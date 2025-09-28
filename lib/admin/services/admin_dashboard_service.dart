import '../../main.dart';

class AdminDashboardService {
  static Future<Map<String, dynamic>> getDashboardData() async {
    try {
      // Get pending requests count
      final pendingRequests = await supabase
          .from('borrow_requests')
          .select('request_id')
          .eq('status', 'pending');

      // Get available equipment count
      final availableItems = await supabase
          .from('equipment')
          .select('equipment_id')
          .eq('status', 'available');

      // Get total equipment count
      final totalEquipment = await supabase
          .from('equipment')
          .select('equipment_id');

      // Get active borrowing count
      final activeBorrowing = await supabase
          .from('borrow_requests')
          .select('request_id')
          .eq('status', 'active');

      return {
        'pendingRequests': pendingRequests.length,
        'availableItems': availableItems.length,
        'totalEquipment': totalEquipment.length,
        'activeBorrowing': activeBorrowing.length,
      };
    } catch (e) {
      throw Exception('Failed to load dashboard data: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getRecentActivities() async {
    try {
      // 🔧 FIXED: Updated query to handle the relationship properly
      final activities = await supabase
          .from('borrow_requests')
          .select(
            'request_id, borrower_id, equipment_id, status, created_at, equipment(name)',
          )
          .order('created_at', ascending: false)
          .limit(10);

      // If we got activities, fetch user names separately
      final activitiesWithUsers = <Map<String, dynamic>>[];

      for (final activity in activities) {
        try {
          // Fetch user profile separately
          final userProfile = await supabase
              .from('user_profiles')
              .select('first_name, last_name')
              .eq('id', activity['borrower_id'])
              .maybeSingle();

          // Add user info to activity
          final activityWithUser = Map<String, dynamic>.from(activity);
          activityWithUser['user_profiles'] =
              userProfile ?? {'first_name': 'Unknown', 'last_name': 'User'};

          activitiesWithUsers.add(activityWithUser);
        } catch (e) {
          // If user lookup fails, add activity with default user info
          final activityWithUser = Map<String, dynamic>.from(activity);
          activityWithUser['user_profiles'] = {
            'first_name': 'Unknown',
            'last_name': 'User',
          };
          activitiesWithUsers.add(activityWithUser);
        }
      }

      return activitiesWithUsers;
    } catch (e) {
      // Return empty list instead of throwing exception
      print('Error loading recent activities: $e');
      return [];
    }
  }
}
