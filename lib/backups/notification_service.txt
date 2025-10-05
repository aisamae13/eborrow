import 'dart:async';

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
    debugPrint('🔍 FromMap - Raw data: $map');
    debugPrint('🔍 FromMap - is_read value: ${map['is_read']} (type: ${map['is_read'].runtimeType})');

    return NotificationItem(
      id: map['notification_id'].toString(),
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${map['type']}',
        orElse: () => NotificationType.general,
      ),
      timestamp: DateTime.parse(map['created_at']).toLocal(),
      isRead: map['is_read'] == true,
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

  void initializeRealtime(String userId) {
    _subscription?.unsubscribe();
    loadNotifications(userId); // Load initial data

    try {
      // 🚀 EFFICIENCY FIX: Filter real-time events by user_id to reduce traffic and processing.
      _subscription = supabase
          .channel('user_$userId') // Use a user-specific channel name
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            // Filter: Only listen for inserts where user_id matches
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,   // 👈 FIX IS HERE
              column: 'user_id',
              value: userId,
            ),
            callback: _handleNewNotification,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'notifications',
            // Filter: Only listen for updates where user_id matches
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,   // 👈 FIX IS HERE
              column: 'user_id',
              value: userId,
            ),
            callback: _handleUpdatedNotification,
          )
          .subscribe();
      debugPrint('🟢 Real-time subscribed for user: $userId');
    } catch (e) {
      debugPrint('❌ Real-time subscription failed: $e');
    }
  }


  void _handleNewNotification(PostgresChangePayload payload) {
    debugPrint('🆕 New notification received: ${payload.newRecord}');
    final newNotification = NotificationItem.fromMap(payload.newRecord);
    _notifications.insert(0, newNotification);
    if (!newNotification.isRead) {
      _unreadCount++;
    }
    debugPrint('📊 After insert - Total: ${_notifications.length}, Unread: $_unreadCount');
    notifyListeners();
  }

  void _handleUpdatedNotification(PostgresChangePayload payload) {
    debugPrint('🔄 Updated notification received: ${payload.newRecord}');
    final updatedNotification = NotificationItem.fromMap(payload.newRecord);
    final index = _notifications.indexWhere((n) => n.id == updatedNotification.id);

    if (index != -1) {
      final oldNotification = _notifications[index];
      debugPrint('📝 Old notification isRead: ${oldNotification.isRead}');
      debugPrint('📝 New notification isRead: ${updatedNotification.isRead}');

      _notifications[index] = updatedNotification;

      if (oldNotification.isRead != updatedNotification.isRead) {
        if (updatedNotification.isRead) {
          _unreadCount = (_unreadCount - 1).clamp(0, double.infinity).toInt();
          debugPrint('✅ Marked as read - New unread count: $_unreadCount');
        } else {
          _unreadCount++;
          debugPrint('📬 Marked as unread - New unread count: $_unreadCount');
        }
      }
      notifyListeners();
    } else {
      debugPrint('⚠️ Could not find notification with id: ${updatedNotification.id}');
    }
  }

  Future<void> loadNotifications(String userId) async {
    // 1. Immediately set loading state and notify to show spinner fast
    _isLoading = true;
    notifyListeners();

    final startTime = DateTime.now(); // ⏱️ Start timer for debugging

    try {
      debugPrint('📥 Loading notifications for user: $userId');

      // 2. Efficient database query (Filtering, sorting, and limiting to 50 is good)
      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('✅ Supabase fetch complete in $duration ms. Start processing.');
      // NOTE: If $duration is high, ensure 'user_id' is indexed in your Supabase DB.

      debugPrint('📦 Raw response from Supabase: $response');

      // 3. Fast local processing
      _notifications = (response as List)
          .map((map) => NotificationItem.fromMap(map))
          .toList();
      _unreadCount = _notifications.where((n) => !n.isRead).length;

      debugPrint('✅ Loaded ${_notifications.length} notifications, $_unreadCount unread');
      debugPrint('📋 Notification details:');
      for (var n in _notifications) {
        debugPrint('   - ${n.title}: isRead=${n.isRead}, id=${n.id}');
      }
    } catch (e) {
      debugPrint('❌ Error loading notifications: $e');
    } finally {
      // 4. Update state *once* after all processing
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      debugPrint('🔵 Attempting to mark notification $notificationId as read');

      // Update the database
      final response = await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('notification_id', notificationId)
          .select(); // Returns the updated row(s)

      debugPrint('✅ Update response: $response');

      // 🚨 FIX: Only update local state if the database confirmed the change
      if (response.isNotEmpty) {
        // Find the record in the returned response to get the confirmed data
        final updatedRecord = response[0];
        final updatedNotification = NotificationItem.fromMap(updatedRecord);

        debugPrint('🔍 Notification after confirmed update: $updatedRecord');
        debugPrint('🔍 is_read value after confirmed update: ${updatedRecord['is_read']}');

        // Update local state immediately for better UX
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1 && !_notifications[index].isRead) {
          // Use the data returned from the database, which should now have isRead: true
          _notifications[index] = updatedNotification;
          _unreadCount = (_unreadCount - 1).clamp(0, double.infinity).toInt();
          debugPrint('📊 Local state updated - New unread count: $_unreadCount');
          notifyListeners();
        }
      } else {
        // If the response is empty, the update failed.
        debugPrint('❌ Supabase update failed: No rows were updated. Check RLS or the notificationId.');
        // Optionally, rethrow a specific error or show a user-facing message here.
      }

    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      rethrow;
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      debugPrint('🔵 Marking all notifications as read for user: $userId');

      final response = await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false)
          .select();

      debugPrint('✅ Marked all notifications as read: ${response.length} updated');

      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
      rethrow;
    }
  }

  @override
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
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
      rethrow;
    }
  }

  static Future<List<NotificationItem>> fetchNotificationsList(String userId) async {
    try {
      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // Map the raw Supabase response to your NotificationItem model
      return response.map((map) => NotificationItem.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error fetching notifications list: $e');
      // Return an empty list on failure
      return [];
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

  // ⚠️ REMOVED: createRequestApprovedNotification (Now handled by DB trigger)
  // ⚠️ REMOVED: createRequestRejectedNotification (Now handled by DB trigger)
  // ⚠️ REMOVED: createEquipmentReturnedNotification (Now handled by DB trigger)

  static Future<void> createEquipmentOverdueNotification({
    required String userId, // This should probably be the admin's ID
    required String userName,
    required String equipmentName,
  }) async {
    await createNotification(
      userId: userId,
      title: 'Equipment Overdue!',
      message: 'The equipment "$equipmentName" borrowed by $userName is now overdue.',
      type: NotificationType.equipmentOverdue,
      metadata: {'equipment_name': equipmentName, 'user_name': userName},
    );
  }
}