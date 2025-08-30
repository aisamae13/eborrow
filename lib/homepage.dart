import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'landingpage.dart';
import 'main.dart';

class HomePage extends StatefulWidget {
  final Function(int) onNavigate;

  const HomePage({super.key, required this.onNavigate});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // UPDATED: This function is now smarter about finding the user's name
  void _loadUserData() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      // For users who signed up with email, we look for 'first_name'
      String? firstName = user.userMetadata?['first_name'];

      // For users who signed in with Google, the name is often in 'full_name'
      String? fullName = user.userMetadata?['full_name'];

      // We prioritize the first name, but fall back to the full name
      final name = firstName ?? fullName;

      if (name != null) {
        // We only want the first part of the name if it's a full name
        setState(() {
          _userName = name.split(' ')[0];
        });
      }
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
      // Standard app bar with the desired colors and content.
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
          // ADD THIS IconButton FOR SIGN OUT
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed:
                _showSignOutConfirmationDialog, // Call the new function here
          ),
          const SizedBox(width: 8), // Adjust spacing if needed
        ],
        // The yellow line is now part of the app bar's bottom property.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(color: const Color(0xFFFFC107), height: 4.0),
        ),
      ),
      // The rest of the page body
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // This now passes the user's name to the welcome card
              _buildWelcomeCard(_userName),

              const SizedBox(height: 24),
              // Quick Actions Section
              _buildSectionHeader('Quick Actions'),
              const SizedBox(height: 16),
              _buildQuickActions(context),
              const SizedBox(height: 24),

              // Equipment Categories Section
              _buildSectionHeader('Equipment Categories'),
              const SizedBox(height: 16),
              _buildCategoryGrid(context),
              const SizedBox(height: 24),

              // Recent Activity Section
              _buildSectionHeader('Recent Activity'),
              const SizedBox(height: 16),
              _buildRecentActivityItem(
                icon: Icons.laptop_mac,
                title: 'MacBook Pro 13"',
                subtitle: 'Due: Tomorrow',
                status: 'Borrowed',
                statusColor: Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildRecentActivityItem(
                icon: Icons.cable,
                title: 'HDMI Cable',
                subtitle: 'Returned: Yesterday',
                status: 'Returned',
                statusColor: Colors.green,
              ),
            ],
          ),
        ),
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

  // Reusable widget for the category cards.
  Widget _buildCategoryGrid(context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: (MediaQuery.of(context).size.width - 48) / 2,
          child: _buildCategoryCard(
            icon: Icons.laptop,
            label: 'Laptops',
            count: '12 available',
            color: Colors.blue.shade100,
            iconColor: Colors.blue.shade800,
          ),
        ),
        SizedBox(
          width: (MediaQuery.of(context).size.width - 48) / 2,
          child: _buildCategoryCard(
            icon: Icons.video_camera_front,
            label: 'Projectors',
            count: '5 available',
            color: Colors.purple.shade100,
            iconColor: Colors.purple.shade800,
          ),
        ),
        SizedBox(
          width: (MediaQuery.of(context).size.width - 48) / 2,
          child: _buildCategoryCard(
            icon: Icons.cable,
            label: 'Cables',
            count: '23 available',
            color: Colors.teal.shade100,
            iconColor: Colors.teal.shade800,
          ),
        ),
        SizedBox(
          width: (MediaQuery.of(context).size.width - 48) / 2,
          child: _buildCategoryCard(
            icon: Icons.headset,
            label: 'Audio',
            count: '9 available',
            color: Colors.red.shade100,
            iconColor: Colors.red.shade800,
          ),
        ),
      ],
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
  Widget _buildRecentActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
  }) {
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
          Icon(icon, size: 36, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
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
