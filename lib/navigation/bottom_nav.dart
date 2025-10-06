import 'package:flutter/material.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import '../borrower/pages/homepage.dart';
import '../borrower/pages/catalogpage.dart';
import '../borrower/pages/scanqr.dart';
import '../borrower/pages/historypage.dart';
import 'package:eborrow/borrower/pages/active_borrowings_page.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(onNavigate: _onItemTapped),
      const CatalogPage(),
      const ScanQRPage(),
      const ActiveBorrowingsPage(),
      const HistoryPage(),
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
        selectedItemColor: const Color(0xFF4A55A2),
        unselectedItemColor: Colors.grey,
        items: [
          SalomonBottomBarItem(
            icon: const Icon(Icons.home),
            title: const Text('Home'),
            selectedColor: const Color(0xFF4A55A2),
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.inventory_2_outlined),
            title: const Text('Catalog'),
            selectedColor: const Color(0xFF4A55A2),
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.qr_code_scanner),
            title: const Text('Scan QR'),
            selectedColor: const Color(0xFF4A55A2),
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.assignment_outlined),
            activeIcon: const Icon(Icons.assignment),
            title: const Text('Active'),
            selectedColor: const Color(0xFF4A55A2),
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.history),
            title: const Text('History'),
            selectedColor: const Color(0xFF4A55A2),
          ),
        ],
      ),
    );
  }
}