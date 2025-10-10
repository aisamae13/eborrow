// admin_service.dart

import 'package:flutter/material.dart';
import '/main.dart';

class AdminService {
  /// Toggle user suspension status
  static Future<void> toggleSuspendUser(String userId, bool suspend) async {
    try {
      debugPrint('${suspend ? "Suspending" : "Unsuspending"} user: $userId');

      // First, get user details for logging
      final userProfileResponse = await supabase
          .from('user_profiles')
          .select('email, first_name, last_name')
          .eq('id', userId)
          .maybeSingle(); // Use maybeSingle() to handle cases where user doesn't exist

      if (userProfileResponse == null) {
        throw 'User not found';
      }

      final userEmail = userProfileResponse['email'] ?? 'Unknown';
      final userName = '${userProfileResponse['first_name'] ?? ''} ${userProfileResponse['last_name'] ?? ''}'.trim();

      // Update suspension status
      await supabase
          .from('user_profiles')
          .update({'is_suspended': suspend})
          .eq('id', userId);

      // Log the action
      await supabase.from('admin_activity_logs').insert({
        'admin_id': supabase.auth.currentUser!.id,
        'action_type': suspend ? 'suspend' : 'unsuspend',
        'target_user_id': userId,
        'target_user_email': userEmail,
        'target_user_name': userName,
      });

      debugPrint('User suspension status updated successfully.');
    } catch (e) {
      debugPrint('Error toggling suspend: $e');
      rethrow;
    }
  }

  /// Deletes a borrower account and logs the admin action
  static Future<void> deleteBorrowerAccount(String userId) async {
    try {
      // Get user details before deletion for logging purposes
      final userDetailsResponse = await supabase
          .from('user_profiles')
          .select('first_name, last_name, email')
          .eq('id', userId)
          .maybeSingle(); // Use maybeSingle() instead of single()
      
      if (userDetailsResponse == null) {
        throw 'User not found or already deleted';
      }
      
      final firstName = userDetailsResponse['first_name'] as String? ?? '';
      final lastName = userDetailsResponse['last_name'] as String? ?? '';
      final email = userDetailsResponse['email'] as String? ?? '';
      final fullName = '$firstName $lastName'.trim();
      
      // Delete operations in the correct order (without transactions for now)
      
      // 1. Delete user's notifications
      await supabase.from('notifications')
          .delete()
          .eq('user_id', userId);
      
      // 2. Cancel user's pending/approved borrow requests (use the correct syntax)
      await supabase.from('borrow_requests')
          .update({'status': 'cancelled'})
          .eq('borrower_id', userId)
          .inFilter('status', ['pending', 'approved']); // Fixed: use inFilter() instead of in_()
      
      // 3. Log the admin action BEFORE deleting the profile
      await supabase.from('admin_activity_logs').insert({
        'admin_id': supabase.auth.currentUser!.id,
        'action_type': 'delete',
        'target_user_id': userId,
        'target_user_email': email,
        'target_user_name': fullName,
        'details': 'User account deleted by admin',
        'metadata': {
          'timestamp': DateTime.now().toIso8601String(),
        }
      });
      
      // 4. Delete user profile
      await supabase.from('user_profiles')
          .delete()
          .eq('id', userId);
      
      // 5. Finally, delete the user from auth system (if using admin API)
      try {
        await supabase.auth.admin.deleteUser(userId);
      } catch (e) {
        debugPrint('Warning: Could not delete user from auth system: $e');
        // Continue anyway as the profile is already deleted
      }
      
      debugPrint('User account deleted successfully');
      
    } catch (e) {
      debugPrint('Error deleting user: $e');
      throw 'Failed to delete user: $e';
    }
  }

  /// Reset user password by sending reset email
  static Future<void> resetUserPassword(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(email);
      
      // Log the admin action
      await supabase.from('admin_activity_logs').insert({
        'admin_id': supabase.auth.currentUser!.id,
        'action_type': 'reset_password',
        'target_user_email': email,
        'details': 'Password reset email sent by admin',
        'metadata': {
          'timestamp': DateTime.now().toIso8601String(),
        }
      });
      
    } catch (e) {
      debugPrint('Error resetting password: $e');
      rethrow;
    }
  }
}