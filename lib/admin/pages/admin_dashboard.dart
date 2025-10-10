import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/recent_activities_widget.dart';
// Add this import
import '../services/admin_dashboard_service.dart';
import '../services/admin_auth_service.dart';
import 'package:provider/provider.dart';
import '../../shared/notifications/notification_page.dart';
import '../../shared/notifications/notification_with_badge.dart';
import '../../shared/notifications/notification_service.dart';
import '../../main.dart';
import 'admin_profile_page.dart';
import 'generate_qr_page.dart';
import 'equipment_management_page.dart'; // Import the Equipment Management page

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

  Future<void> _refreshDashboard() async {
    setState(() {
      _dashboardData = AdminDashboardService.getDashboardData();
    });
    await _fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6E8F0), // 🎨 Neumorphic background
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
              width: 36,
              height: 36,
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
        onRefresh: _refreshDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // 🔧 Better scroll physics
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0), // 🔧 Optimized padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Actions
              Text(
                'Quick Actions',
                style: GoogleFonts.poppins(
                  fontSize: 22, // 🔧 Slightly larger for better hierarchy
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2B326B),
                  letterSpacing: -0.5, // 🔧 Better letter spacing
                ),
              ),
              const SizedBox(height: 16),
              _buildQuickActions(),
              const SizedBox(height: 32), // 🔧 Better spacing

              // Overview Stats
              Text(
                'Overview',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2B326B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<Map<String, dynamic>>(
                future: _dashboardData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6E8F0),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            // 🎨 Neumorphic loading indicator
                            BoxShadow(
                              color: Color(0xFFBCC0D0),
                              offset: Offset(8, 8),
                              blurRadius: 15,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Colors.white,
                              offset: Offset(-8, -8),
                              blurRadius: 15,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2B326B)),
                          strokeWidth: 3,
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6E8F0),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFBCC0D0),
                            offset: Offset(8, 8),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: Colors.white,
                            offset: Offset(-8, -8),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        'Error loading data',
                        style: GoogleFonts.poppins(
                          color: Colors.red[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }

                  final data = snapshot.data!;
                  return _buildStatsGrid(data);
                },
              ),
              const SizedBox(height: 32),

              // Recent Activities
              Text(
                'Recent Activities',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2B326B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              const RecentActivitiesWidget(),
              const SizedBox(height: 20), // 🔧 Bottom padding for last element
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionCard(
            'Add\nEquipment',
            Icons.add_circle_outline,
            const Color(0xFF4A90E2), // 🎨 Softer blue
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EquipmentManagementPage(),
                ),
              ).then((_) {
                _refreshDashboard();
              });
            },
          ),
        ),
        const SizedBox(width: 16), // 🔧 Optimized spacing
        Expanded(
          child: _buildQuickActionCard(
            'Generate\nQR Code',
            Icons.qr_code,
            const Color(0xFF50C878), // 🎨 Softer green
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GenerateQRPage(),
                ),
              );
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), // 🔧 Smooth animation
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), // 🔧 Optimized padding
        decoration: BoxDecoration(
          color: const Color(0xFFE6E8F0), // 🎨 Neumorphic background
          borderRadius: BorderRadius.circular(18), // 🔧 Slightly smaller radius
          boxShadow: const [
            // 🎨 Neumorphic shadows
            BoxShadow(
              color: Color(0xFFBCC0D0),
              offset: Offset(6, 6), // 🔧 Slightly smaller shadows
              blurRadius: 12,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.white,
              offset: Offset(-6, -6),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16), // 🔧 Better proportions
              decoration: BoxDecoration(
                color: const Color(0xFFE6E8F0),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  // 🎨 Inner neumorphic effect for icon container
                  BoxShadow(
                    color: const Color(0xFFBCC0D0).withOpacity(0.7),
                    offset: const Offset(3, 3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.9),
                    offset: const Offset(-3, -3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: color,
                size: 30, // 🔧 Optimized size
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13, // 🔧 Slightly smaller
                height: 1.2,
                color: const Color(0xFF2B326B),
                letterSpacing: -0.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
      crossAxisSpacing: 16, // 🔧 Optimized spacing
      mainAxisSpacing: 16,
      childAspectRatio: 1.2, // 🔧 Better proportions
      
      children: [
        _buildStatCard(
          'Pending\nRequests',
          data['pendingRequests'].toString(),
          Icons.pending_actions,
          const Color(0xFFFF8C42), // 🎨 Softer orange
        ),
        _buildStatCard(
          'Available\nItems',
          data['availableItems'].toString(),
          Icons.check_circle,
          const Color(0xFF50C878), // 🎨 Softer green
        ),
        _buildStatCard(
          'Total\nEquipment',
          data['totalEquipment'].toString(),
          Icons.inventory_2,
          const Color(0xFF4A90E2), // 🎨 Softer blue
        ),
        _buildStatCard(
          'Active\nBorrowing',
          data['activeBorrowing'].toString(),
          Icons.handshake,
          const Color(0xFF9B59B6), // 🎨 Softer purple
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
      padding: const EdgeInsets.all(16), // 🔧 Optimized padding
      decoration: BoxDecoration(
        color: const Color(0xFFE6E8F0), // 🎨 Neumorphic background
        borderRadius: BorderRadius.circular(18), // 🔧 Consistent radius
        boxShadow: const [
          // 🎨 Neumorphic shadows
          BoxShadow(
            color: Color(0xFFBCC0D0),
            offset: Offset(6, 6),
            blurRadius: 12,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white,
            offset: Offset(-6, -6),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10), // 🔧 Better proportions
            decoration: BoxDecoration(
              color: const Color(0xFFE6E8F0),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                // 🎨 Inner neumorphic effect for icon
                BoxShadow(
                  color: const Color(0xFFBCC0D0).withOpacity(0.7),
                  offset: const Offset(3, 3),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.9),
                  offset: const Offset(-3, -3),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: 24, // 🔧 Consistent size
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20, // 🔧 Optimized size
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11, // 🔧 Smaller for better fit
              color: const Color(0xFF2B326B).withOpacity(0.8),
              fontWeight: FontWeight.bold,
              height: 1.1,
              letterSpacing: -0.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}