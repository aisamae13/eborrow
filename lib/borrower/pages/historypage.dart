import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../models/borrow_request.dart';
import 'package:eborrow/shared/utils/string_extension.dart';
import 'modify_request_page.dart';
import 'request_detail_popup.dart';
import '../../shared/notifications/notification_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  Future<List<BorrowRequest>>? _requestsFuture;
  bool _isRefreshing = false;

  late PageController _pageController;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _requestsFuture ??= _fetchBorrowRequests();
  }

  Future<List<BorrowRequest>> _fetchBorrowRequests() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return [];
    }

    try {
      final response = await supabase
          .from('borrow_requests')
          .select('*, equipment(name, image_url)')
          .eq('borrower_id', userId)
          .order('created_at', ascending: false);

      final requestList = response
          .map((map) => BorrowRequest.fromMap(map))
          .toList();
      return requestList;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Error fetching history. Check your connection.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return; // Prevent multiple simultaneous refreshes

    setState(() {
      _isRefreshing = true;
    });

    try {
      final newData = await _fetchBorrowRequests();
      if (mounted) {
        setState(() {
          _requestsFuture = Future.value(newData);
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _onTabSelected(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });

      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      _animationController.forward().then((_) {
        _animationController.reset();
      });
    }
  }

  Future<void> _cancelRequest(BorrowRequest request) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Cancellation'),
        content: const Text(
          'Are you sure you want to cancel this borrow request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. Notify the BORROWER (Self-Notification for UX)
        await NotificationService.createNotification(
          userId: request.borrowerId,
          title: 'Request Cancelled',
          message:
              'You have cancelled your borrow request for "${request.equipmentName}".',
          type: NotificationType.requestRejected,
          metadata: {
            'equipment_name': request.equipmentName,
            'borrow_request_id': request.requestId,
            'action': 'cancelled_by_user',
          },
        );

        // 2. Update the database
        await supabase
            .from('borrow_requests')
            .update({'status': 'cancelled'})
            .eq('request_id', request.requestId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request cancelled successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          _refreshData();
        }
      } catch (e) {
        print("--- ❌ CANCELLATION FAILED ---");
        print(e);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error cancelling request: ${e.toString()}'),
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
      body: Column(
        children: [
          _buildCustomAppBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: FutureBuilder<List<BorrowRequest>>(
                future: _requestsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !_isRefreshing) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }

                  final allRequests = snapshot.data ?? [];
                  if (allRequests.isEmpty) {
                    return _buildScrollableEmptyState();
                  }

                  // Clear status categorization
                  final activeItems = allRequests
                      .where(
                        (r) => [
                          'pending', // Waiting for approval
                          'approved', // Approved, ready for pickup
                          'active', // Currently borrowed
                          'overdue', // Past due date
                        ].contains(r.status.toLowerCase()),
                      )
                      .toList();

                  final historyItems = allRequests
                      .where(
                        (r) => [
                          'returned', // Successfully returned
                          'rejected', // Denied by admin
                          'cancelled', // Cancelled by user
                          'expired', // Request expired (optional)
                        ].contains(r.status.toLowerCase()),
                      )
                      .toList();

                  return PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    children: [
                      _buildItemsList(activeItems),
                      _buildItemsList(historyItems),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF2B326B),
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
            onTap: () => _onTabSelected(0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
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
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: GoogleFonts.poppins(
                    color: _selectedIndex == 0
                        ? Colors.white
                        : Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                  child: const Text('Active'),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _onTabSelected(1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
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
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: GoogleFonts.poppins(
                    color: _selectedIndex == 1
                        ? Colors.white
                        : Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                  child: const Text('History'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScrollableEmptyState() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyState(isHistory: _selectedIndex == 1),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error loading data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Pull down to retry',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList(List<BorrowRequest> items) {
    if (items.isEmpty) {
      return _buildScrollableEmptyState();
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
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
    final dateTimeFormatter = DateFormat('MMM dd, yyyy hh:mm a');

    final isPending = item.status.toLowerCase() == 'pending';
    String statusDescription = _getStatusDescription(item.status.toLowerCase(), item);

    // 💡 NEW: Gamitin ang image URL, o isang placeholder kung walang image
    final imageUrl = item.equipmentImageUrl;
    const placeholderUrl =
        'https://via.placeholder.com/70/D3D3D3/000000?text=No+Img';

    return GestureDetector(
  onTap: () {
    // Call the external function here
    showRequestDetailPopup(context, item);
  },
  child: Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column( // Gumamit ng Column para ma-accommodate ang image ROW at ang buttons
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row( // Ito ang main row para sa image at details
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Equipment Image (Left Side)
              ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: Image.network(
                  imageUrl ?? placeholderUrl,
                  width: 70, // Fixed width
                  height: 70, // Fixed height
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 70,
                      height: 70,
                      color: Colors.grey.shade200,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // 2. Details Column (Right Side)
              Expanded(
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
                        // Status Badge
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
                            _getDisplayStatus(item.status, item),
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

                    // Status description
                    if (statusDescription.isNotEmpty)
                      Text(
                        statusDescription,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),

                    if (statusDescription.isNotEmpty) const SizedBox(height: 4),

                    Text(
                      'Requested: ${dateTimeFormatter.format(item.borrowDate)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),

                    const SizedBox(height: 4),

                    // Conditional date/reason info (from _buildDateInfo)
                    _buildDateInfo(item, dateTimeFormatter, statusColor),
                  ],
                ),
              ),
            ],
          ),

          // Conditional buttons for pending requests only (full width below the row)
          if (isPending) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text('Modify${item.modificationCount >= 3 ? ' (Limit)' : ''}'),
                  onPressed: item.modificationCount >= 3
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ModifyRequestPage(request: item),
                            ),
                          ).then((_) {
                            _refreshData();
                          });
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(
                      color: const Color.fromARGB(255, 168, 168, 168),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancel'),
                  onPressed: () => _cancelRequest(item),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.red.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ));
  }

  // Helper methods
  String _getStatusDescription(String status, BorrowRequest item) {
  switch (status) {
    case 'pending':
      return 'Waiting for admin approval';
    case 'approved':
      return 'Approved - Ready for pickup';
    case 'active':
      return 'Currently borrowed by you';
    case 'overdue':
      return 'Past due date - Please return immediately';
    case 'returned':
      return 'Successfully returned';
    case 'rejected':
      return 'Request denied by admin';
    case 'cancelled':
      // Check if there's a rejection reason - if yes, admin rejected it
      if (item.rejectionReason != null && item.rejectionReason!.isNotEmpty) {
        return 'Rejected by admin';
      }
      return 'Cancelled by you';
    case 'expired':
      return 'Request expired';
    default:
      return '';
  }
}

String _getDisplayStatus(String status, BorrowRequest item) {
  switch (status.toLowerCase()) {
    case 'pending':
      return 'Pending';
    case 'approved':
      return 'Approved';
    case 'active':
      return 'Active';
    case 'overdue':
      return 'Overdue';
    case 'returned':
      return 'Returned';
    case 'rejected':
      return 'Rejected';
    case 'cancelled':
      // Check if there's a rejection reason - if yes, admin rejected it
      if (item.rejectionReason != null && item.rejectionReason!.isNotEmpty) {
        return 'Rejected';
      }
      return 'Cancelled';
    case 'expired':
      return 'Expired';
    default:
      return status.capitalize();
  }
}

  Widget _buildDateInfo(
    BorrowRequest item,
    DateFormat formatter,
    Color statusColor,
  ) {
    switch (item.status.toLowerCase()) {
      case 'pending':
      case 'approved':
        return Text(
          'Due date: ${formatter.format(item.returnDate)}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        );

      case 'active':
        return Text(
          'Due: ${formatter.format(item.returnDate)}',
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        );

      case 'overdue':
        return Text(
          'Was due: ${formatter.format(item.returnDate)}',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        );

      case 'returned':
        return Text(
          'Returned: ${formatter.format(item.returnDate)}',
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        );

      case 'rejected':
        final reason = item.rejectionReason;
        final hasReason = reason != null && reason.isNotEmpty;

        // Ipakita lang ang REASON kung meron, dahil ang Requested Date ay nasa itaas na ng card.
        if (hasReason) {
          return Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Reason: $reason',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          );
        }
        // Fallback or intentionally hide if no reason (uses SizedBox.shrink to avoid redundant date)
        return const SizedBox.shrink();

      case 'cancelled':
        // Hahanapin ng user ang "Cancelled by you" description at ang Requested Date sa itaas,
        // kaya wala nang kailangang idagdag na detalye dito.
        return const SizedBox.shrink();

      default:
        // Default na pag-display ng Due date
        return Text(
          'Due: ${formatter.format(item.returnDate)}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        );
    }
  }
}