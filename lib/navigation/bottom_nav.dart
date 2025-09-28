import 'package:flutter/material.dart';
import '../borrower/pages/homepage.dart';
import '../borrower/pages/catalogpage.dart';
import '../borrower/pages/scanqr.dart';
import '../borrower/pages/historypage.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int _selectedIndex = 0; // Tracks the currently selected tab index

  // This list holds the widgets for each tab's content.
  // We use `late final` because it's initialized in `initState`.
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Initialize the list of pages. We need to do this here because we're passing
    // a function to HomePage that depends on `this`.
    _pages = [
      // Pass the navigation function to HomePage to allow it to change the tab.
      HomePage(onNavigate: _onItemTapped),
      const CatalogPage(),
      const ScanQRPage(),
      const HistoryPage(),
    ];
  }

  // This function is called when a tab is tapped, updating the selected index.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // We now return a Scaffold without an AppBar. Each page will have its own header.
    return Scaffold(
      body: _pages[_selectedIndex],

      // The bottom navigation bar is part of the main Scaffold
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Catalog',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan QR',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
        currentIndex: _selectedIndex, // Set the current index
        selectedItemColor: const Color(0xFF4A55A2),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped, // Call the function when a tab is tapped
      ),
    );
  }
}
