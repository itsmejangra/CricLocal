import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cric_local/app/theme.dart';
import 'package:cric_local/features/home/data/models/notification_model.dart';
import 'package:cric_local/core/services/sync_service.dart';
import 'package:cric_local/app/di.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final results = await getIt<SyncService>().getNotifications();
    if (mounted) {
      setState(() {
        _notifications = results.map((m) => NotificationModel.fromMap(m)).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications marked as read')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: AppTheme.textHint),
          const SizedBox(height: 16),
          Text('No notifications yet', style: AppTheme.titleMedium),
          const SizedBox(height: 8),
          Text('We will keep you updated on new features!', style: AppTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildNotificationList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final n = _notifications[index];
        return _buildNotificationCard(n);
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel n) {
    IconData icon;
    Color color;

    switch (n.type) {
      case 'update':
        icon = Icons.system_update;
        color = AppTheme.primaryRed;
        break;
      case 'feature':
        icon = Icons.auto_awesome;
        color = AppTheme.accentTeal;
        break;
      default:
        icon = Icons.info_outline;
        color = AppTheme.primaryBlue;
    }

    return InkWell(
      onTap: () {
        if (n.actionUrl != null) {
          launchUrl(Uri.parse(n.actionUrl!), mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM').format(n.createdAt),
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    n.message,
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary, height: 1.4),
                  ),
                  if (n.actionUrl != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          n.type == 'update' ? 'DOWNLOAD NOW' : 'LEARN MORE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward, color: color, size: 14),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
