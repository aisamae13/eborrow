import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../models/borrow_request.dart';
import 'package:eborrow/shared/utils/string_extension.dart';
import 'modify_request_page.dart';
import 'request_detail_popup.dart';
import '../../shared/notifications/notification_service.dart';

class ActiveBorrowingsPage extends StatefulWidget {
  const ActiveBorrowingsPage({super.key});

  @override
  State<ActiveBorrowingsPage> createState() => _ActiveBorrowingsPageState();
}

class _ActiveBorrowingsPageState extends State<ActiveBorrowingsPage> {
  Future<List<BorrowRequest>>? _requestsFuture;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _requestsFuture = _fetchActiveRequests();
  }

  Future<List<BorrowRequest>> _fetchActiveRequests() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return [];
    }

    try {
      // Scan for overdue requests before fetching
      await supabase.rpc('scan_overdue_requests');

      final response = await supabase
          .from('borrow_requests')
          .select('*, equipment(name, image_url)')
          .eq('borrower_id', userId)
          .inFilter('status', ['pending', 'approved', 'active', 'overdue'])
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
              'Error fetching active requests. Check your connection.',
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
      final newData = await _fetchActiveRequests();
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

  Future<void> _cancelRequest(BorrowRequest request) async {
    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange[600],
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Confirm Cancellation',
                style: TextStyle(fontSize: 20),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to cancel this borrow request?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Equipment: ${request.equipmentName}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Keep Request',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (shouldCancel == true) {
      try {
        // 🆕 NEW: Cancel any active reminders for this request
        LocalReminderService.cancelRemindersForRequest(request.requestId.toString());
        
        // Create notification about the cancellation
        await NotificationService.createNotification(
          userId: request.borrowerId,
          title: 'Request Cancelled',
          message:
              'You have cancelled your borrow request for "${request.equipmentName}".',
          type: NotificationType.general,
          metadata: {
            'equipment_name': request.equipmentName,
            'action': 'cancelled_by_user',
          },
        );

        // Update the request status in the database
        await supabase
            .from('borrow_requests')
            .update({'status': 'cancelled'})
            .eq('request_id', request.requestId);

        if (mounted) {
          // Refresh the data
          setState(() {
            _requestsFuture = _fetchActiveRequests();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Request cancelled successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Error cancelling request: ${e.toString()}'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Active Borrowings',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF2B326B),
        child: FutureBuilder<List<BorrowRequest>>(
          future: _requestsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !_isRefreshing) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2B326B),
                ),
              );
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            final activeRequests = snapshot.data ?? [];
            if (activeRequests.isEmpty) {
              return _buildScrollableEmptyState();
            }

            return Column(
              children: [
                // Status Summary Card
                _buildStatusSummary(activeRequests),
                
                // Requests List
                Expanded(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    itemCount: activeRequests.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _buildBorrowedItemCard(activeRequests[index]),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusSummary(List<BorrowRequest> requests) {
    final pending = requests.where((r) => r.status.toLowerCase() == 'pending').length;
    final approved = requests.where((r) => r.status.toLowerCase() == 'approved').length;
    final active = requests.where((r) => r.status.toLowerCase() == 'active').length;
    final overdue = requests.where((r) => r.status.toLowerCase() == 'overdue').length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2B326B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSummaryItem('Pending', pending, Colors.orange)),
              Expanded(child: _buildSummaryItem('Approved', approved, Colors.blue)),
              Expanded(child: _buildSummaryItem('Active', active, Colors.green)),
              Expanded(child: _buildSummaryItem('Overdue', overdue, Colors.red)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
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
                    'Pull down to retry or tap refresh',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _refreshData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B326B),
                    foregroundColor: Colors.white,
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.hourglass_empty,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Active Borrowings',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Your pending, approved, active, and overdue borrowings will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Removed the "Go Back" button
        ],
      ),
    );
  }

  Widget _buildBorrowedItemCard(BorrowRequest item) {
    final statusColor = item.getStatusColor();
    final dateTimeFormatter = DateFormat('MMM dd, yyyy hh:mm a');
    final isPending = item.status.toLowerCase() == 'pending';
    final isOverdue = item.status.toLowerCase() == 'overdue';
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
          border: isOverdue ? Border.all(color: Colors.red, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 2,
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overdue Warning Banner
            if (isOverdue) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[600], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'OVERDUE - Please return immediately',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            Row(
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
                            color: const Color(0xFF2B326B),
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
                          Flexible( // Wrap Text with Flexible
                            child: Text(
                              item.equipmentName,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
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
                              style: GoogleFonts.poppins(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Status description
                      if (statusDescription.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusDescription,
                            style: GoogleFonts.poppins(
                              color: Colors.grey[700],
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      Row(
                        children: [
                          Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Requested: ${dateTimeFormatter.format(item.borrowDate)}',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600], 
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      _buildDateInfo(item, dateTimeFormatter, statusColor),
                    ],
                  ),
                ),
              ],
            ),

            // Action Buttons for pending requests only
            if (isPending) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text(
                      item.modificationCount >= 3 
                        ? 'Modify (Limit Reached)' 
                        : 'Modify Request'
                    ),
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
                      foregroundColor: item.modificationCount >= 3 
                        ? Colors.grey 
                        : const Color(0xFF2B326B),
                      side: BorderSide(
                        color: item.modificationCount >= 3 
                          ? Colors.grey 
                          : const Color(0xFF2B326B),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Cancel'),
                    onPressed: () => _cancelRequest(item),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red[600],
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
      ),
    );
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
      default:
        return status.capitalize();
    }
  }

  Widget _buildDateInfo(
    BorrowRequest item,
    DateFormat formatter,
    Color statusColor,
  ) {
    Widget dateWidget;
    IconData iconData;
    
    switch (item.status.toLowerCase()) {
      case 'pending':
      case 'approved':
        iconData = Icons.event;
        dateWidget = Text(
          'Due date: ${formatter.format(item.returnDate)}',
          style: GoogleFonts.poppins(
            color: Colors.grey[600], 
            fontSize: 11,
          ),
        );
        break;

      case 'active':
        iconData = Icons.schedule;
        dateWidget = Text(
          'Due: ${formatter.format(item.returnDate)}',
          style: GoogleFonts.poppins(
            color: statusColor,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        );
        break;

      case 'overdue':
        iconData = Icons.warning;
        dateWidget = Text(
          'Was due: ${formatter.format(item.returnDate)}',
          style: GoogleFonts.poppins(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        );
        break;

      default:
        iconData = Icons.event;
        dateWidget = Text(
          'Due: ${formatter.format(item.returnDate)}',
          style: GoogleFonts.poppins(
            color: Colors.grey[600], 
            fontSize: 11,
          ),
        );
    }

    return Row(
      children: [
        Icon(iconData, size: 14, color: statusColor),
        const SizedBox(width: 4),
        dateWidget,
      ],
    );
  }
}