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
Map<String, dynamic>? _profileData; // Add this line

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
          .select('student_id, avatar_url') // Add avatar_url here
          .eq('id', user.id)
          .single();

      final studentId = profile['student_id'];

      setState(() {
        _profileData = profile; // Store the profile data
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
  // Try to get avatar from user profile data (if available)
  final profileAvatarUrl = _profileData?['avatar_url'];
  final googlePhotoUrl = supabase.auth.currentUser?.userMetadata?['avatar_url'];

  final avatarUrl = profileAvatarUrl ?? googlePhotoUrl;

  if (avatarUrl != null) {
    return Image.network(
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
    );
  }

  return Container(
    color: Colors.white,
    child: const Icon(
      Icons.person,
      color: Color(0xFF2B326B),
      size: 20,
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFC107),
                  width: 1,
                ),
              ),
              child: ClipOval(
                child: _buildAvatarImage(),
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
                                ))
                            .toList(),
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
                                ))
                            .toList(),
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

  Widget _buildStudentIdBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFFFC107), size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Please add your Student ID in your profile to borrow equipment.',
              style: TextStyle(
                color: Color(0xFF2B326B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            ),
            child: const Text(
              'Add ID',
              style: TextStyle(color: Color(0xFF2B326B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(String? userName) {
    final displayName = userName ?? 'Welcome!';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B326B), Color(0xFF686A9E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, $displayName!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFC107),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Find and borrow any equipment easily',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

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
              color: Colors.green.shade100,
              iconColor: Colors.green,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () => widget.onNavigate(1),
            child: _buildActionCard(
              icon: Icons.search,
              label: 'Browse',
              subtitle: 'View catalog',
              color: Colors.yellow.shade100,
              iconColor: Colors.yellow.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
         border: Border.all(
        color: iconColor.withOpacity(0.5), // Use the darker color (iconColor) with some transparency
        width: 1.5, // Increase width slightly for visibility
      ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: iconColor),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(subtitle, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

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
                  height: 140,
                  child: _buildCategoryCard(
                    icon: _getIconForCategory(category.name),
                    label: category.name,
                    count: '${category.availableCount} available',
                    color: _getColorForCategory(category.name).shade100,
                    iconColor: _getColorForCategory(category.name).shade800,
                  ),
                ))
            .toList(),
      ),
      if (hasMore) ...[
        const SizedBox(height: 12),
        TextButton.icon(
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
            style: const TextStyle(
              color: Color(0xFF2B326B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ],
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

  Widget _buildCategoryCard({
    required IconData icon,
    required String label,
    required String count,
    required Color color,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
          border: Border.all(
        color: iconColor.withOpacity(0.5),
        width: 1.5,
      ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: iconColor),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(count, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildNewEquipmentItem(NewEquipment item) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.new_releases, size: 28, color: Colors.green[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${item.brand} • ${item.category}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'New',
              style: TextStyle(
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

  Widget _buildRecentActivityItem(BorrowRequest item) {
    return Container(
      padding: const EdgeInsets.all(12),
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
 child: Row(
      children: [
        Icon(Icons.history_toggle_off, size: 36, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.equipmentName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Status: ${item.formattedStatus}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: item.getStatusColor().withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            item.formattedStatus,
            style: TextStyle(
              color: item.getStatusColor(),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
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

    print('DEBUG: Raw Response: $response'); // ADD THIS to see actual data

    final requests = response.map((map) => BorrowRequest.fromMap(map)).toList();
    print('DEBUG: Parsed ${requests.length} requests'); // ADD THIS

    return requests;
  } catch (e, stackTrace) {
    print('DEBUG: Fetch Error: $e');
    print('DEBUG: Stack Trace: $stackTrace'); // ADD THIS to see where it fails
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
  @override
  void dispose() {
    // The issue is using 'context.read' (or Provider.of(context, listen: false))
    // in dispose(), as the context might be deactivated.
    // The recommended fix is to use a try-catch block to handle the exception gracefully,
    // or, better, to restructure where the service is disposed if possible,
    // but in a typical app structure, try-catch is the practical solution here.
    try {
      final notificationProvider = context.read<NotificationProvider>();
      notificationProvider.dispose();
    } on FlutterError {
      // Catch the "Looking up a deactivated widget's ancestor is unsafe" error
      // which is thrown as a FlutterError.
      // print('Provider lookup failed in dispose: $e'); // Optional: for debugging
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