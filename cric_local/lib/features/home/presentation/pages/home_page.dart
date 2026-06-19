import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/theme.dart';
import '../../../../core/constants.dart';
import '../../../../features/match/data/models/models.dart';
import '../../../../features/match/data/repositories/match_repository.dart';
import '../../../../app/di.dart';
import '../widgets/app_drawer.dart';
import '../widgets/match_card.dart';
import '../widgets/global_search_delegate.dart';
import '../../../../core/services/sync_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool _isLiveTab = true;
  List<MatchModel> _localMatches = [];
  List<MatchModel> _liveMatches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() => _loading = true);
    final repo = getIt<MatchRepository>();
    final syncService = getIt<SyncService>();
    final localMatches = await repo.getAllMatches();
    final liveMatches = await syncService.getAllLiveMatches();
    setState(() { 
      _localMatches = localMatches;
      _liveMatches = liveMatches;
      _loading = false; 
    });
  }

  List<MatchModel> get _matchesToDisplay => _isLiveTab ? _liveMatches : _localMatches;

  Future<void> _confirmDelete(BuildContext context, MatchModel match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Match?'),
        content: Text('Are you sure you want to delete "${match.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteMatch(match.id);
    }
  }

  Future<void> _deleteMatch(String matchId) async {
    await getIt<MatchRepository>().deleteMatch(matchId);
    _loadMatches();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Match deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.sports_cricket, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          RichText(text: TextSpan(children: [
            TextSpan(text: 'cric', style: AppTheme.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w400)),
            TextSpan(text: 'local', style: AppTheme.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          ])),
        ]),
        actions: [
          if (kIsWeb)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download Android App',
              onPressed: () => launchUrl(Uri.parse(AppConstants.apkDownloadUrl), mode: LaunchMode.externalApplication),
            ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search anything',
            onPressed: () => showSearch(
              context: context,
              delegate: GlobalSearchDelegate(
                localMatches: _localMatches,
                liveMatches: _liveMatches,
              ),
            ),
          ),
          Stack(children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.push('/notifications'),
            ),
            Positioned(right: 8, top: 8, child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: AppTheme.accentTeal, shape: BoxShape.circle),
                child: Text('3', style: AppTheme.bodySmall.copyWith(color: Colors.white, fontSize: 10)),
              ),
            )),
          ]),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadMatches,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Tab bar
            Container(
              color: Colors.white,
              child: Row(children: [
                _buildTab('Global Matches', _isLiveTab, () => setState(() => _isLiveTab = true)),
                _buildTab('My Matches', !_isLiveTab, () => setState(() => _isLiveTab = false)),
              ]),
            ),
            const SizedBox(height: 16),
            // User avatar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Stack(children: [
                  const CircleAvatar(radius: 28, backgroundColor: AppTheme.backgroundGray,
                    child: Icon(Icons.person, size: 32, color: AppTheme.textSecondary)),
                  Positioned(bottom: 0, right: 0, child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: AppTheme.accentTeal, shape: BoxShape.circle),
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  )),
                ]),
                const SizedBox(height: 4),
                Text('You', style: AppTheme.bodySmall),
              ]),
            ),
            const SizedBox(height: 20),
            // Matches section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_isLiveTab ? 'All Global Matches' : 'Matches you score', style: AppTheme.titleMedium),
                TextButton(onPressed: () {}, child: Text('View All', style: AppTheme.labelLarge)),
              ]),
            ),
            const SizedBox(height: 8),
            _loading
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                : _matchesToDisplay.isEmpty
                    ? _buildEmptyState()
                    : SizedBox(
                        height: 245,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _matchesToDisplay.length,
                          itemBuilder: (ctx, i) => Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: MatchCard(
                              match: _matchesToDisplay[i],
                              onTap: () {
                                // If match exists locally, always go to manage/score page
                                final isLocal = _localMatches.any((m) => m.id == _matchesToDisplay[i].id);
                                if (isLocal) {
                                  context.push('/match/${_matchesToDisplay[i].id}');
                                } else {
                                  context.push('/live/${_matchesToDisplay[i].id}');
                                }
                              },
                              onDelete: _isLiveTab ? null : () => _confirmDelete(context, _matchesToDisplay[i]),
                            ),
                          ),
                        ),
                      ),
            const SizedBox(height: 16),
            // Cricketers section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Cricketers you may know', style: AppTheme.titleMedium),
            ),
            const SizedBox(height: 100),
          ]),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 0) return; // Already on Home
          
          if (i == 1) {
            context.push('/leaderboards');
          } else if (i == 2) {
            context.push('/awards');
          } else if (i == 3) {
            context.push('/contact');
          } else if (i == 4) {
             _showShareOptions();
          }
          // Reset index to home after navigation/action so home stays selected 
          // (standard pattern for action-based bottom items)
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _currentIndex = 0);
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard_outlined), activeIcon: Icon(Icons.leaderboard), label: 'Leaderboards'),
          BottomNavigationBarItem(icon: Icon(Icons.military_tech_outlined), activeIcon: Icon(Icons.military_tech), label: 'Awards'),
          BottomNavigationBarItem(icon: Icon(Icons.phone_outlined), activeIcon: Icon(Icons.phone), label: 'Contact'),
          BottomNavigationBarItem(icon: Icon(Icons.share_outlined), activeIcon: Icon(Icons.share), label: 'Share'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryRed,
        onPressed: () => context.push('/match/new'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTab(String label, bool isActive, VoidCallback onTap) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(border: Border(
          bottom: BorderSide(color: isActive ? AppTheme.primaryRed : Colors.transparent, width: 3),
        )),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(child: Text(label, style: isActive
            ? AppTheme.titleMedium.copyWith(color: AppTheme.primaryRed)
            : AppTheme.titleMedium.copyWith(color: AppTheme.textSecondary))),
      ),
    ));
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(children: [
        Icon(Icons.sports_cricket, size: 64, color: AppTheme.textHint),
        const SizedBox(height: 16),
        Text('No matches yet', style: AppTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Tap + to start your first match!', style: AppTheme.bodySmall),
      ]),
    );
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.backgroundGray, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('Share CricLocal', style: AppTheme.headlineSmall.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Invite your friends to the ultimate cricket experience', style: AppTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _shareCircle(Icons.link, 'Copy Link', AppTheme.primaryBlue, () {
                  final appUrl = 'https://criclocal.eduhubacademy.org';
                  Clipboard.setData(ClipboardData(text: appUrl));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App link copied to clipboard!')));
                }),
                _shareCircle(Icons.qr_code, 'QR Code', AppTheme.accentTeal, () {
                  Navigator.pop(ctx);
                  _showQRCodeDialog();
                }),
                _shareCircle(Icons.more_horiz, 'System', Colors.grey, () {
                  Navigator.pop(ctx);
                  final appUrl = 'https://criclocal.eduhubacademy.org';
                  Share.share('Check out CricLocal for live cricket scoring: $appUrl');
                }),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _shareCircle(IconData icon, String label, Color color, VoidCallback onTap) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showQRCodeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan to Share'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Image.network(
                'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${Uri.encodeComponent('https://criclocal.eduhubacademy.org')}',
                width: 200,
                height: 200,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.red, size: 48),
                          SizedBox(height: 8),
                          Text('Failed to load QR code', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text('Scan this code to open CricLocal', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE')),
        ],
      ),
    );
  }
}
