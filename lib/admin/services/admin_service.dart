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

  /// Completely deletes a borrower account and all associated data
  static Future<void> deleteBorrowerAccount(String userId) async {
    try {
      debugPrint('🗑️ Starting complete deletion of user: $userId');
      
      // Call the database function that handles complete deletion
      final response = await supabase.rpc('delete_borrower_completely', 
        params: {'target_user_id': userId}
      );
      
      debugPrint('✅ Complete user deletion successful');
      
      // Optional: Try to delete from auth system using admin API if available
      // This requires service_role key and should be done server-side in production
      try {
        await supabase.auth.admin.deleteUser(userId);
        debugPrint('✅ User also deleted from auth system');
      } catch (e) {
        debugPrint('⚠️ Warning: Could not delete user from auth system: $e');
        debugPrint('   User profile and data deleted, but auth record may remain');
        // Continue anyway as the main data is already deleted
      }
      
    } catch (e) {
      debugPrint('❌ Error during complete user deletion: $e');
      throw 'Failed to completely delete user: $e';
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