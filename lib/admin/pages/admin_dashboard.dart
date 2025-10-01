import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/recent_activities_widget.dart';
import '../services/admin_dashboard_service.dart';
import '../services/admin_auth_service.dart';
import 'package:provider/provider.dart';
import '../../shared/notifications/notification_page.dart';
import '../../shared/notifications/notification_with_badge.dart';
import '../../shared/notifications/notification_service.dart';
import '../../main.dart';
import 'admin_profile_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<Map<String, dynamic>> _dashboardData;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _dashboardData = AdminDashboardService.getDashboardData();
    _initializeNotifications();
    _fetchProfile();
  }

  void _initializeNotifications() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<NotificationProvider>().initializeRealtime(user.id);
      });
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final profile = await AdminAuthService.getAdminProfile();
      if (mounted) {
        setState(() {
          _profileData = profile;
        });
      }
    } catch (e) {
      // Silent fail - just won't show profile picture
      debugPrint('Error fetching profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IT Admin',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2B326B),
        actions: [
          RealtimeNotificationBadge(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationPage(),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminProfilePage(),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFC107),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: _profileData != null
                    ? Image.network(
                        'https://cdn-icons-png.flaticon.com/512/3135/3135715.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFFFFC107),
                            child: const Icon(
                              Icons.admin_panel_settings,
                              size: 20,
                              color: Color(0xFF2B326B),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: const Color(0xFFFFC107),
                        child: const Icon(
                          Icons.admin_panel_settings,
                          size: 20,
                          color: Color(0xFF2B326B),
                        ),
                      ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(color: const Color(0xFFFFC107), height: 4.0),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _dashboardData = AdminDashboardService.getDashboardData();
          });
          await _fetchProfile();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              _buildWelcomeCard(),
              const SizedBox(height: 24),

              // Quick Actions
              Text(
                'Quick Actions',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildQuickActions(),
              const SizedBox(height: 24),

              // Overview Stats
              Text(
                'Overview',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<Map<String, dynamic>>(
                future: _dashboardData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }

                  final data = snapshot.data!;
                  return _buildStatsGrid(data);
                },
              ),
              const SizedBox(height: 24),

              // Recent Activities
              Text(
                'Recent Activities',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const RecentActivitiesWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B326B), Color(0xFF4A55A2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, Admin!',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFFFC107),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage equipment and user requests',
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionCard(
            'Add Equipment',
            Icons.add_circle_outline,
            Colors.blue,
            () {
              // Navigate to add equipment page
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildQuickActionCard(
            'Generate QR',
            Icons.qr_code,
            Colors.green,
            () {
              // Navigate to QR generator
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> data) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard(
          'Pending Requests',
          data['pendingRequests'].toString(),
          Icons.pending_actions,
          Colors.orange,
        ),
        _buildStatCard(
          'Available Items',
          data['availableItems'].toString(),
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Total Equipment',
          data['totalEquipment'].toString(),
          Icons.inventory_2,
          Colors.blue,
        ),
        _buildStatCard(
          'Active Borrowing',
          data['activeBorrowing'].toString(),
          Icons.handshake,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}