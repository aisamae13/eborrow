import 'package:flutter/material.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // Tracks the currently selected tab: 0 for Active, 1 for History.
  int _selectedIndex = 0;

  // Sample data for active and history items.
  // This would typically come from an external source (like a database).
  final List<BorrowedItem> _activeItems = [
    BorrowedItem(
      name: 'MacBook Pro 13"',
      borrowedDate: '2025-08-15',
      dueDate: '2025-08-17',
      status: 'Active',
      statusColor: Colors.orange,
    ),
    BorrowedItem(
      name: 'MacBook Pro 13"',
      borrowedDate: '2025-06-25',
      dueDate: '2025-06-29',
      status: 'Overdue',
      statusColor: Colors.red,
    ),
    BorrowedItem(
      name: 'MacBook Pro 13"',
      borrowedDate: '2025-01-15',
      dueDate: '2025-01-18',
      status: 'Active',
      statusColor: Colors.orange,
    ),
  ];

  final List<BorrowedItem> _historyItems = [
    BorrowedItem(
      name: 'HDMI Cable',
      borrowedDate: '2025-01-10',
      returnedDate: '2025-01-12',
      status: 'Returned',
      statusColor: Colors.green,
    ),
    BorrowedItem(
      name: 'HDMI Cable',
      borrowedDate: '2025-01-10',
      returnedDate: '2025-01-12',
      status: 'Returned',
      statusColor: Colors.green,
    ),
    BorrowedItem(
      name: 'HDMI Cable',
      borrowedDate: '2025-01-10',
      returnedDate: '2025-01-12',
      status: 'Returned',
      statusColor: Colors.green,
    ),
    BorrowedItem(
      name: 'HDMI Cable',
      borrowedDate: '2025-06-10',
      returnedDate: '2025-01-12',
      status: 'Returned',
      statusColor: Colors.green,
    ),
    BorrowedItem(
      name: 'HDMI Cable',
      borrowedDate: '2025-01-10',
      returnedDate: '2025-01-12',
      status: 'Returned',
      statusColor: Colors.green,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Custom App Bar with Tab functionality
            _buildCustomAppBar(),

            // The main content of the page changes based on the selected tab.
            _selectedIndex == 0 ? _buildActiveItemsList() : _buildHistoryItemsList(),
          ],
        ),
      ),
    );
  }

  // A custom app bar that includes a title and a tab selector.
  Widget _buildCustomAppBar() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF2B326B), // The dark blue header color.
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Borrowings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildTabSelector(),
            ],
          ),
        ),
      ),
    );
  }

  // The widget for the "Active" and "History" tabs.
  Widget _buildTabSelector() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = 0;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _selectedIndex == 0
                        ? const Color(0xFFECA352) // Highlight color for active tab.
                        : Colors.white.withOpacity(0.3),
                    width: 3.0,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  'Active',
                  style: TextStyle(
                    color: _selectedIndex == 0
                        ? Colors.white
                        : Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = 1;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _selectedIndex == 1
                        ? const Color(0xFFECA352) // Highlight color for history tab.
                        : Colors.white.withOpacity(0.3),
                    width: 3.0,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  'History',
                  style: TextStyle(
                    color: _selectedIndex == 1
                        ? Colors.white
                        : Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Builds the list of active borrowed items.
  Widget _buildActiveItemsList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: _activeItems.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildBorrowedItemCard(item),
          );
        }).toList(),
      ),
    );
  }

  // Builds the list of returned items from history.
  Widget _buildHistoryItemsList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: _historyItems.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildBorrowedItemCard(item),
          );
        }).toList(),
      ),
    );
  }

  // Reusable widget for an individual borrowed item card.
  Widget _buildBorrowedItemCard(BorrowedItem item) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.0),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: item.statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(
                    color: item.statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Borrowed: ${item.borrowedDate}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.status == 'Returned' ? 'Returned: ${item.returnedDate}' : 'Due: ${item.dueDate}',
            style: TextStyle(
              color: item.statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// A simple model class for a borrowed item to keep data organized.
class BorrowedItem {
  final String name;
  final String borrowedDate;
  final String status;
  final Color statusColor;
  final String? dueDate;
  final String? returnedDate;

  BorrowedItem({
    required this.name,
    required this.borrowedDate,
    required this.status,
    required this.statusColor,
    this.dueDate,
    this.returnedDate,
  });
}
