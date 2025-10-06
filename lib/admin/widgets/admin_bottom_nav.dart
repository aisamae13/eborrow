import 'package:flutter/material.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import '../pages/admin_dashboard.dart';
import '../pages/requests_management_page.dart';
import '../pages/equipment_management_page.dart';
import '../pages/issues_management_page.dart';
import '../pages/user_management_page.dart';

class AdminBottomNav extends StatefulWidget {
  const AdminBottomNav({super.key});

  @override
  State<AdminBottomNav> createState() => _AdminBottomNavState();
}

class _AdminBottomNavState extends State<AdminBottomNav> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const AdminDashboard(),
      const RequestsManagementPage(),
      const EquipmentManagementPage(),
      const IssuesManagementPage(),
      const UserManagementScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: SalomonBottomBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF2B326B),
        unselectedItemColor: Colors.grey,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        itemPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        items: [
          SalomonBottomBarItem(
            icon: const Icon(Icons.home),
            title: const Text('Home'),
            selectedColor: const Color(0xFF2B326B),
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.assignment),
            title: const Text('Requests'),
            selectedColor: const Color(0xFF2B326B),
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.inventory_2),
            title: const Text('Equipment'),
            selectedColor: const Color(0xFF2B326B),
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.report_problem),
            title: const Text('Issues'),
            selectedColor: const Color(0xFF2B326B),
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.people),
            title: const Text('Users'),
            selectedColor: const Color(0xFF2B326B),
          ),
        ],
      ),
    );
  }
}