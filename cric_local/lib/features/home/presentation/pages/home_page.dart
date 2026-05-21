import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/theme.dart';
import '../../../../features/match/data/models/models.dart';
import '../../../../features/match/data/repositories/match_repository.dart';
import '../../../../app/di.dart';
import '../widgets/app_drawer.dart';
import '../widgets/match_card.dart';
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
              onPressed: () => launchUrl(Uri.parse('/CricHero.apk')),
            ),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.chat_bubble_outline), onPressed: () {}),
          Stack(children: [
            IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
            Positioned(right: 8, top: 8, child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: AppTheme.accentTeal, shape: BoxShape.circle),
              child: Text('3', style: AppTheme.bodySmall.copyWith(color: Colors.white, fontSize: 10)),
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
                                if (_isLiveTab) {
                                  context.push('/live/${_matchesToDisplay[i].id}');
                                } else {
                                  context.push('/match/${_matchesToDisplay[i].id}');
                                }
                              },
                              onDelete: _isLiveTab ? null : () => _confirmDelete(context, _matchesToDisplay[i]),
                            ),
                          ),
                        ),
                      ),
            const SizedBox(height: 24),
            // Stream banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                ),
              ),
              child: Stack(children: [
                Positioned(left: 16, top: 16, bottom: 16, child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(width: 120, color: Colors.grey[800],
                    child: const Icon(Icons.videocam, color: Colors.white54, size: 40)),
                )),
                Positioned(right: 16, top: 20, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Stream your', style: AppTheme.bodyLarge.copyWith(color: Colors.white)),
                    Text('first match', style: AppTheme.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    Text('for ₹99', style: AppTheme.titleLarge.copyWith(color: Colors.white)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppTheme.accentTeal, borderRadius: BorderRadius.circular(4)),
                      child: Text('Start streaming', style: AppTheme.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ],
                )),
              ]),
            ),
            const SizedBox(height: 24),
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
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Looking'),
          BottomNavigationBarItem(icon: Icon(Icons.sports_cricket_outlined), activeIcon: Icon(Icons.sports_cricket), label: 'My Cricket'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), activeIcon: Icon(Icons.groups), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.store_outlined), activeIcon: Icon(Icons.store), label: 'Store'),
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
}
