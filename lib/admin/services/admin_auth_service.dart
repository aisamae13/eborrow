import 'package:flutter/material.dart'; // Add this for debugPrint
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';

class AdminAuthService {
  static Future<bool> isAdmin() async {
    final user = supabase.auth.currentUser;

    // Add debugging
    debugPrint('=== ADMIN CHECK DEBUG ===');
    debugPrint('Current user: ${user?.email}');
    debugPrint('User ID: ${user?.id}');

    if (user == null) {
      debugPrint('No user found');
      return false;
    }

    try {
      final profile = await supabase
          .from('user_profiles')
          .select(
            'role, email, first_name, last_name',
          ) // Select more fields for debugging
          .eq('id', user.id)
          .single();

      // Add more debugging
      debugPrint('Profile found: $profile');
      debugPrint('User role: ${profile['role']}');
      debugPrint('Is admin: ${profile['role'] == 'admin'}');
      debugPrint('========================');

      return profile['role'] == 'admin';
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      debugPrint('========================');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getAdminProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final profile = await supabase
          .from('user_profiles')
          .select('*')
          .eq('id', user.id)
          .single();

      return profile['role'] == 'admin' ? profile : null;
    } catch (e) {
      debugPrint('Error getting admin profile: $e');
      return null;
    }
  }
}
