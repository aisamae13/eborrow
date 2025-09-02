import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'landingpage.dart';
import 'main.dart';
import 'profile_page.dart';
import 'models/borrow_request.dart'; // Import the new model file

class HomePage extends StatefulWidget {
  final Function(int) onNavigate;

  const HomePage({super.key, required this.onNavigate});

  @override
  State<HomePage> createState() => _HomePageState();
}

// Model for our categories
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

class _HomePageState extends State<HomePage> {
  String? _userName;
  late final Future<List<BorrowRequest>> _recentActivityFuture;
  late final Future<List<EquipmentCategory>> _categoriesFuture;
  bool _showStudentIdBanner = false;

  Future<void> _loadUserDataAndCheckProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Set the display name
    final name =
        user.userMetadata?['first_name'] ?? user.userMetadata?['full_name'];
    if (name != null) {
      setState(() {
        _userName = name.split(' ')[0];
      });
    }

    // Check if the user signed in with Google and is missing a student ID
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

  @override
  void initState() {
    super.initState();
    _loadUserDataAndCheckProfile(); // Use the new function here
    _recentActivityFuture = _fetchRecentActivity();
    _categoriesFuture = _fetchCategories();
  }

  void _loadUserData() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      String? firstName = user.userMetadata?['first_name'];
      String? fullName = user.userMetadata?['full_name'];
      final name = firstName ?? fullName;

      if (name != null) {
        setState(() {
          _userName = name.split(' ')[0];
        });
      }
    }
  }

  // New function to fetch the user's last 2 borrow requests
  Future<List<BorrowRequest>> _fetchRecentActivity() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final response = await supabase
          .from('borrow_requests')
          .select('*, equipment(name)')
          .eq('borrower_id', userId)
          .order('created_at', ascending: false)
          .limit(2);
      return response.map((map) => BorrowRequest.fromMap(map)).toList();
    } catch (e) {
      // Silently fail is okay for a summary view
      return [];
    }
  }

  // New function to fetch categories and count available items
  Future<List<EquipmentCategory>> _fetchCategories() async {
    try {
      // Fetch all categories
      final categoriesResponse = await supabase
          .from('equipment_categories')
          .select();
      final categories = categoriesResponse.map((map) {
        return EquipmentCategory(
          id: map['category_id'],
          name: map['category_name'],
        );
      }).toList();

      // Fetch all available equipment using a case-insensitive filter
      final equipmentResponse = await supabase
          .from('equipment')
          .select('category_id')
          .ilike('status', 'available'); // Changed from .eq() to .ilike()

      // Count available items for each category
      for (var category in categories) {
        final count = equipmentResponse
            .where((item) => item['category_id'] == category.id)
            .length;
        category.availableCount = count;
      }
      return categories;
    } catch (e) {
      return []; // Return empty list on error
    }
  }

  Future<void> _showSignOutConfirmationDialog() async {
    final bool? shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldSignOut == true) {
      // IMPORTANT: Capture the Navigator before the async operation.
      // This avoids using 'BuildContext' across async gaps.
      final navigator = Navigator.of(context);

      try {
        await supabase.auth.signOut();

        // After successful sign out, perform the navigation.
        await navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LandingPage()),
          (route) => false,
        );
      } on AuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

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
      body: Column(
        children: [
          // This is where the notification banner is placed.
          // It will only be visible if _showStudentIdBanner is true.
          if (_showStudentIdBanner)
            MaterialBanner(
              padding: const EdgeInsets.all(12),
              content: const Text(
                'Please complete your profile by adding your Student ID.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.blue.shade700,
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfilePage(),
                      ),
                    );
                  },
                  child: const Text(
                    'Go to Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _showStudentIdBanner = false),
                  child: const Text(
                    'Dismiss',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),

          // The rest of your page is wrapped in an Expanded widget
          // to make it scrollable below the banner.
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(_userName),
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final categories = snapshot.data ?? [];
                        return _buildCategoryGrid(context, categories);
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Recent Activity'),
                    const SizedBox(height: 16),
                    FutureBuilder<List<BorrowRequest>>(
                      future: _recentActivityFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final activities = snapshot.data ?? [];
                        if (activities.isEmpty) {
                          return const Center(
                            child: Text('No recent activity.'),
                          );
                        }

                        return Column(
                          children: activities
                              .map(
                                (activity) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _buildRecentActivityItem(activity),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(String? userName) {
    // Display the user's name if available, otherwise show a default message
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
            'Welcome, $displayName!', // This line is now dynamic
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

  // Helper method to build the header for each section.
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

  // Helper method for the Quick Actions buttons.
  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => widget.onNavigate(2), // 2 is the index for Scan QR
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
            onTap: () => widget.onNavigate(1), // 1 is the index for Catalog
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

  // Reusable widget for the action cards.
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

  // UPDATED: Now takes a list of categories
  Widget _buildCategoryGrid(
    BuildContext context,
    List<EquipmentCategory> categories,
  ) {
    // Hardcoded colors for a consistent look
    final colors = [Colors.blue, Colors.purple, Colors.teal, Colors.red];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: categories.map((category) {
        final color = colors[categories.indexOf(category) % colors.length];
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 48) / 2,
          child: _buildCategoryCard(
            icon: Icons.laptop, // We can make this dynamic later
            label: category.name,
            count: '${category.availableCount} available',
            color: color.shade100,
            iconColor: color.shade800,
          ),
        );
      }).toList(),
    );
  }

  // Reusable widget for the category cards.
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

  // Reusable widget for the recent activity list items.
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
