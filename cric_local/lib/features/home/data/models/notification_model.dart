import 'package:equatable/equatable.dart';

class NotificationModel extends Equatable {
  final String id;
  final String title;
  final String message;
  final String? type; // 'update', 'feature', 'info'
  final String? actionUrl;
  final DateTime createdAt;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.type,
    this.actionUrl,
    required this.createdAt,
    this.isRead = false,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> m) => NotificationModel(
    id: m['id'] as String,
    title: m['title'] as String,
    message: m['message'] as String,
    type: m['type'] as String?,
    actionUrl: m['actionUrl'] as String?,
    createdAt: DateTime.parse(m['createdAt'] as String),
    isRead: m['isRead'] == true || m['isRead'] == 1,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'message': message,
    'type': type,
    'actionUrl': actionUrl,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead ? 1 : 0,
  };

  @override
  List<Object?> get props => [id, title, message, createdAt];
}
