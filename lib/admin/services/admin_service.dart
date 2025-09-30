// admin_service.dart

import '/main.dart';
import 'package:flutter/material.dart';

class AdminService {
  /// Toggle user suspension status
  static Future<void> toggleSuspendUser(String userId, bool suspend) async {
    try {
      debugPrint('${suspend ? "Suspending" : "Unsuspending"} user: $userId');

      // First, get user details for logging
      final userProfile = await supabase
          .from('user_profiles')
          .select('email, first_name, last_name')
          .eq('id', userId)
          .single();

      final userEmail = userProfile['email'] ?? 'Unknown';
      final userName = '${userProfile['first_name'] ?? ''} ${userProfile['last_name'] ?? ''}'.trim();

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

  /// Delete a borrower account by calling the Edge Function
  static Future<void> deleteBorrowerAccount(String userId) async {
    try {
      debugPrint('Calling Edge Function to delete user: $userId');

      // Get user details for logging before deletion
      final userProfile = await supabase
          .from('user_profiles')
          .select('email, first_name, last_name')
          .eq('id', userId)
          .single();

      final userEmail = userProfile['email'] ?? 'Unknown';
      final userName = '${userProfile['first_name'] ?? ''} ${userProfile['last_name'] ?? ''}'.trim();

      // Get current user's access token
      final session = supabase.auth.currentSession;
      if (session == null) {
        throw Exception('No active session');
      }

      final response = await supabase.functions.invoke(
        'delete-user',
        body: {'userId': userId},
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );

      debugPrint('Edge Function response status: ${response.status}');
      debugPrint('Edge Function response data: ${response.data}');

      if (response.status != 200) {
        final errorMessage = response.data is Map
            ? (response.data['error'] ?? 'Failed to delete user')
            : 'Failed to delete user';
        throw Exception(errorMessage);
      }

      // Log the deletion
      await supabase.from('admin_activity_logs').insert({
        'admin_id': supabase.auth.currentUser!.id,
        'action_type': 'delete',
        'target_user_id': userId,
        'target_user_email': userEmail,
        'target_user_name': userName,
        'details': 'User account permanently deleted',
      });

      debugPrint('User deletion completed successfully.');
    } catch (e) {
      debugPrint('Error calling delete-user Edge Function: $e');
      rethrow;
    }
  }

  /// Alternative: Soft delete (recommended for data retention)
  static Future<void> softDeleteBorrowerAccount(String userId) async {
    try {
      debugPrint('Soft deleting user: $userId');

      await supabase
          .from('user_profiles')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'is_suspended': true,
          })
          .eq('id', userId);

      debugPrint('User soft deleted successfully.');
    } catch (e) {
      debugPrint('Error soft deleting user: $e');
      rethrow;
    }
  }
}