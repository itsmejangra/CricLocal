import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../../main.dart';
import '../../../match/data/repositories/match_repository.dart';
import '../../../match/presentation/pages/live_viewer_page.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(children: [
        // Profile header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
          decoration: const BoxDecoration(color: AppTheme.accentTeal),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const CircleAvatar(radius: 30, backgroundColor: Colors.white70,
                child: Icon(Icons.person, size: 36, color: AppTheme.accentTeal)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cricket Fan', style: AppTheme.titleLarge.copyWith(color: Colors.white)),
                const SizedBox(height: 2),
                Text('9876543210', style: AppTheme.bodySmall.copyWith(color: Colors.white70)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text('FREE', style: AppTheme.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 10)),
                ),
              ])),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white70)),
                child: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
              ),
            ]),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0.25, minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerRight,
              child: Text('25%', style: AppTheme.bodySmall.copyWith(color: Colors.white70, fontSize: 11))),
          ]),
        ),
        // Menu items
        Expanded(child: ListView(padding: EdgeInsets.zero, children: [
      _buildMenuItem(Icons.workspace_premium, 'PRO Privileges', context, onTap: () => _showComingSoon(context, 'PRO Privileges')),
      _buildMenuItem(Icons.emoji_events_outlined, 'Add a Tournament/Series', context, badge: 'Free', onTap: () => _showComingSoon(context, 'Tournaments')),
      _buildMenuItem(Icons.sports_cricket, 'Start A Match', context, badge: 'Free', onTap: () {
        Navigator.pop(context);
        context.push('/match/new');
      }),
      _buildMenuItem(Icons.videocam_outlined, 'Go Live', context, onTap: () => _showComingSoon(context, 'Go Live')),
      _buildMenuItem(Icons.podcasts, 'Live Viewer', context, onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveViewerPage()));
      }),
      const Divider(height: 1),
      _buildMenuItem(Icons.auto_graph, 'My Cricket', context, onTap: () {
        Navigator.pop(context);
        context.go('/'); // Goes to home where My Cricket tab resides
      }),
      _buildMenuItem(Icons.bar_chart, 'My Performance', context, onTap: () {
        Navigator.pop(context);
        context.push('/player/stats/Cricket%20Fan');
      }),
      _buildMenuItem(Icons.storefront_outlined, 'CricLocal Store', context, onTap: () => _showComingSoon(context, 'Store')),
      _buildMenuItem(Icons.leaderboard_outlined, 'Leaderboards', context, onTap: () => _showComingSoon(context, 'Leaderboards')),
      _buildMenuItem(Icons.military_tech_outlined, 'CricLocal Awards', context, onTap: () => _showComingSoon(context, 'Awards')),
      const Divider(height: 1),
      _buildMenuItem(Icons.groups_outlined, 'Associations', context, onTap: () => _showComingSoon(context, 'Associations')),
      _buildMenuItem(Icons.shield_outlined, 'Clubs', context, onTap: () => _showComingSoon(context, 'Clubs')),
      _buildMenuItem(Icons.delete_forever_outlined, 'Clear All Data', context, onTap: () => _showClearDataDialog(context)),
      _buildMenuItem(Icons.phone_outlined, 'Contact', context, onTap: () => _showComingSoon(context, 'Contact')),
      _buildMenuItem(Icons.share_outlined, 'Share the app', context, onTap: () => _showComingSoon(context, 'Sharing')),
      const Divider(height: 1),
      ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeNotifier,
        builder: (context, mode, child) => SwitchListTile(
          secondary: Icon(mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode, color: AppTheme.textPrimary, size: 24),
          title: Text('Dark Mode', style: AppTheme.bodyLarge),
          value: mode == ThemeMode.dark,
          onChanged: (v) => themeModeNotifier.value = v ? ThemeMode.dark : ThemeMode.light,
          dense: true,
        ),
      ),
    ])),
  ]),
);
}

Widget _buildMenuItem(IconData icon, String label, BuildContext context, {String? badge, VoidCallback? onTap}) {
return ListTile(
  leading: Icon(icon, color: AppTheme.textPrimary, size: 24),
  title: Row(
    children: [
      Expanded(child: Text(label, style: AppTheme.bodyLarge, overflow: TextOverflow.ellipsis)),
      if (badge != null) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(color: AppTheme.accentTeal, borderRadius: BorderRadius.circular(4)),
          child: Text(badge, style: AppTheme.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11)),
        ),
      ],
    ],
  ),
  onTap: onTap ?? () => Navigator.pop(context),
  dense: true,
  visualDensity: const VisualDensity(vertical: -1),
);
}

void _showClearDataDialog(BuildContext context) {
showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('Clear All Data?'),
    content: const Text('This will delete all matches, players, and stats recorded so far. This action cannot be undone.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
      TextButton(
        onPressed: () async {
          Navigator.pop(ctx); // Close dialog
          Navigator.pop(context); // Close drawer
          await getIt<MatchRepository>().clearAllData();
          if (context.mounted) {
            context.go('/'); // Refresh home
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('All data cleared successfully')),
            );
          }
        },
        child: const Text('CLEAR ALL', style: TextStyle(color: AppTheme.primaryRed)),
      ),
    ],
  ),
);
}

  void _showComingSoon(BuildContext context, String feature) {
    Navigator.pop(context); // Close drawer
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
