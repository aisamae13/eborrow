import 'package:flutter/material.dart';
import '../../main.dart';

class AdminAuthService {
  // Cache the admin status
  static bool? _cachedIsAdmin;
  static String? _cachedUserId;

  static Future<bool> isAdmin({bool forceRefresh = false}) async {
    final user = supabase.auth.currentUser;

    debugPrint('=== ADMIN CHECK DEBUG ===');
    debugPrint('Current user: ${user?.email}');
    debugPrint('User ID: ${user?.id}');

    if (user == null) {
      debugPrint('No user found');
      _cachedIsAdmin = null;
      _cachedUserId = null;
      return false;
    }

    // Return cached value if available and user hasn't changed
    if (!forceRefresh &&
        _cachedIsAdmin != null &&
        _cachedUserId == user.id) {
      debugPrint('Returning cached admin status: $_cachedIsAdmin');
      debugPrint('========================');
      return _cachedIsAdmin!;
    }

    try {
      final profile = await supabase
          .from('user_profiles')
          .select('role')  // Only select what you need
          .eq('id', user.id)
          .single();

      final isAdminUser = profile['role'] == 'admin';

      // Cache the result
      _cachedIsAdmin = isAdminUser;
      _cachedUserId = user.id;

      debugPrint('Profile found: $profile');
      debugPrint('User role: ${profile['role']}');
      debugPrint('Is admin: $isAdminUser');
      debugPrint('========================');

      return isAdminUser;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      debugPrint('========================');
      return false;
    }
  }

  // Clear cache when user logs out
  static void clearCache() {
    _cachedIsAdmin = null;
    _cachedUserId = null;
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