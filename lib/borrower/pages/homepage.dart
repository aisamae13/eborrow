import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/borrow_request.dart';
import '../../main.dart';
import '../../shared/profile/profile_page.dart';
import '../../shared/notifications/notification_page.dart';
import '../../shared/notifications/notification_with_badge.dart';
import '../../shared/notifications/notification_service.dart';

class HomePage extends StatefulWidget {
  final Function(int) onNavigate;

  const HomePage({super.key, required this.onNavigate});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _userName;
  late final Future<List<BorrowRequest>> _recentActivityFuture;
  late final Future<List<NewEquipment>> _newEquipmentFuture;
  late final Future<List<EquipmentCategory>> _categoriesFuture;
  bool _showStudentIdBanner = false;
  bool _isCategoriesExpanded = false;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndCheckProfile();
    _initializeNotifications();
    _recentActivityFuture = _fetchRecentActivity();
    _newEquipmentFuture = _fetchNewEquipment();
    _categoriesFuture = _fetchCategories();
  }

  void _initializeNotifications() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<NotificationProvider>().initializeRealtime(user.id);
      });
    }
  }

  Future<void> _loadUserDataAndCheckProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Set Display Name
    final name =
        user.userMetadata?['first_name'] ?? user.userMetadata?['full_name'];
    if (name != null) {
      setState(() {
        _userName = name.split(' ')[0];
      });
    }

    final providerName = user.appMetadata['provider']?.toString().toLowerCase();
    final isGoogleUser = providerName == 'google' || providerName == 'gmail';

    if (isGoogleUser) {
      try {
        final profile = await supabase
            .from('user_profiles')
            .select('student_id, avatar_url')
            .eq('id', user.id)
            .single();

        final studentId = profile['student_id'];

        setState(() {
          _profileData = profile;
          if (studentId == null || (studentId is String && studentId.isEmpty)) {
            _showStudentIdBanner = true;
          }
        });
      } catch (e) {
        debugPrint('❌ Profile Fetch Failure (Assuming ID is missing): $e');
        if (mounted) {
          setState(() {
            _showStudentIdBanner = true;
          });
        }
      }
    }
  }

  Widget _buildAvatarImage() {
    final profileAvatarUrl = _profileData?['avatar_url'];
    final googlePhotoUrl = supabase.auth.currentUser?.userMetadata?['avatar_url'];
    final avatarUrl = profileAvatarUrl ?? googlePhotoUrl;

    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: ClipOval(
        child: avatarUrl != null
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.white,
                    child: const Icon(
                      Icons.person,
                      color: Color(0xFF2B326B),
                      size: 20,
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.white,
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF2B326B),
                        ),
                      ),
                    ),
                  );
                },
              )
            : Container(
                color: Colors.white,
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF2B326B),
                  size: 20,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF1F8), // 🎨 Neumorphism background
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Borrower',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2B326B),
        elevation: 0,
        actions: [
          // 🎨 Neumorphic Notification Badge Container
          Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2B326B),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  offset: const Offset(-2, -2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: RealtimeNotificationBadge(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationPage(),
                    ),
                  );
                },
              ),
            ),
          ),
          // 🎨 Neumorphic Profile Avatar Container
          Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2B326B),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  offset: const Offset(-2, -2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFC107),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: _buildAvatarImage(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(color: const Color(0xFFFFC107), height: 4.0),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(_userName),
              if (_showStudentIdBanner) _buildStudentIdBanner(),
              const SizedBox(height: 24),
              _buildSectionHeader('Quick Actions'),
              const SizedBox(height: 16),
              _buildQuickActions(context),
              const SizedBox(height: 24),
              _buildSectionHeader('Equipment Categories'),
              const SizedBox(height: 16),
              FutureBuilder<List<EquipmentCategory>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return const Center(
                      child: Text('Error loading categories.'),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No categories available.'),
                    );
                  } else {
                    return _buildCategoryGrid(snapshot.data!);
                  }
                },
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Recently Added Equipment'),
              const SizedBox(height: 16),
              FutureBuilder<List<NewEquipment>>(
                future: _newEquipmentFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return const Center(
                      child: Text('Error loading new equipment.'),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Column(
                      children: [
                        Center(child: Text('No new equipment added recently.')),
                        SizedBox(height: 24),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        ...snapshot.data!
                            .map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _buildNewEquipmentItem(item),
                                )),
                        const SizedBox(height: 24),
                      ],
                    );
                  }
                },
              ),
              _buildSectionHeader('My Recent Activity'),
              const SizedBox(height: 16),
              FutureBuilder<List<BorrowRequest>>(
                future: _recentActivityFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return const Center(
                      child: Text('Error loading recent activity.'),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Column(
                      children: [
                        Center(child: Text('No recent activity to show.')),
                        SizedBox(height: 24),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        ...snapshot.data!
                            .map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _buildRecentActivityItem(item),
                                )),
                        const SizedBox(height: 24),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎨 Neumorphic Student ID Banner
  Widget _buildStudentIdBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.white,
            offset: const Offset(-8, -8),
            blurRadius: 15,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            offset: const Offset(8, 8),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF1F8),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  offset: const Offset(4, 4),
                  blurRadius: 8,
                ),
                BoxShadow(
                  color: Colors.white,
                  offset: const Offset(-4, -4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.info_outline,
              color: Color(0xFFFFC107),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Please add your Student ID in your profile to borrow equipment.',
              style: GoogleFonts.poppins(
                color: const Color(0xFF2B326B),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEEF1F8),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                ),
                BoxShadow(
                  color: Colors.white,
                  offset: const Offset(-2, -2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              ),
              child: Text(
                'Add ID',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF2B326B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 Neumorphic Welcome Card
  Widget _buildWelcomeCard(String? userName) {
    final displayName = userName ?? 'Welcome!';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B326B), Color(0xFF686A9E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            offset: const Offset(8, 8),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            offset: const Offset(-8, -8),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, $displayName!',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFC107),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find and borrow any equipment easily',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF2B326B),
      ),
    );
  }

  // 🎨 Neumorphic Quick Actions
  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => widget.onNavigate(2),
            child: _buildActionCard(
              icon: Icons.qr_code_scanner,
              label: 'Scan QR',
              subtitle: 'Quick borrow',
              primaryColor: Colors.green,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: GestureDetector(
            onTap: () => widget.onNavigate(1),
            child: _buildActionCard(
              icon: Icons.search,
              label: 'Browse',
              subtitle: 'View catalog',
              primaryColor: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  // 🎨 Neumorphic Action Card
  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.white,
            offset: const Offset(-8, -8),
            blurRadius: 15,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            offset: const Offset(8, 8),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF1F8),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  offset: const Offset(4, 4),
                  blurRadius: 8,
                ),
                BoxShadow(
                  color: Colors.white,
                  offset: const Offset(-4, -4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, size: 32, color: primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: const Color(0xFF2B326B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 Neumorphic Category Grid
  Widget _buildCategoryGrid(List<EquipmentCategory> categories) {
    final displayedCategories = _isCategoriesExpanded
        ? categories
        : categories.take(4).toList();
    final hasMore = categories.length > 4;

    return Column(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: displayedCategories
              .map((category) => SizedBox(
                    width: (MediaQuery.of(context).size.width - 48) / 2,
                    height: 160,
                    child: _buildCategoryCard(
                      icon: _getIconForCategory(category.name),
                      label: category.name,
                      count: '${category.availableCount} available',
                      color: _getColorForCategory(category.name),
                    ),
                  ))
              .toList(),
        ),
        if (hasMore) ...[
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEEF1F8),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  offset: const Offset(4, 4),
                  blurRadius: 8,
                ),
                BoxShadow(
                  color: Colors.white,
                  offset: const Offset(-4, -4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _isCategoriesExpanded = !_isCategoriesExpanded;
                });
              },
              icon: Icon(
                _isCategoriesExpanded
                    ? Icons.expand_less
                    : Icons.expand_more,
                color: const Color(0xFF2B326B),
              ),
              label: Text(
                _isCategoriesExpanded ? 'Show Less' : 'Show More',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF2B326B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 🎨 Neumorphic Category Card - FIXED OVERFLOW
  Widget _buildCategoryCard({
    required IconData icon,
    required String label,
    required String count,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16), // Reduced padding slightly
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.white,
            offset: const Offset(-6, -6),
            blurRadius: 12,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            offset: const Offset(6, 6),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF1F8),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  offset: const Offset(3, 3),
                  blurRadius: 6,
                ),
                BoxShadow(
                  color: Colors.white,
                  offset: const Offset(-3, -3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Icon(icon, size: 24, color: color.shade700), // Slightly smaller icon
          ),
          const SizedBox(height: 10),
          // 🔧 FIXED: Better text handling for long labels
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 13, // Slightly smaller font
                color: const Color(0xFF2B326B),
                height: 1.2, // Better line height
              ),
              textAlign: TextAlign.center,
              maxLines: 2, // Allow 2 lines
              overflow: TextOverflow.ellipsis, // Add ellipsis if still too long
            ),
          ),
          const SizedBox(height: 6),
          Text(
            count,
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 10, // Slightly smaller
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 🎨 Neumorphic New Equipment Item
  Widget _buildNewEquipmentItem(NewEquipment item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F8),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.white,
            offset: const Offset(-6, -6),
            blurRadius: 12,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            offset: const Offset(6, 6),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF1F8),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  offset: const Offset(3, 3),
                  blurRadius: 6,
                ),
                BoxShadow(
                  color: Colors.white,
                  offset: const Offset(-3, -3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Icon(Icons.new_releases, size: 24, color: Colors.green[700]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: const Color(0xFF2B326B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.brand} • ${item.category}',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF1F8),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                ),
                BoxShadow(
                  color: Colors.white,
                  offset: const Offset(-2, -2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              'New',
              style: GoogleFonts.poppins(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 Neumorphic Recent Activity Item
  Widget _buildRecentActivityItem(BorrowRequest item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F8),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.white,
            offset: const Offset(-6, -6),
            blurRadius: 12,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            offset: const Offset(6, 6),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF1F8),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  offset: const Offset(3, 3),
                  blurRadius: 6,
                ),
                BoxShadow(
                  color: Colors.white,
                  offset: const Offset(-3, -3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Icon(Icons.history_toggle_off, size: 24, color: Colors.grey[600]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.equipmentName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: const Color(0xFF2B326B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Status: ${item.formattedStatus}',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF1F8),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                ),
                BoxShadow(
                  color: Colors.white,
                  offset: const Offset(-2, -2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              item.formattedStatus,
              style: GoogleFonts.poppins(
                color: item.getStatusColor(),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForCategory(String categoryName) {
    switch (categoryName) {
      case 'Laptops':
        return Icons.laptop;
      case 'Projectors':
        return Icons.video_camera_front;
      case 'HDMI Cables':
      case 'Cables':
        return Icons.cable;
      case 'Audio':
      case 'Audio Equipment':
        return Icons.headset;
      case 'Tablets':
        return Icons.tablet_mac;
      case 'Monitors':
        return Icons.monitor;
      case 'Keyboards':
        return Icons.keyboard;
      case 'Mice':
      case 'Mouse':
        return Icons.mouse;
      default:
        return Icons.category;
    }
  }

  MaterialColor _getColorForCategory(String categoryName) {
    switch (categoryName) {
      case 'Laptops':
        return Colors.blue;
      case 'Projectors':
        return Colors.purple;
      case 'HDMI Cables':
      case 'Cables':
        return Colors.teal;
      case 'Audio':
      case 'Audio Equipment':
        return Colors.red;
      case 'Tablets':
        return Colors.orange;
      case 'Monitors':
        return Colors.indigo;
      case 'Keyboards':
        return Colors.green;
      case 'Mice':
      case 'Mouse':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  Future<List<BorrowRequest>> _fetchRecentActivity() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      print('DEBUG: User ID is NULL. Cannot fetch activity.');
      return [];
    }
    print('DEBUG: Fetching activity for User ID: $userId');

    try {
      final response = await supabase
          .from('borrow_requests')
          .select('*, equipment(name, brand, image_url)')
          .eq('borrower_id', userId)
          .order('created_at', ascending: false)
          .limit(3);

      print('DEBUG: Raw Response: $response');

      final requests = response.map((map) => BorrowRequest.fromMap(map)).toList();
      print('DEBUG: Parsed ${requests.length} requests');

      return requests;
    } catch (e, stackTrace) {
      print('DEBUG: Fetch Error: $e');
      print('DEBUG: Stack Trace: $stackTrace');
      return [];
    }
  }

  Future<List<NewEquipment>> _fetchNewEquipment() async {
    try {
      final response = await supabase
          .from('equipment')
          .select('equipment_id, name, brand, category_id, equipment_categories(category_name)')
          .eq('status', 'available')
          .order('created_at', ascending: false)
          .limit(3);

      return response.map((map) {
        final categoryName = map['equipment_categories'] != null
            ? map['equipment_categories']['category_name']
            : 'Unknown';

        return NewEquipment(
          id: map['equipment_id'],
          name: map['name'],
          brand: map['brand'] ?? '',
          category: categoryName,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<EquipmentCategory>> _fetchCategories() async {
    try {
      final categoriesResponse = await supabase
          .from('equipment_categories')
          .select('category_id, category_name');

      final categories = categoriesResponse.map((map) {
        return EquipmentCategory(
          id: map['category_id'],
          name: map['category_name'],
        );
      }).toList();

      final equipmentResponse = await supabase
          .from('equipment')
          .select('category_id')
          .eq('status', 'available');

      for (var category in categories) {
        final count = equipmentResponse
            .where((item) => item['category_id'] == category.id)
            .length;
        category.availableCount = count;
      }
      return categories;
    } catch (e) {
      return [];
    }
  }

  @override
  void dispose() {
    try {
      final notificationProvider = context.read<NotificationProvider>();
      notificationProvider.dispose();
    } on FlutterError {
      // Catch the "Looking up a deactivated widget's ancestor is unsafe" error
    }

    super.dispose();
  }
}

class EquipmentCategory {
  final int id;
  final String name;
  int availableCount;

  EquipmentCategory({
    required this.id,
    required this.name,
    this.availableCount = 0,
  });
}

class NewEquipment {
  final int id;
  final String name;
  final String brand;
  final String category;

  NewEquipment({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
  });
}