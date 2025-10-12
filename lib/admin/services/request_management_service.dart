import 'package:flutter/material.dart';

import '../../shared/notifications/notification_service.dart';
import '../../main.dart';

class RequestManagementService {
  // Get requests by status with user and equipment info
  static Future<void> scanOverdueRequests() async {
    try {
      await supabase.rpc('scan_overdue_requests');
    } catch (e) {
      print('Error scanning overdue requests: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getRequestsByStatus(
    String status,
  ) async {
    try {
      // Scan for overdue requests before fetching
      await scanOverdueRequests();

      final requests = await supabase
          .from('borrow_requests')
          .select('''
            request_id,
            borrower_id,
            equipment_id,
            borrow_date,
            return_date,
            purpose,
            status,
            created_at,
            modification_count,
            rejection_reason,
            equipment(name, brand, image_url)
          ''')
          .eq('status', status)
          .order('created_at', ascending: false);

      // Rest of your existing code...
      final requestsWithUsers = <Map<String, dynamic>>[];

      for (final request in requests) {
        try {
          final userProfile = await supabase
              .from('user_profiles')
              .select('first_name, last_name, student_id, avatar_url')
              .eq('id', request['borrower_id'])
              .single();

          final requestWithUser = Map<String, dynamic>.from(request);
          requestWithUser['user_profiles'] = userProfile;
          requestsWithUsers.add(requestWithUser);
        } catch (e) {
          print(
            'Could not find user profile for borrower_id: ${request['borrower_id']}',
          );
          continue;
        }
      }

      return requestsWithUsers;
    } catch (e) {
      print('Error loading requests: $e');
      throw Exception('Failed to load requests: $e');
    }
  }

  static Future<void> sendReminder(
    int requestId,
    String borrowerId,
    String equipmentName,
  ) async {
    // Keep a precise error for notification failure; other ops are best-effort.
    try {
      // 1) Admin activity log (use allowed action_type values; put details about the reminder)
      try {
        await supabase.from('admin_activity_logs').insert({
          'admin_id': supabase.auth.currentUser!.id,
          'action_type': 'update', // limited to allowed enum in schema
          'target_user_id': borrowerId,
          'target_user_email': null,
          'target_user_name': null,
          'details': 'Sent return reminder for "$equipmentName" (request_id: $requestId)',
          'metadata': {
            'request_id': requestId,
            'equipment_name': equipmentName,
            'action': 'send_reminder'
          },
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        // non-fatal: admin log failed (RLS or missing table). Keep going.
        debugPrint('Warning: failed to write admin_activity_logs entry: $e');
      }

      // 2) Create the in-app notification (THIS is the critical piece)
      try {
        await NotificationService.createNotification(
          userId: borrowerId,
          title: 'Return Reminder',
          message: 'Please remember to return "$equipmentName" soon.',
          type: NotificationType.returnReminder,
          metadata: {
            'equipment_name': equipmentName,
            'request_id': requestId,
            'sent_by_admin': supabase.auth.currentUser?.id,
          },
        );
      } catch (e) {
        // If this fails, surface the error to callers so UI can show it.
        debugPrint('Error creating notification: $e');
        throw Exception('Failed to send notification: $e');
      }

      // 3) Try to record the reminder in reminder_logs (optional; non-fatal if missing)
      try {
        await supabase.from('reminder_logs').insert({
          'request_id': requestId,
          'borrower_id': borrowerId,
          'sent_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        // Likely missing table or RLS; don't fail the whole flow.
        debugPrint('Notice: could not insert reminder_logs (non-fatal): $e');
      }

      // 4) Update borrow_requests.last_reminder_sent to help auditing (best-effort)
      try {
        await supabase
            .from('borrow_requests')
            .update({'last_reminder_sent': DateTime.now().toIso8601String()})
            .eq('request_id', requestId);
      } catch (e) {
        debugPrint('Warning: could not update borrow_requests.last_reminder_sent: $e');
      }

      // success
      return;
    } catch (e) {
      // bubble up notification failures or unexpected errors
      throw Exception('Failed to send reminder: $e');
    }
  }

  /// Extends the borrowing period for a request
  static Future<void> extendBorrowing(
    int requestId,
    DateTime newReturnDate,
  ) async {
    try {
      // Get current request details
      final request = await supabase
          .from('borrow_requests')
          .select('return_date, borrower_id, equipment(name)')
          .eq('request_id', requestId)
          .single();

      final currentReturnDate = DateTime.parse(request['return_date']);
      final borrowerId = request['borrower_id'];
      final equipmentName = request['equipment']['name'];

      // Validate that new date is after current return date
      if (newReturnDate.isBefore(currentReturnDate)) {
        throw Exception('New return date must be after the current return date');
      }

      // Update the return date (This does not change the 'status', so no trigger needed)
      await supabase
          .from('borrow_requests')
          .update({'return_date': newReturnDate.toIso8601String()})
          .eq('request_id', requestId);

      // Calculate extension days
      final extensionDays = newReturnDate.difference(currentReturnDate).inDays;

      // Send notification to borrower (This is not a status change, so it remains here)
      await NotificationService.createNotification(
        userId: borrowerId,
        title: 'Borrowing Period Extended',
        message: 'Your borrowing period for "$equipmentName" has been extended by $extensionDays day(s). New return date: ${_formatDate(newReturnDate)}',
        type: NotificationType.general,
        metadata: {
          'equipment_name': equipmentName,
          'request_id': requestId,
          'extension_days': extensionDays,
          'new_return_date': newReturnDate.toIso8601String(),
        },
      );

      // Optional: Log the extension
      await supabase.from('extension_logs').insert({
        'request_id': requestId,
        'borrower_id': borrowerId,
        'old_return_date': currentReturnDate.toIso8601String(),
        'new_return_date': newReturnDate.toIso8601String(),
        'extension_days': extensionDays,
        'extended_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to extend borrowing period: $e');
    }
  }

  /// Helper function to format date
  static String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // Approve a request
  static Future<void> approveRequest(
    int requestId,
    String borrowerId,
    String equipmentName,
  ) async {
    try {
      // ✅ FIX: Update request status. The DB trigger handles ALL notifications.
      await supabase
          .from('borrow_requests')
          .update({'status': 'approved'})
          .eq('request_id', requestId);

      // ❌ REMOVED: All manual notification calls are deleted.
    } catch (e) {
      throw Exception('Failed to approve request: $e');
    }
  }

  // Reject a request
  static Future<void> rejectRequest(
    int requestId,
    String borrowerId,
    String equipmentName, {
    String? reason,
  }) async {
    try {
      // ✅ FIX: Update status to 'rejected'. The DB trigger handles ALL notifications.
      await supabase
        .from('borrow_requests')
        .update({
          'status': 'cancelled',
          'rejection_reason': reason,
        })
        .eq('request_id', requestId);

      // ❌ REMOVED: All manual notification calls are deleted.
    } catch (e) {
      throw Exception('Failed to reject request: $e');
    }
  }

  // Mark equipment as returned
  static Future<void> markAsReturned(int requestId, int equipmentId) async {
    try {
      // Get borrower info first (needed for the DB trigger's message)
      await supabase
          .from('borrow_requests')
          .select('borrower_id, equipment(name)')
          .eq('request_id', requestId)
          .single();


      // ✅ FIX: Update request status. The DB trigger handles ALL notifications.
      await supabase
          .from('borrow_requests')
          .update({
            'status': 'returned',
            'return_date': DateTime.now().toIso8601String(),
          })
          .eq('request_id', requestId);

      // Update equipment status to available (KEEP THIS)
      await supabase
          .from('equipment')
          .update({'status': 'available'})
          .eq('equipment_id', equipmentId);

      // ❌ REMOVED: All manual notification calls are deleted.
    } catch (e) {
      throw Exception('Failed to mark as returned: $e');
    }
  }

  // Hand out equipment (change from approved to active)
  static Future<void> handOutEquipment(int requestId, int equipmentId) async {
    try {
      // Get request info first (needed for the DB trigger's message)
      final request = await supabase
          .from('borrow_requests')
          .select('borrower_id, equipment(name)')
          .eq('request_id', requestId)
          .single();

      final _ = request['borrower_id'];

      // ✅ FIX: Update request status to active. The DB trigger handles ALL notifications.
      await supabase
          .from('borrow_requests')
          .update({'status': 'active'})
          .eq('request_id', requestId);

      // Update equipment status to borrowed (KEEP THIS)
      await supabase
          .from('equipment')
          .update({'status': 'borrowed'})
          .eq('equipment_id', equipmentId);

      // ❌ REMOVED: All manual notification calls are deleted.
    } catch (e) {
      throw Exception('Failed to hand out equipment: $e');
    }
  }
}