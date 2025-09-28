import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/admin_dashboard_service.dart';

class RecentActivitiesWidget extends StatefulWidget {
  const RecentActivitiesWidget({super.key});

  @override
  State<RecentActivitiesWidget> createState() => _RecentActivitiesWidgetState();
}

class _RecentActivitiesWidgetState extends State<RecentActivitiesWidget> {
  late Future<List<Map<String, dynamic>>> _activitiesFuture;

  @override
  void initState() {
    super.initState();
    _activitiesFuture = AdminDashboardService.getRecentActivities();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _activitiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        final activities = snapshot.data ?? [];

        if (activities.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Text(
                'No recent activities',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            ),
          );
        }

        return Column(
          children: activities.take(3).map((activity) {
            return _buildActivityItem(activity);
          }).toList(),
        );
      },
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final userName =
        '${activity['user_profiles']['first_name']} ${activity['user_profiles']['last_name']}';
    final equipmentName = activity['equipment']['name'];
    final status = activity['status'];
    final createdAt = DateTime.parse(activity['created_at']);
    final timeAgo = _getTimeAgo(createdAt);

    IconData icon;
    Color iconColor;
    String actionText;

    switch (status) {
      case 'pending':
        icon = Icons.pending;
        iconColor = Colors.orange;
        actionText = 'New borrow request from';
        break;
      case 'returned':
        icon = Icons.assignment_return;
        iconColor = Colors.green;
        actionText = 'Equipment returned by';
        break;
      default:
        icon = Icons.info;
        iconColor = Colors.blue;
        actionText = 'Request update from';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$actionText $userName',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  equipmentName,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            timeAgo,
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
