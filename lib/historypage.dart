import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'models/borrow_request.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int _selectedIndex = 0;
  Future<List<BorrowRequest>>? _requestsFuture;

  @override
  void initState() {
    super.initState();
    _requestsFuture = _fetchBorrowRequests();
  }

  Future<List<BorrowRequest>> _fetchBorrowRequests() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      // Return an empty list if the user is not logged in
      return [];
    }

    try {
      final response = await supabase
          .from('borrow_requests')
          .select(
            '*, equipment(name)',
          ) // Join with equipment table to get the name
          .eq('borrower_id', userId) // Filter by the current user's ID
          .order('created_at', ascending: false); // Show the newest first

      final requestList = response
          .map((map) => BorrowRequest.fromMap(map))
          .toList();
      return requestList;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching history: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return [];
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _requestsFuture = _fetchBorrowRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildCustomAppBar(),
          Expanded(
            child: FutureBuilder<List<BorrowRequest>>(
              future: _requestsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allRequests = snapshot.data!;
                if (allRequests.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refreshData,
                    child: Stack(children: [ListView(), _buildEmptyState()]),
                  );
                }
                // Filter the requests into active and history lists
                final activeItems = allRequests
                    .where(
                      (r) => [
                        'pending',
                        'approved',
                        'active',
                        'overdue',
                      ].contains(r.status.toLowerCase()),
                    )
                    .toList();

                final historyItems = allRequests
                    .where(
                      (r) => [
                        'returned',
                        'rejected',
                        'cancelled',
                      ].contains(r.status.toLowerCase()),
                    )
                    .toList();

                return RefreshIndicator(
                  onRefresh: _refreshData,
                  child: _selectedIndex == 0
                      ? _buildItemsList(activeItems)
                      : _buildItemsList(historyItems),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF2E4F7A),
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

  Widget _buildTabSelector() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedIndex = 0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _selectedIndex == 0
                        ? const Color(0xFFECA352)
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
            onTap: () => setState(() => _selectedIndex = 1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _selectedIndex == 1
                        ? const Color(0xFFECA352)
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

  Widget _buildItemsList(List<BorrowRequest> items) {
    if (items.isEmpty) {
      return _buildEmptyState(isHistory: _selectedIndex == 1);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildBorrowedItemCard(items[index]),
        );
      },
    );
  }

  Widget _buildEmptyState({bool isHistory = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.list_alt, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            isHistory ? 'No History Found' : 'No Active Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isHistory
                ? 'Your past borrowings will appear here.'
                : 'Your pending and active borrowings will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildBorrowedItemCard(BorrowRequest item) {
    final statusColor = item.getStatusColor();
    final formatter = DateFormat('MMM dd, yyyy');

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
              Flexible(
                child: Text(
                  item.equipmentName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 4.0,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Borrowed: ${formatter.format(item.borrowDate)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            item.status.toLowerCase() == 'returned'
                ? 'Returned: ${formatter.format(item.returnDate)}'
                : 'Due: ${formatter.format(item.returnDate)}',
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
