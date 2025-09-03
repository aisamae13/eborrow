import 'package:flutter/material.dart';
import 'main.dart';
import 'profile_page.dart';


class HomePage extends StatefulWidget {
  final Function(int) onNavigate;

  const HomePage({super.key, required this.onNavigate});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _userName;
  late final Future<List<BorrowRequest>> _recentActivityFuture;
  late final Future<List<EquipmentCategory>> _categoriesFuture;
  bool _showStudentIdBanner = false;

  @override
  void initState() {
    super.initState();
    // Use the single, more complete method to load user data
    _loadUserDataAndCheckProfile();
    // Initialize the futures
    _recentActivityFuture = _fetchRecentActivity();
    _categoriesFuture = _fetchCategories();
  }

  Future<void> _loadUserDataAndCheckProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final name =
        user.userMetadata?['first_name'] ?? user.userMetadata?['full_name'];
    if (name != null) {
      setState(() {
        _userName = name.split(' ')[0];
      });
    }

    final isGoogleUser = user.appMetadata['provider'] == 'google';
    if (isGoogleUser) {
      try {
        final profile = await supabase
            .from('user_profiles')
            .select('student_id')
            .eq('id', user.id)
            .single();
        final studentId = profile['student_id'];
        if (studentId == null || studentId.isEmpty) {
          setState(() {
            _showStudentIdBanner = true;
          });
        }
      } catch (_) {
        // Handle cases where profile might not exist yet
      }
    }
  }

  Future<List<BorrowRequest>> _fetchRecentActivity() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final response = await supabase
          .from('borrow_requests')
          .select('*, equipment(name, brand, image_url)')
          .eq('borrower_id', userId)
          .order('created_at', ascending: false)
          .limit(2);
      return response.map((map) => BorrowRequest.fromMap(map)).toList();
    } catch (e) {
      // Silently fail is okay for a summary view
      return [];
    }
  }

  Future<List<EquipmentCategory>> _fetchCategories() async {
    try {
      final categoriesResponse = await supabase.from('equipment_categories').select();
      final categories = categoriesResponse.map((map) {
        return EquipmentCategory(
          id: map['category_id'],
          name: map['category_name'],
        );
      }).toList();

      final equipmentResponse = await supabase
          .from('equipment')
          .select('category_id')
          .ilike('status', 'available');

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
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text(
        'Borrower',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: const Color(0xFF2B326B),
      actions: [
        IconButton(
          icon: const Icon(Icons.person_outline, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          },
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
                  return const Center(child: Text('Error loading categories.'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No categories available.'));
                } else {
                  return _buildCategoryGrid(snapshot.data!);
                }
              },
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Recent Activity'),
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
                // Add a SizedBox to create space below the text
                return const Column(
                  children: [
                    Center(
                      child: Text('No recent activity to show.'),
                    ),
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

  // New banner widget to prompt user for student ID
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
            child: const Text('Add ID', style: TextStyle(color: Color(0xFF2B326B))),
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
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: categories
          .map((category) => SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                child: _buildCategoryCard(
                  icon: _getIconForCategory(category.name),
                  label: category.name,
                  count: '${category.availableCount} available',
                  color: _getColorForCategory(category.name).shade100,
                  iconColor: _getColorForCategory(category.name).shade800,
                ),
              ))
          .toList(),
    );
  }

  IconData _getIconForCategory(String categoryName) {
    switch (categoryName) {
      case 'Laptops':
        return Icons.laptop;
      case 'Projectors':
        return Icons.video_camera_front;
      case 'HDMI Cables':
        return Icons.cable;
      case 'Audio':
        return Icons.headset;
      case 'Tablets':
        return Icons.tablet_mac;
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
        return Colors.teal;
      case 'Audio':
        return Colors.red;
      case 'Tablets':
        return Colors.orange;
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
                  'Status: ${item.status}',
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
              item.status,
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
}

// Make sure to define these models in separate files as per the original imports.
// Example: models/borrow_request.dart
class BorrowRequest {
  final int borrowId;
  final String borrowerId;
  final int equipmentId;
  final DateTime requestedAt;
  final String status;
  final String equipmentName;

  BorrowRequest({
    required this.borrowId,
    required this.borrowerId,
    required this.equipmentId,
    required this.requestedAt,
    required this.status,
    required this.equipmentName,
  });

  factory BorrowRequest.fromMap(Map<String, dynamic> map) {
    return BorrowRequest(
      borrowId: map['borrow_id'],
      borrowerId: map['borrower_id'],
      equipmentId: map['equipment_id'],
      requestedAt: DateTime.parse(map['requested_at']),
      status: map['status'],
      equipmentName: map['equipment']['name'],
    );
  }

  Color getStatusColor() {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'borrowed':
        return Colors.blue;
      case 'returned':
        return Colors.green;
      case 'denied':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// Example: models/equipment_category.dart
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