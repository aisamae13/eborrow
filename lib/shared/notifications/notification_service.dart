import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibration/vibration.dart'; // 🆕 NEW: Import vibration package
import '/main.dart';

// Enhanced NotificationItem class
enum NotificationType {
  modificationLimit,
  requestApproved,
  requestRejected,
  equipmentOverdue,
  equipmentReturned,
  returnReminder, // 🆕 NEW: For local return reminders
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
  final bool isLocal; // 🆕 NEW: Flag for local notifications

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
    this.isLocal = false, // 🆕 NEW: Default to false for DB notifications
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
      isLocal: false, // DB notifications are never local
    );
  }

  // 🆕 NEW: Factory for local notifications
  factory NotificationItem.local({
    required String id,
    required String title,
    required String message,
    required NotificationType type,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationItem(
      id: id,
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      isRead: false,
      metadata: metadata,
      isLocal: true,
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
    bool? isLocal,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
      isLocal: isLocal ?? this.isLocal,
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
      case NotificationType.returnReminder: // 🆕 NEW
        return Icons.schedule;
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
        return Colors.red;
      case NotificationType.equipmentReturned:
        return Colors.blue;
      case NotificationType.returnReminder: // 🆕 NEW
        return Colors.orange;
      case NotificationType.general:
        return Colors.grey;
    }
  }

  // 🆕 NEW: Method to check if notification should vibrate
  bool get shouldVibrate {
    switch (type) {
      case NotificationType.equipmentOverdue:
        return true; // Vibrate for overdue equipment
      case NotificationType.returnReminder:
        return metadata?['is_urgent'] == true; // Vibrate for urgent reminders
      default:
        return false;
    }
  }
}

// 🆕 NEW: Vibration Helper Class
class VibrationHelper {
  static bool _vibrationEnabled = true;
  static bool _hasVibrator = false;

  static Future<void> initialize() async {
    try {
      _hasVibrator = await Vibration.hasVibrator() ?? false;
      debugPrint('🔸 Vibration support detected: $_hasVibrator');
    } catch (e) {
      debugPrint('❌ Error checking vibration support: $e');
      _hasVibrator = false;
    }
  }

  static void enableVibration(bool enabled) {
    _vibrationEnabled = enabled;
    debugPrint('🔸 Vibration ${enabled ? 'enabled' : 'disabled'}');
  }

  static Future<void> vibrateForNotification(NotificationType type) async {
    if (!_vibrationEnabled || !_hasVibrator) return;

    try {
      switch (type) {
        case NotificationType.equipmentOverdue:
          // Strong vibration pattern for overdue equipment (urgent)
          await Vibration.vibrate(
            duration: 1000, // 1 second
            amplitude: 255, // Max intensity
          );
          // Wait and vibrate again
          await Future.delayed(const Duration(milliseconds: 500));
          await Vibration.vibrate(
            duration: 1000,
            amplitude: 255,
          );
          debugPrint('📳 Strong vibration for overdue equipment');
          break;

        case NotificationType.returnReminder:
          // Medium vibration for return reminders
          await Vibration.vibrate(
            duration: 500, // 0.5 seconds
            amplitude: 180,
          );
          debugPrint('📳 Medium vibration for return reminder');
          break;

        case NotificationType.requestApproved:
        case NotificationType.requestRejected:
          // Light vibration for request updates
          await Vibration.vibrate(
            duration: 200,
            amplitude: 100,
          );
          debugPrint('📳 Light vibration for request update');
          break;

        default:
          // Default light vibration
          await Vibration.vibrate(duration: 150);
          debugPrint('📳 Default vibration');
          break;
      }
    } catch (e) {
      debugPrint('❌ Error vibrating: $e');
    }
  }

  static Future<void> vibratePattern(List<int> pattern) async {
    if (!_vibrationEnabled || !_hasVibrator) return;

    try {
      await Vibration.vibrate(pattern: pattern);
    } catch (e) {
      debugPrint('❌ Error vibrating pattern: $e');
    }
  }

  // 🆕 NEW: Custom vibration patterns
  static Future<void> vibrateOverdueAlert() async {
    // Pattern: vibrate 500ms, pause 300ms, vibrate 500ms, pause 300ms, vibrate 1000ms
    const pattern = [0, 500, 300, 500, 300, 1000];
    await vibratePattern(pattern);
    debugPrint('📳 Overdue alert vibration pattern');
  }

  static Future<void> vibrateUrgentReminder() async {
    // Pattern: quick bursts - vibrate 200ms, pause 100ms, repeat 3 times
    const pattern = [0, 200, 100, 200, 100, 200];
    await vibratePattern(pattern);
    debugPrint('📳 Urgent reminder vibration pattern');
  }
}

// 🆕 NEW: Enhanced Local Return Reminder Service with Overdue Detection
class LocalReminderService {
  static Timer? _reminderTimer;
  static Timer? _overdueCheckTimer; // 🆕 NEW: Timer for overdue checks
  static final Map<String, Timer> _activeReminders = {};
  static final Set<String> _notifiedOverdueRequests = {}; // 🆕 NEW: Track notified overdue requests
  static NotificationProvider? _notificationProvider;

  static void initialize(NotificationProvider provider) {
    _notificationProvider = provider;
    _startMonitoring();
    _startOverdueMonitoring(); // 🆕 NEW: Start overdue monitoring
  }

  static void dispose() {
    _reminderTimer?.cancel();
    _overdueCheckTimer?.cancel(); // 🆕 NEW: Cancel overdue timer
    _clearAllReminders();
    _notifiedOverdueRequests.clear(); // 🆕 NEW: Clear overdue tracking
  }

  static void _startMonitoring() {
    // Check for reminders every minute
    _reminderTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkForReminders();
    });
    debugPrint('🔔 Local reminder monitoring started');
  }

  // 🆕 NEW: Monitor for overdue equipment
  static void _startOverdueMonitoring() {
    // Check for overdue equipment every 5 minutes
    _overdueCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkForOverdueEquipment();
    });
    debugPrint('⚠️ Overdue monitoring started');
  }

  // 🆕 NEW: Check for overdue equipment and create notifications with vibration
  static Future<void> _checkForOverdueEquipment() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch overdue borrowings
      final response = await supabase
          .from('borrow_requests')
          .select('request_id, return_date, equipment(name)')
          .eq('borrower_id', userId)
          .inFilter('status', ['active'])
          .order('return_date', ascending: true);

      final now = DateTime.now();
      
      for (final request in response) {
        final requestId = request['request_id'].toString();
        final returnDate = DateTime.parse(request['return_date']);
        final equipmentName = request['equipment']['name'] ?? 'Equipment';
        
        // Check if equipment is overdue (past return date)
        if (now.isAfter(returnDate)) {
          // Only notify once per overdue request
          if (!_notifiedOverdueRequests.contains(requestId)) {
            final hoursOverdue = now.difference(returnDate).inHours;
            
            // Create overdue notification
            final notification = NotificationItem.local(
              id: 'overdue_$requestId',
              title: '🚨 Equipment Overdue!',
              message: 'Your borrowed "$equipmentName" is overdue by $hoursOverdue hours. Please return it immediately to avoid penalties!',
              type: NotificationType.equipmentOverdue,
              metadata: {
                'equipment_name': equipmentName,
                'request_id': requestId,
                'hours_overdue': hoursOverdue,
                'return_date': returnDate.toIso8601String(),
              },
            );

            _notificationProvider?.addLocalNotification(notification);
            
            // 🚨 VIBRATE FOR OVERDUE EQUIPMENT
            await VibrationHelper.vibrateOverdueAlert();
            
            // Mark as notified to prevent spam
            _notifiedOverdueRequests.add(requestId);
            
            debugPrint('🚨 Created overdue notification for $equipmentName ($hoursOverdue hours overdue)');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking for overdue equipment: $e');
    }
  }

  static Future<void> _checkForReminders() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch active borrowings
      final response = await supabase
          .from('borrow_requests')
          .select('request_id, return_date, equipment(name)')
          .eq('borrower_id', userId)
          .inFilter('status', ['active'])
          .order('return_date', ascending: true);

      final now = DateTime.now();
      
      for (final request in response) {
        final requestId = request['request_id'].toString();
        final returnDate = DateTime.parse(request['return_date']);
        final equipmentName = request['equipment']['name'] ?? 'Equipment';
        
        final minutesUntilDue = returnDate.difference(now).inMinutes;
        
        // Schedule 15-minute reminder
        if (minutesUntilDue <= 15 && minutesUntilDue > 5) {
          _scheduleReminder(
            requestId: requestId,
            equipmentName: equipmentName,
            minutesRemaining: minutesUntilDue,
            isUrgent: false,
          );
        }
        // Schedule 5-minute urgent reminder with vibration
        else if (minutesUntilDue <= 5 && minutesUntilDue > 0) {
          _scheduleReminder(
            requestId: requestId,
            equipmentName: equipmentName,
            minutesRemaining: minutesUntilDue,
            isUrgent: true,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking for reminders: $e');
    }
  }

  static void _scheduleReminder({
    required String requestId,
    required String equipmentName,
    required int minutesRemaining,
    required bool isUrgent,
  }) {
    final reminderId = '${requestId}_${isUrgent ? '5min' : '15min'}';
    
    // Don't schedule if already scheduled
    if (_activeReminders.containsKey(reminderId)) return;

    debugPrint('🔔 Scheduling ${isUrgent ? 'urgent' : 'regular'} reminder for $equipmentName');

    // Create and add local notification immediately
    final notification = NotificationItem.local(
      id: 'reminder_$reminderId',
      title: isUrgent ? '⚠️ Return Due Soon!' : '⏰ Return Reminder',
      message: isUrgent 
          ? 'Your borrowed "$equipmentName" is due in $minutesRemaining minutes. Please return it immediately!'
          : 'Your borrowed "$equipmentName" is due in $minutesRemaining minutes. Start preparing to return it.',
      type: NotificationType.returnReminder,
      metadata: {
        'equipment_name': equipmentName,
        'request_id': requestId,
        'minutes_remaining': minutesRemaining,
        'is_urgent': isUrgent,
      },
    );

    _notificationProvider?.addLocalNotification(notification);

    // 🚨 VIBRATE FOR URGENT REMINDERS
    if (isUrgent) {
      VibrationHelper.vibrateUrgentReminder();
    }

    // Set timer to clean up after 5 minutes
    _activeReminders[reminderId] = Timer(const Duration(minutes: 5), () {
      _activeReminders.remove(reminderId);
    });
  }

  static void _clearAllReminders() {
    for (final timer in _activeReminders.values) {
      timer.cancel();
    }
    _activeReminders.clear();
  }

  static void cancelRemindersForRequest(String requestId) {
    final keysToRemove = _activeReminders.keys
        .where((key) => key.startsWith(requestId))
        .toList();
    
    for (final key in keysToRemove) {
      _activeReminders[key]?.cancel();
      _activeReminders.remove(key);
    }
    
    // Also remove from overdue tracking when equipment is returned
    _notifiedOverdueRequests.remove(requestId);
    
    debugPrint('🔕 Cancelled reminders for request $requestId');
  }
}

// Enhanced Real-time Notification Provider
class NotificationProvider extends ChangeNotifier {
  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  RealtimeChannel? _subscription;
  String? _currentUserId; // 🆕 NEW: Track current user ID

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get currentUserId => _currentUserId; // 🚀 NEW: Expose current user ID

  void initializeRealtime(String userId) {
    // 🚀 IMPROVED: Better initialization logic
    final bool userChanged = _currentUserId != userId;
    final bool hasExistingSubscription = _subscription != null;
    
    if (!userChanged && hasExistingSubscription && _notifications.isNotEmpty) {
      debugPrint('📋 User unchanged ($userId), subscription active, data exists - skipping reinitialization');
      return;
    }

    debugPrint('🔄 Initializing notifications for user: $userId (previous: $_currentUserId, userChanged: $userChanged)');
    _currentUserId = userId;
    
    // Only unsubscribe if user changed
    if (userChanged) {
      _subscription?.unsubscribe();
      _notifications.clear(); // Clear previous user's notifications
      _unreadCount = 0;
    }
    
    // 🚀 IMPROVED: Set loading state only if we don't have data
    if (_notifications.isEmpty) {
      _isLoading = true;
      notifyListeners(); // Notify immediately for loading state
    }
    
    loadNotifications(userId); // Load initial data
    
    // 🆕 NEW: Initialize local reminder service and vibration
    LocalReminderService.initialize(this);
    VibrationHelper.initialize(); // 🆕 NEW: Initialize vibration support

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

  // 🆕 NEW: Clear notifications method for account switching
  void clearNotifications() {
    debugPrint('🧹 Clearing all notifications');
    _subscription?.unsubscribe();
    _subscription = null;
    _currentUserId = null;
    _notifications.clear();
    _unreadCount = 0;
    _isLoading = false;
    LocalReminderService.dispose();
    notifyListeners();
  }

  // 🆕 NEW: Add local notification method with vibration
  void addLocalNotification(NotificationItem notification) {
    // Check if similar notification already exists
    final exists = _notifications.any((n) => 
        n.isLocal && 
        n.metadata?['request_id'] == notification.metadata?['request_id'] &&
        n.metadata?['is_urgent'] == notification.metadata?['is_urgent']
    );

    if (!exists) {
      _notifications.insert(0, notification);
      _unreadCount++;
      
      // 🚨 VIBRATE FOR QUALIFYING NOTIFICATIONS
      if (notification.shouldVibrate) {
        VibrationHelper.vibrateForNotification(notification.type);
      }
      
      debugPrint('🔔 Added local notification: ${notification.title}');
      notifyListeners();
    }
  }

  void _handleNewNotification(PostgresChangePayload payload) {
    debugPrint('🆕 New notification received: ${payload.newRecord}');
    final newNotification = NotificationItem.fromMap(payload.newRecord);
    _notifications.insert(0, newNotification);
    if (!newNotification.isRead) {
      _unreadCount++;
    }
    
    // 🚨 VIBRATE FOR QUALIFYING DB NOTIFICATIONS
    if (newNotification.shouldVibrate) {
      VibrationHelper.vibrateForNotification(newNotification.type);
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

      // 3. Fast local processing - keep local notifications at top
      final dbNotifications = (response as List)
          .map((map) => NotificationItem.fromMap(map))
          .toList();
      
      // Merge with existing local notifications
      final localNotifications = _notifications.where((n) => n.isLocal).toList();
      _notifications = [...localNotifications, ...dbNotifications];
      
      _unreadCount = _notifications.where((n) => !n.isRead).length;

      debugPrint('✅ Loaded ${_notifications.length} notifications, $_unreadCount unread');
      debugPrint('📋 Notification details:');
      for (var n in _notifications.take(5)) {
        debugPrint('   - ${n.title}: isRead=${n.isRead}, id=${n.id}, isLocal=${n.isLocal}');
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
    // Handle local notifications differently
    final notification = _notifications.firstWhere((n) => n.id == notificationId);
    
    if (notification.isLocal) {
      // For local notifications, just update the local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _unreadCount = (_unreadCount - 1).clamp(0, double.infinity).toInt();
        debugPrint('✅ Marked local notification as read - New unread count: $_unreadCount');
        notifyListeners();
      }
      return;
    }

    // Handle database notifications as before
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

      // Mark all database notifications as read
      final response = await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false)
          .select();

      debugPrint('✅ Marked all notifications as read: ${response.length} updated');

      // Update local state for all notifications (including local ones)
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
    LocalReminderService.dispose(); // 🆕 NEW: Clean up reminder service
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

  // 🚨 ENHANCED: Overdue notification with vibration support
  static Future<void> createEquipmentOverdueNotification({
    required String userId, // This should be the borrower's ID for vibration
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