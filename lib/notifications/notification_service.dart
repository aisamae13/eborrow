import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/main.dart';

// Enhanced NotificationItem class
enum NotificationType {
  modificationLimit,
  requestApproved,
  requestRejected,
  equipmentOverdue,
  equipmentReturned,
  general
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
  });

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: map['notification_id'].toString(),
      title: map['title'],
      message: map['message'],
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${map['type']}',
        orElse: () => NotificationType.general,
      ),
      timestamp: DateTime.parse(map['created_at']).toLocal(), // Fix timestamp
      isRead: map['is_read'] ?? false,
      metadata: map['metadata'],
    );
  }

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }

  IconData get icon {
    switch (type) {
      case NotificationType.modificationLimit:
        return Icons.block;
      case NotificationType.requestApproved:
        return Icons.check_circle;
      case NotificationType.requestRejected:
        return Icons.cancel;
      case NotificationType.equipmentOverdue:
        return Icons.warning;
      case NotificationType.equipmentReturned:
        return Icons.done_all;
      case NotificationType.general:
        return Icons.info;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.modificationLimit:
        return Colors.red;
      case NotificationType.requestApproved:
        return Colors.green;
      case NotificationType.requestRejected:
        return Colors.red;
      case NotificationType.equipmentOverdue:
        return Colors.orange;
      case NotificationType.equipmentReturned:
        return Colors.blue;
      case NotificationType.general:
        return Colors.grey;
    }
  }
}

// Real-time Notification Provider
class NotificationProvider extends ChangeNotifier {
  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  RealtimeChannel? _subscription;

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  // Initialize real-time subscription
  void initializeRealtime(String userId) {
    // Cancel any existing subscription
    _subscription?.unsubscribe();

    // Create new subscription
    _subscription = supabase
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: _handleNewNotification,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: _handleUpdatedNotification,
        )
        .subscribe();

    // Load initial notifications
    loadNotifications(userId);
  }

  void _handleNewNotification(PostgresChangePayload payload) {
    final newNotification = NotificationItem.fromMap(payload.newRecord);
    _notifications.insert(0, newNotification);
    if (!newNotification.isRead) {
      _unreadCount++;
    }
    notifyListeners();
  }

  void _handleUpdatedNotification(PostgresChangePayload payload) {
    final updatedNotification = NotificationItem.fromMap(payload.newRecord);
    final index = _notifications.indexWhere((n) => n.id == updatedNotification.id);

    if (index != -1) {
      final oldNotification = _notifications[index];
      _notifications[index] = updatedNotification;

      // Update unread count
      if (oldNotification.isRead != updatedNotification.isRead) {
        if (updatedNotification.isRead) {
          _unreadCount = (_unreadCount - 1).clamp(0, double.infinity).toInt();
        } else {
          _unreadCount++;
        }
      }
      notifyListeners();
    }
  }

  Future<void> loadNotifications(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      _notifications = response.map((map) => NotificationItem.fromMap(map)).toList();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('notification_id', notificationId);

      // Update local state immediately for better UX
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _unreadCount = (_unreadCount - 1).clamp(0, double.infinity).toInt();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      // Update local state
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}

// Enhanced NotificationService with better error handling
class NotificationService {
  static Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type.toString().split('.').last,
        'metadata': metadata,
        'is_read': false,
        // Don't set created_at - let Supabase handle it with NOW()
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
      rethrow; // Re-throw to handle in UI if needed
    }
  }

  static Future<void> createModificationLimitNotification({
    required String userId,
    required String equipmentName,
  }) async {
    await createNotification(
      userId: userId,
      title: 'Modification Limit Reached',
      message: 'You have reached the maximum modification limit (3 times) for "$equipmentName". You can no longer modify this request.',
      type: NotificationType.modificationLimit,
      metadata: {'equipment_name': equipmentName},
    );
  }

  static Future<void> createRequestApprovedNotification({
    required String userId,
    required String equipmentName,
  }) async {
    await createNotification(
      userId: userId,
      title: 'Request Approved!',
      message: 'Your borrow request for "$equipmentName" has been approved. Please proceed to the IT office.',
      type: NotificationType.requestApproved,
      metadata: {'equipment_name': equipmentName},
    );
  }

  static Future<void> createRequestRejectedNotification({
    required String userId,
    required String equipmentName,
    String? reason,
  }) async {
    String message = 'Your borrow request for "$equipmentName" has been rejected.';
    if (reason != null && reason.isNotEmpty) {
      message += ' Reason: $reason';
    }

    await createNotification(
      userId: userId,
      title: 'Request Rejected',
      message: message,
      type: NotificationType.requestRejected,
      metadata: {'equipment_name': equipmentName, 'reason': reason},
    );
  }
}