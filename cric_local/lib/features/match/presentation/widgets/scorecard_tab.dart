import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme.dart';
import '../../data/models/models.dart';
import '../bloc/scoring_event_state.dart';

class ScorecardTab extends StatelessWidget {
  final ScoringState state;
  final bool isScrollable;
  const ScorecardTab({super.key, required this.state, this.isScrollable = true});

  Future<void> _exportScorecardToPdf(BuildContext context, MatchModel match, List<ScorecardData> allScorecards, List<PlayerModel> players) async {
    try {
      final pdf = pw.Document();
      
      final fontNormal = await PdfGoogleFonts.interRegular();
      final fontBold = await PdfGoogleFonts.interBold();
      
      final String matchTitle = match.title;
      final String venue = match.venue ?? 'N/A';
      final String resultSummary = match.resultSummary ?? 'In Progress';
      final String team1 = match.team1Name;
      final String team2 = match.team2Name;
      final String dateStr = DateFormat('dd MMM yyyy').format(match.matchDate);
      final String tossText = match.tossSummary;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Text('CricLocal Official Scorecard',
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

            // 1. Branded Crimson Title Header
            content.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CricLocal', style: pw.TextStyle(font: fontBold, fontSize: 26, color: PdfColors.red900)),
                      pw.Text('OFFICIAL MATCH SCORECARD',
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

            // 2. Overview Panel
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
                    if (tossText.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('Toss: ', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey700)),
                          pw.Text(tossText, style: pw.TextStyle(font: fontNormal, fontSize: 10)),
                        ],
                      ),
                    ],
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

            // 3. Innings Scorecard
            for (final scorecard in allScorecards) {
              final inn = scorecard.innings;
              
              content.add(
                pw.Container(
                  color: PdfColors.red900,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${inn.battingTeam} Innings', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white)),
                      pw.Text(inn.fullScoreDisplay, style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white)),
                    ],
                  ),
                ),
              );
              
              content.add(pw.SizedBox(height: 8));

              // --- BATTING TABLE ---
              final List<List<String>> battingTableData = [
                ['BATTER', 'DISMISSAL', 'R', 'B', '4s', '6s', 'SR']
              ];
              
              for (final bi in scorecard.batsmanStats) {
                final player = players.where((p) => p.id == bi.playerId).firstOrNull;
                final name = player?.displayName ?? 'Unknown';
                final desc = bi.isOut ? (bi.dismissalDescription ?? bi.dismissalType ?? 'out') : (bi.ballsFaced > 0 ? 'batting' : 'yet to bat');
                battingTableData.add([
                  name,
                  desc,
                  '${bi.runs}',
                  '${bi.ballsFaced}',
                  '${bi.fours}',
                  '${bi.sixes}',
                  bi.strikeRateDisplay
                ]);
              }

              content.add(
                pw.TableHelper.fromTextArray(
                  headers: battingTableData[0],
                  data: battingTableData.sublist(1),
                  border: pw.TableBorder.symmetric(inside: const pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
                  headerStyle: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.grey800),
                  cellStyle: pw.TextStyle(font: fontNormal, fontSize: 8),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.5),
                    1: const pw.FlexColumnWidth(3.0),
                    2: const pw.FixedColumnWidth(20),
                    3: const pw.FixedColumnWidth(20),
                    4: const pw.FixedColumnWidth(20),
                    5: const pw.FixedColumnWidth(20),
                    6: const pw.FixedColumnWidth(25),
                  },
                  cellAlignment: pw.Alignment.centerRight,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                  }
                )
              );

              content.add(pw.SizedBox(height: 6));
              
              // Extras & Totals
              content.add(
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Extras: ${inn.extrasSummary}', style: pw.TextStyle(font: fontNormal, fontSize: 9, color: PdfColors.grey800)),
                    pw.Text('Total: ${inn.scoreDisplay} (${inn.oversDisplay} Ov, RR ${inn.currentRunRateDisplay})', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.red900)),
                  ]
                )
              );
              
              // Yet to Bat
              final battedIds = scorecard.batsmanStats.map((b) => b.playerId).toSet();
              final toBat = players.where((p) => p.teamName == inn.battingTeam && !battedIds.contains(p.id)).toList();
              if (toBat.isNotEmpty) {
                content.add(pw.SizedBox(height: 4));
                content.add(pw.Text('Yet to bat: ${toBat.map((p) => p.displayName).join(", ")}', style: pw.TextStyle(font: fontNormal, fontSize: 8.5, color: PdfColors.grey600)));
              }

              content.add(pw.SizedBox(height: 12));

              // --- BOWLING TABLE ---
              final List<List<String>> bowlingTableData = [
                ['BOWLER', 'O', 'M', 'R', 'W', 'Eco']
              ];
              
              for (final bs in scorecard.bowlerStats) {
                final player = players.where((p) => p.id == bs.playerId).firstOrNull;
                final name = player?.displayName ?? 'Unknown';
                bowlingTableData.add([
                  name,
                  bs.oversDisplay,
                  '${bs.maidens}',
                  '${bs.runsConceded}',
                  '${bs.wickets}',
                  bs.economyDisplay
                ]);
              }

              content.add(
                pw.TableHelper.fromTextArray(
                  headers: bowlingTableData[0],
                  data: bowlingTableData.sublist(1),
                  border: pw.TableBorder.symmetric(inside: const pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
                  headerStyle: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.grey800),
                  cellStyle: pw.TextStyle(font: fontNormal, fontSize: 8),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3.0),
                    1: const pw.FixedColumnWidth(25),
                    2: const pw.FixedColumnWidth(25),
                    3: const pw.FixedColumnWidth(25),
                    4: const pw.FixedColumnWidth(25),
                    5: const pw.FixedColumnWidth(30),
                  },
                  cellAlignment: pw.Alignment.centerRight,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                  }
                )
              );

              content.add(pw.SizedBox(height: 24));
            }

            return content;
          },
        ),
      );
      
      final pdfName = 'CricLocal_${matchTitle.replaceAll(RegExp(r"\s+"), "_")}_Scorecard.pdf';
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: pdfName,
      );
    } catch (e) {
      print('Scorecard PDF Export error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    List<ScorecardData> allScorecards = [];
    List<PlayerModel> players = [];
    MatchModel? match;

    if (state is ScoringActive) {
      final s = state as ScoringActive;
      allScorecards = s.allScorecards;
      players = s.allPlayers;
      match = s.match;
    } else if (state is InningsBreak) {
      final s = state as InningsBreak;
      allScorecards = s.allScorecards;
      players = s.allPlayers;
      match = s.match;
    } else if (state is MatchCompleted) {
      final s = state as MatchCompleted;
      allScorecards = s.allScorecards;
      players = s.allPlayers;
      match = s.match;
    }

    if (allScorecards.isEmpty) {
      return const Center(child: Text('No scorecard data available yet.'));
    }

    final listView = ListView.builder(
          itemCount: allScorecards.length,
          shrinkWrap: !isScrollable,
          physics: isScrollable ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          itemBuilder: (context, index) {
            final scorecard = allScorecards[index];
            return _InningsScorecard(
              data: scorecard,
              players: players,
              isExpanded: index == allScorecards.length - 1,
            );
          },
        );

    return Column(
      children: [
        // Utility header panel
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_outlined, size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${allScorecards.length} Innings Scorecards',
                    style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              if (match != null)
                ElevatedButton.icon(
                  onPressed: () => _exportScorecardToPdf(context, match!, allScorecards, players),
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
        if (isScrollable)
          Expanded(child: listView)
        else
          listView,
      ],
    );
  }
}

class _InningsScorecard extends StatelessWidget {
  final ScorecardData data;
  final List<PlayerModel> players;
  final bool isExpanded;

  const _InningsScorecard({
    required this.data,
    required this.players,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final innings = data.innings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: AppTheme.primaryRed,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${innings.battingTeam} Innings',
                  style: AppTheme.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                innings.fullScoreDisplay,
                style: AppTheme.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        _buildBattersTable(),
        _buildExtrasRow(),
        _buildTotalRow(),
        if (players.isNotEmpty) _buildToBatRow(),
        const SizedBox(height: 16),
        _buildBowlersTable(),
        _buildFallOfWickets(),
        const Divider(height: 32, thickness: 8, color: AppTheme.backgroundGray),
      ],
    );
  }

  Widget _buildBattersTable() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: AppTheme.backgroundGray.withValues(alpha: 0.5),
          child: Row(
            children: [
              const Expanded(flex: 4, child: Text('BATTERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
              _headerCell('R'),
              _headerCell('B'),
              _headerCell('4s'),
              _headerCell('6s'),
              _headerCell('SR'),
            ],
          ),
        ),
        ...data.batsmanStats.map((bi) {
          final player = players.where((p) => p.id == bi.playerId).firstOrNull;
          return _BatsmanRow(player: player, stat: bi);
        }),
      ],
    );
  }

  Widget _headerCell(String label) {
    return SizedBox(
      width: 38,
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _buildExtrasRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Extras', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          Text(data.innings.extrasSummary, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTotalRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.accentTeal.withValues(alpha: 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total', style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold)),
              Text('${data.innings.oversDisplay} Overs (RR ${data.innings.currentRunRateDisplay})', 
                   style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
            ],
          ),
          Text(
            data.innings.scoreDisplay,
            style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primaryRed),
          ),
        ],
      ),
    );
  }

  Widget _buildToBatRow() {
    final battedIds = data.batsmanStats.map((b) => b.playerId).toSet();
    final toBat = players.where((p) => p.teamName == data.innings.battingTeam && !battedIds.contains(p.id)).toList();
    if (toBat.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Yet to bat', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(
            toBat.map((p) => p.displayName).join(', '),
            style: AppTheme.bodySmall.copyWith(color: AppTheme.accentTeal, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildBowlersTable() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: AppTheme.backgroundGray.withValues(alpha: 0.5),
          child: Row(
            children: [
              const Expanded(flex: 4, child: Text('BOWLERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
              _headerCell('O'),
              _headerCell('M'),
              _headerCell('R'),
              _headerCell('W'),
              _headerCell('Eco'),
            ],
          ),
        ),
        ...data.bowlerStats.map((bs) {
          final player = players.where((p) => p.id == bs.playerId).firstOrNull;
          return _BowlerRow(player: player, stat: bs);
        }),
      ],
    );
  }

  Widget _buildFallOfWickets() {
    final wickets = data.deliveries.where((d) => d.isWicket).toList();
    if (wickets.isEmpty) return const SizedBox.shrink();

    int runningScore = 0;
    final entries = <String>[];
    for (final delivery in data.deliveries) {
      runningScore += delivery.totalRuns;
      if (delivery.isWicket) {
        final player = players.where((p) => p.id == delivery.dismissedPlayerId).firstOrNull;
        final name = player?.displayName ?? 'Unknown';
        final over = '${delivery.overNumber}.${delivery.ballNumber}';
        entries.add('${entries.length + 1}-$runningScore $name ($over ov)');
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fall of Wickets',
            style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            entries.join(', '),
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _BatsmanRow extends StatelessWidget {
  final PlayerModel? player;
  final BatsmanInningsModel stat;

  const _BatsmanRow({required this.player, required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: InkWell(
                  onTap: player != null ? () => context.push('/player/stats/${Uri.encodeComponent(player!.name)}') : null,
                  child: Text(
                    player?.displayName ?? 'Unknown',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.accentTeal,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.accentTeal.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              _statCell('${stat.runs}', isBold: true),
              _statCell('${stat.ballsFaced}'),
              _statCell('${stat.fours}'),
              _statCell('${stat.sixes}'),
              _statCell(stat.strikeRateDisplay),
            ],
          ),
          if (stat.isOut)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                stat.dismissalDescription ?? stat.dismissalType ?? 'out',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary, fontSize: 11),
              ),
            )
          else if (stat.ballsFaced > 0 || stat.battingPosition > 0)
             Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'batting',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.accentTeal, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statCell(String value, {bool isBold = false}) {
    return SizedBox(
      width: 38,
      child: Text(
        value,
        style: AppTheme.bodyMedium.copyWith(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }
}

class _BowlerRow extends StatelessWidget {
  final PlayerModel? player;
  final BowlerInningsModel stat;

  const _BowlerRow({required this.player, required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: player != null ? () => context.push('/player/stats/${Uri.encodeComponent(player!.name)}') : null,
              child: Text(
                player?.displayName ?? 'Unknown',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.accentTeal,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: AppTheme.accentTeal.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          _statCell(stat.oversDisplay),
          _statCell('${stat.maidens}'),
          _statCell('${stat.runsConceded}'),
          _statCell('${stat.wickets}', isBold: true),
          _statCell(stat.economyDisplay),
        ],
      ),
    );
  }

  Widget _statCell(String value, {bool isBold = false}) {
    return SizedBox(
      width: 38,
      child: Text(
        value,
        style: AppTheme.bodyMedium.copyWith(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }
}
