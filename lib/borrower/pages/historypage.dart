import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../models/borrow_request.dart';
import 'package:eborrow/shared/utils/string_extension.dart';
import 'request_detail_popup.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Future<List<BorrowRequest>>? _requestsFuture;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _requestsFuture = _fetchHistoryRequests();
  }

  Future<List<BorrowRequest>> _fetchHistoryRequests() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return [];
    }

    try {
      final response = await supabase
          .from('borrow_requests')
          .select('*, equipment(name, image_url)')
          .eq('borrower_id', userId)
          .inFilter('status', ['returned', 'rejected', 'cancelled', 'expired'])
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
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final newData = await _fetchHistoryRequests();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Borrowing History',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2B326B),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(color: const Color(0xFFFFC107), height: 4.0),
        ),
      ),
      body: RefreshIndicator(
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

            final historyRequests = snapshot.data ?? [];
            if (historyRequests.isEmpty) {
              return _buildScrollableEmptyState();
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              itemCount: historyRequests.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _buildBorrowedItemCard(historyRequests[index]),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildScrollableEmptyState() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyState(),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No History Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your completed borrowings will appear here.',
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
    String statusDescription = _getStatusDescription(item.status.toLowerCase(), item);

    final imageUrl = item.equipmentImageUrl;
    const placeholderUrl = 'https://via.placeholder.com/70/D3D3D3/000000?text=No+Img';

    return GestureDetector(
      onTap: () {
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Equipment Image
            ClipRRect(
              borderRadius: BorderRadius.circular(10.0),
              child: Image.network(
                imageUrl ?? placeholderUrl,
                width: 70,
                height: 70,
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

            // Details Column
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

                  _buildDateInfo(item, dateTimeFormatter, statusColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  String _getStatusDescription(String status, BorrowRequest item) {
    switch (status) {
      case 'returned':
        return 'Successfully returned';
      case 'rejected':
        return 'Request denied by admin';
      case 'cancelled':
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
      case 'returned':
        return 'Returned';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
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
        return const SizedBox.shrink();

      case 'cancelled':
        return const SizedBox.shrink();

      default:
        return Text(
          'Due: ${formatter.format(item.returnDate)}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        );
    }
  }
}