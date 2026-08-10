import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
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
        InkWell(
          onTap: () {
            Navigator.pop(context);
            context.push('/profile');
          },
          child: Container(
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
      _buildMenuItem(Icons.compare_arrows, 'Head to Head', context, badge: 'New', onTap: () {
        Navigator.pop(context);
        context.push('/head-to-head');
      }),
      _buildMenuItem(Icons.people_outline, 'My Teams', context, onTap: () {
        Navigator.pop(context);
        context.push('/teams');
      }),
      _buildMenuItem(Icons.storefront_outlined, 'CricLocal Store', context, onTap: () => _showComingSoon(context, 'Store')),
      _buildMenuItem(Icons.leaderboard_outlined, 'Leaderboards', context, onTap: () {
        Navigator.pop(context);
        context.push('/leaderboards');
      }),
      _buildMenuItem(Icons.table_chart_outlined, 'Detailed Rankings', context, badge: 'New', onTap: () {
        Navigator.pop(context);
        context.push('/rankings');
      }),
      _buildMenuItem(Icons.military_tech_outlined, 'CricLocal Awards', context, onTap: () {
        Navigator.pop(context);
        context.push('/awards');
      }),
      const Divider(height: 1),
      _buildMenuItem(Icons.groups_outlined, 'Associations', context, onTap: () {
        Navigator.pop(context);
        context.push('/associations');
      }),
      _buildMenuItem(Icons.shield_outlined, 'Clubs', context, onTap: () {
        Navigator.pop(context);
        context.push('/clubs');
      }),
      _buildMenuItem(Icons.phone_outlined, 'Contact', context, onTap: () {
        Navigator.pop(context);
        context.push('/contact');
      }),
      _buildMenuItem(Icons.share_outlined, 'Share the app', context, onTap: () {
        Navigator.pop(context);
        // Using basic share message
        final box = context.findRenderObject() as RenderBox?;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening share menu...')),
        );
        // This would typically use share_plus, but we'll show a fancy dialog for now 
        // to match the "Premium" requirement if share_plus isn't readily available for web native share
        _showShareOptions(context);
      }),
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

  void _showShareOptions(BuildContext context) {
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
            const SizedBox(height: 32),
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
                  _showQRCodeDialog(context);
                }),
                _shareCircle(Icons.more_horiz, 'System', Colors.grey, () {
                  Navigator.pop(ctx);
                  final appUrl = 'https://criclocal.eduhubacademy.org';
                  Share.share('Check out CricLocal for live cricket scoring: $appUrl');
                }),
              ],
            ),
            const SizedBox(height: 32),
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

  void _showQRCodeDialog(BuildContext context) {
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
                'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=https://criclocal.eduhubacademy.org',
                width: 200,
                height: 200,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(width: 200, height: 200, child: Center(child: CircularProgressIndicator()));
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
