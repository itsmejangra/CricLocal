import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../../core/services/sync_service.dart';
import '../../data/models/delivery_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/repositories/match_repository.dart';
import '../bloc/scoring_event_state.dart';

class CommentaryTab extends StatefulWidget {
  final ScoringState state;
  final String matchId;

  const CommentaryTab({
    super.key,
    required this.state,
    required this.matchId,
  });

  @override
  State<CommentaryTab> createState() => _CommentaryTabState();
}

class _CommentaryTabState extends State<CommentaryTab> {
  List<DeliveryModel> _allDeliveries = [];
  MatchModel? _match;
  List<InningsModel> _innings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant CommentaryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload when state or matchId changes so we get live updates
    if (oldWidget.state != widget.state || oldWidget.matchId != widget.matchId) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      final repo = getIt<MatchRepository>();
      final syncService = getIt<SyncService>();

      // 1. Try to load local match details & deliveries
      MatchModel? match = await repo.getMatch(widget.matchId);
      List<InningsModel> innings = [];
      List<DeliveryModel> deliveries = [];

      if (match != null) {
        innings = await repo.getInningsForMatch(widget.matchId);
        deliveries = await repo.getAllDeliveriesForMatch(widget.matchId);
      }

      // 2. If not found locally or empty deliveries, fall back to remote D1 sync service
      if (match == null || deliveries.isEmpty) {
        final remoteData = await syncService.getLiveMatchData(widget.matchId);
        if (remoteData != null) {
          match = remoteData.match;
          innings = remoteData.innings;
          deliveries = remoteData.recentDeliveries; // Updated backend returns all deliveries
        }
      }

      if (mounted) {
        setState(() {
          _match = match;
          _innings = innings;
          _allDeliveries = deliveries;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('CommentaryTab load error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportToPdf() async {
    if (_match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot export PDF: Match data not loaded.')),
      );
      return;
    }

    try {
      final pdf = pw.Document();

      // Load premium web fonts dynamically
      final fontNormal = await PdfGoogleFonts.interRegular();
      final fontBold = await PdfGoogleFonts.interBold();

      final String matchTitle = _match!.title;
      final String venue = _match!.venue ?? 'N/A';
      final String resultSummary = _match!.resultSummary ?? 'In Progress';
      final String team1 = _match!.team1Name;
      final String team2 = _match!.team2Name;
      final String dateStr = DateFormat('dd MMM yyyy').format(_match!.matchDate);

      // Group deliveries by innings for structured presentation
      final Map<String, List<DeliveryModel>> inningsDeliveries = {};
      for (final inn in _innings) {
        final list = _allDeliveries.where((d) => d.inningsId == inn.id).toList();
        if (list.isNotEmpty) {
          inningsDeliveries[inn.battingTeam] = list;
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Text('CricLocal Official Match Commentary',
                style: pw.TextStyle(font: fontNormal, fontSize: 8, color: PdfColors.grey500)),
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(font: fontNormal, fontSize: 9, color: PdfColors.grey500)),
          ),
          build: (pw.Context context) {
            final List<pw.Widget> content = [];

            // 1. Premium Branded Header
            content.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CricLocal', style: pw.TextStyle(font: fontBold, fontSize: 26, color: PdfColors.red900)),
                      pw.Text('BALL-BY-BALL COMMENTARY LOG',
                          style: pw.TextStyle(font: fontNormal, fontSize: 10, color: PdfColors.grey700, letterSpacing: 1)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(dateStr, style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.grey800)),
                      pw.Text('Venue: $venue', style: pw.TextStyle(font: fontNormal, fontSize: 9, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            );

            content.add(pw.SizedBox(height: 12));
            content.add(pw.Divider(thickness: 2, color: PdfColors.red900));
            content.add(pw.SizedBox(height: 12));

            // 2. Summary Overview Panel
            content.add(
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(matchTitle, style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.black)),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Text('Teams: ', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey700)),
                        pw.Text('$team1 vs $team2', style: pw.TextStyle(font: fontNormal, fontSize: 10)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Text('Result: ', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey700)),
                        pw.Text(resultSummary, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.teal900)),
                      ],
                    ),
                  ],
                ),
              ),
            );

            content.add(pw.SizedBox(height: 20));

            // 3. Innings Breakdown & Commentary Log
            if (inningsDeliveries.isEmpty) {
              content.add(pw.Center(
                child: pw.Text('No commentary logs found for this match.',
                    style: pw.TextStyle(font: fontNormal, fontSize: 12, color: PdfColors.grey600)),
              ));
            } else {
              inningsDeliveries.forEach((battingTeam, deliveries) {
                content.add(pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8),
                  child: pw.Text('Innings of $battingTeam',
                      style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.red800)),
                ));
                content.add(pw.Divider(thickness: 1, color: PdfColors.grey300));
                content.add(pw.SizedBox(height: 6));

                // Sort deliveries chronologically (oldest first, i.e., 0.1, 0.2...) for match log report
                final sorted = List<DeliveryModel>.from(deliveries)
                  ..sort((a, b) {
                    if (a.overNumber != b.overNumber) {
                      return a.overNumber.compareTo(b.overNumber);
                    }
                    return a.ballNumber.compareTo(b.ballNumber);
                  });

                for (final ball in sorted) {
                  PdfColor chipBg = PdfColors.grey300;
                  PdfColor chipText = PdfColors.black;
                  String chipLabel = '${ball.totalRuns}';

                  if (ball.isWicket) {
                    chipBg = PdfColors.red900;
                    chipText = PdfColors.white;
                    chipLabel = 'W';
                  } else if (ball.isWide) {
                    chipBg = PdfColors.amber100;
                    chipText = PdfColors.amber900;
                    chipLabel = 'WD';
                  } else if (ball.isNoBall) {
                    chipBg = PdfColors.orange100;
                    chipText = PdfColors.orange900;
                    chipLabel = 'NB';
                  } else if (ball.runsScored == 4) {
                    chipBg = PdfColors.blue100;
                    chipText = PdfColors.blue900;
                  } else if (ball.runsScored == 6) {
                    chipBg = PdfColors.purple100;
                    chipText = PdfColors.purple900;
                  } else if (ball.totalRuns == 0) {
                    chipBg = PdfColors.grey100;
                    chipText = PdfColors.grey700;
                  }

                  content.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Ball Over.Ball (e.g. 5.3)
                          pw.Container(
                            width: 35,
                            child: pw.Text('${ball.overNumber}.${ball.ballNumber}',
                                style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.grey800)),
                          ),
                          // Result Tag
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                            decoration: pw.BoxDecoration(
                              color: chipBg,
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                            ),
                            constraints: const pw.BoxConstraints(minWidth: 16),
                            alignment: pw.Alignment.center,
                            child: pw.Text(chipLabel,
                                style: pw.TextStyle(font: fontBold, fontSize: 8, color: chipText)),
                          ),
                          pw.SizedBox(width: 10),
                          // Ball commentary description
                          pw.Expanded(
                            child: pw.Text(
                              ball.commentary ?? 'Delivery recorded.',
                              style: pw.TextStyle(font: fontNormal, fontSize: 9, color: PdfColors.grey900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                content.add(pw.SizedBox(height: 16));
              });
            }

            return content;
          },
        ),
      );

      final pdfName = 'CricLocal_${matchTitle.replaceAll(RegExp(r'\s+'), '_')}_Commentary.pdf';
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: pdfName,
      );
    } catch (e) {
      print('PDF Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allDeliveries.isEmpty) {
      return const Center(child: Text('No commentary available yet.'));
    }

    // Show newest first for active scrolling feedback (standard cricket presentation)
    final reversedBalls = _allDeliveries.reversed.toList();

    return Column(
      children: [
        // Premium utility header panel
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${_allDeliveries.length} Deliveries Logged',
                    style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _exportToPdf,
                icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.white),
                label: const Text('Export PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Commentary ball-by-ball list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reversedBalls.length,
            separatorBuilder: (ctx, i) => const Divider(height: 24),
            itemBuilder: (ctx, i) {
              final ball = reversedBalls[i];
              return _buildCommentaryItem(ball);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCommentaryItem(DeliveryModel ball) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ball indicator
        Container(
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.backgroundGray,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              Text('${ball.overNumber}.${ball.ballNumber}',
                  style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              _ballResultChip(ball),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Commentary text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ball.commentary ?? 'Delivery recorded.',
                style: AppTheme.bodyMedium.copyWith(height: 1.4),
              ),
              if (ball.isWicket)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'WICKET!',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ballResultChip(DeliveryModel ball) {
    Color bg = AppTheme.textHint;
    String text = '${ball.totalRuns}';

    if (ball.isWicket) {
      bg = AppTheme.wicketRed;
      text = 'W';
    } else if (ball.isWide) {
      bg = AppTheme.wideColor;
      text = 'WD';
    } else if (ball.isNoBall) {
      bg = AppTheme.noBallColor;
      text = 'NB';
    } else if (ball.runsScored == 4) {
      bg = AppTheme.fourColor;
    } else if (ball.runsScored == 6) {
      bg = AppTheme.sixColor;
    } else if (ball.totalRuns == 0) {
      bg = AppTheme.dotBallColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: bg.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: bg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
