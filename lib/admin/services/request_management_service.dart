import '../../main.dart';
import '../../shared/notifications/notification_service.dart';

class RequestManagementService {
  // Get requests by status with user and equipment info
  static Future<List<Map<String, dynamic>>> getRequestsByStatus(
    String status,
  ) async {
    try {
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
            equipment(name, brand, image_url)
          ''')
          .eq('status', status)
          .order('created_at', ascending: false);

      // Get user info for each request
      final requestsWithUsers = <Map<String, dynamic>>[];

      for (final request in requests) {
        try {
          final userProfile = await supabase
              .from('user_profiles')
              .select('first_name, last_name, student_id')
              .eq('id', request['borrower_id'])
              .single();

          final requestWithUser = Map<String, dynamic>.from(request);
          requestWithUser['user_profiles'] = userProfile;
          requestsWithUsers.add(requestWithUser);
        } catch (e) {
          // Skip requests where user profile can't be found
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
    try {
      // Get the request details to check return date
      final request = await supabase
          .from('borrow_requests')
          .select('return_date')
          .eq('request_id', requestId)
          .single();

      final returnDate = DateTime.parse(request['return_date']);
      final daysUntilDue = returnDate.difference(DateTime.now()).inDays;

      String message;
      if (daysUntilDue < 0) {
        message = 'Your borrowed equipment "$equipmentName" is overdue by ${daysUntilDue.abs()} day(s). Please return it as soon as possible.';
      } else if (daysUntilDue == 0) {
        message = 'Your borrowed equipment "$equipmentName" is due for return today. Please return it to the IT office.';
      } else {
        message = 'Reminder: Your borrowed equipment "$equipmentName" is due for return in $daysUntilDue day(s).';
      }

      // Create notification
      await NotificationService.createNotification(
        userId: borrowerId,
        title: 'Return Reminder',
        message: message,
        type: NotificationType.equipmentOverdue,
        metadata: {
          'equipment_name': equipmentName,
          'request_id': requestId,
          'days_until_due': daysUntilDue,
        },
      );

      // Optional: Log the reminder in a separate table for tracking
      await supabase.from('reminder_logs').insert({
        'request_id': requestId,
        'borrower_id': borrowerId,
        'sent_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
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

      // Update the return date
      await supabase
          .from('borrow_requests')
          .update({'return_date': newReturnDate.toIso8601String()})
          .eq('request_id', requestId);

      // Calculate extension days
      final extensionDays = newReturnDate.difference(currentReturnDate).inDays;

      // Send notification to borrower
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
      // Update request status
      await supabase
          .from('borrow_requests')
          .update({'status': 'approved'})
          .eq('request_id', requestId);

      // Send notification to borrower
      await NotificationService.createRequestApprovedNotification(
        userId: borrowerId,
        equipmentName: equipmentName,
      );

      // Notify all admins about the approval
      await _notifyAllAdmins(
        title: 'Request Approved',
        message: 'Borrow request for "$equipmentName" has been approved.',
        type: NotificationType.general,
      );
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
      // Update request status
      await supabase
          .from('borrow_requests')
          .update({'status': 'rejected'})
          .eq('request_id', requestId);

      // Send notification to borrower
      await NotificationService.createRequestRejectedNotification(
        userId: borrowerId,
        equipmentName: equipmentName,
        reason: reason,
      );

      // Notify all admins about the rejection
      await _notifyAllAdmins(
        title: 'Request Rejected',
        message: 'Borrow request for "$equipmentName" has been rejected.',
        type: NotificationType.general,
      );
    } catch (e) {
      throw Exception('Failed to reject request: $e');
    }
  }

  // Mark equipment as returned
  static Future<void> markAsReturned(int requestId, int equipmentId) async {
    try {
      // Get borrower info first
      final request = await supabase
          .from('borrow_requests')
          .select('borrower_id, equipment(name)')
          .eq('request_id', requestId)
          .single();

      final borrowerId = request['borrower_id'];
      final equipmentName = request['equipment']['name'];

      // Update request status
      await supabase
          .from('borrow_requests')
          .update({
            'status': 'returned',
            'return_date': DateTime.now().toIso8601String(),
          })
          .eq('request_id', requestId);

      // Update equipment status to available
      await supabase
          .from('equipment')
          .update({'status': 'available'})
          .eq('equipment_id', equipmentId);

      // Notify borrower that return was confirmed
      await NotificationService.createNotification(
        userId: borrowerId,
        title: 'Return Confirmed',
        message: 'Your return of "$equipmentName" has been confirmed. Thank you!',
        type: NotificationType.equipmentReturned,
        metadata: {'equipment_name': equipmentName},
      );

      // Notify all admins about the return
      await _notifyAllAdmins(
        title: 'Equipment Returned',
        message: '"$equipmentName" has been returned.',
        type: NotificationType.equipmentReturned,
      );
    } catch (e) {
      throw Exception('Failed to mark as returned: $e');
    }
  }

  // Hand out equipment (change from approved to active)
  static Future<void> handOutEquipment(int requestId, int equipmentId) async {
    try {
      // Get request info first
      final request = await supabase
          .from('borrow_requests')
          .select('borrower_id, equipment(name)')
          .eq('request_id', requestId)
          .single();

      final borrowerId = request['borrower_id'];
      final equipmentName = request['equipment']['name'];

      // Update request status to active
      await supabase
          .from('borrow_requests')
          .update({'status': 'active'})
          .eq('request_id', requestId);

      // Update equipment status to borrowed
      await supabase
          .from('equipment')
          .update({'status': 'borrowed'})
          .eq('equipment_id', equipmentId);

      // Notify borrower that equipment is handed out
      await NotificationService.createNotification(
        userId: borrowerId,
        title: 'Equipment Handed Out',
        message: 'You have received "$equipmentName". Please return it on time.',
        type: NotificationType.general,
        metadata: {'equipment_name': equipmentName},
      );

      // Notify all admins
      await _notifyAllAdmins(
        title: 'Equipment Handed Out',
        message: '"$equipmentName" has been handed out to borrower.',
        type: NotificationType.general,
      );
    } catch (e) {
      throw Exception('Failed to hand out equipment: $e');
    }
  }

  // Helper method to notify all admins
  static Future<void> _notifyAllAdmins({
    required String title,
    required String message,
    required NotificationType type,
  }) async {
    try {
      // Get all admin user IDs
      final admins = await supabase
          .from('user_profiles')
          .select('id')
          .eq('role', 'admin');

      // Send notification to each admin
      for (final admin in admins) {
        await NotificationService.createNotification(
          userId: admin['id'],
          title: title,
          message: message,
          type: type,
        );
      }
    } catch (e) {
      print('Error notifying admins: $e');
      // Don't throw error - admin notifications failing shouldn't break the main operation
    }
  }
}