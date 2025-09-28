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

      // Send notification to user
      await NotificationService.createRequestApprovedNotification(
        userId: borrowerId,
        equipmentName: equipmentName,
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

      // Send notification to user
      await NotificationService.createRequestRejectedNotification(
        userId: borrowerId,
        equipmentName: equipmentName,
        reason: reason,
      );
    } catch (e) {
      throw Exception('Failed to reject request: $e');
    }
  }

  // Mark equipment as returned
  static Future<void> markAsReturned(int requestId, int equipmentId) async {
    try {
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
    } catch (e) {
      throw Exception('Failed to mark as returned: $e');
    }
  }

  // Hand out equipment (change from approved to active)
  static Future<void> handOutEquipment(int requestId, int equipmentId) async {
    try {
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
    } catch (e) {
      throw Exception('Failed to hand out equipment: $e');
    }
  }

  // Send reminder for overdue items
  static Future<void> sendReminder(
    int requestId,
    String borrowerId,
    String equipmentName,
  ) async {
    try {
      // Create a reminder notification
      await NotificationService.createNotification(
        userId: borrowerId,
        title: 'Return Reminder',
        message: 'Please return "$equipmentName" as soon as possible.',
        type: NotificationType.equipmentOverdue,
        metadata: {'equipment_name': equipmentName, 'request_id': requestId},
      );
    } catch (e) {
      throw Exception('Failed to send reminder: $e');
    }
  }

  // Extend borrowing period
  static Future<void> extendBorrowing(
    int requestId,
    DateTime newReturnDate,
  ) async {
    try {
      await supabase
          .from('borrow_requests')
          .update({'return_date': newReturnDate.toIso8601String()})
          .eq('request_id', requestId);
    } catch (e) {
      throw Exception('Failed to extend borrowing: $e');
    }
  }
}
