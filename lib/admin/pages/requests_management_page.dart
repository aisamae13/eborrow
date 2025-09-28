import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/request_management_service.dart';
import '../../main.dart';

class RequestsManagementPage extends StatefulWidget {
  const RequestsManagementPage({super.key});

  @override
  State<RequestsManagementPage> createState() => _RequestsManagementPageState();
}

class _RequestsManagementPageState extends State<RequestsManagementPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Borrowing Requests',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2B326B),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFFC107),
          unselectedLabelColor: Colors.white70,
          indicatorColor: const Color(0xFFFFC107),
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Active'),
            Tab(text: 'Returned'),
            Tab(text: 'Cancelled'),
            Tab(text: 'Expired'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          RequestsTab(status: 'pending'),
          RequestsTab(status: 'approved'),
          RequestsTab(status: 'active'),
          RequestsTab(status: 'returned'), // ✅ ADDED
          RequestsTab(status: 'cancelled'), // ✅ ADDED
          RequestsTab(status: 'expired'), // ✅ ADDED
        ],
      ),
    );
  }
}

class RequestsTab extends StatefulWidget {
  final String status;

  const RequestsTab({super.key, required this.status});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  late Future<List<Map<String, dynamic>>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() {
    setState(() {
      _requestsFuture = RequestManagementService.getRequestsByStatus(
        widget.status,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _loadRequests();
      },
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Error loading requests', style: GoogleFonts.poppins()),
                  TextButton(
                    onPressed: _loadRequests,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getStatusIcon(widget.status),
                    size: 80,
                    color: Colors.grey[400],
                  ), // ✅ FIXED
                  const SizedBox(height: 16),
                  Text(
                    'No ${widget.status.toLowerCase()} requests',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getEmptyStateMessage(widget.status), // ✅ FIXED
                    style: GoogleFonts.poppins(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              return RequestCard(
                request: requests[index],
                onAction: _loadRequests,
              );
            },
          );
        },
      ),
    );
  }

  // ✅ FIXED: Now being used in the build method
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'approved':
        return Icons.check_circle;
      case 'active':
        return Icons.handshake;
      case 'returned':
        return Icons.assignment_return;
      case 'cancelled':
        return Icons.cancel;
      case 'expired':
        return Icons.schedule;
      default:
        return Icons.assignment;
    }
  }

  // ✅ FIXED: Now being used in the build method
  String _getEmptyStateMessage(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'New requests will appear here';
      case 'approved':
        return 'Approved requests ready for pickup';
      case 'active':
        return 'Currently borrowed equipment';
      case 'returned':
        return 'Successfully returned equipment';
      case 'cancelled':
        return 'User-cancelled requests';
      case 'expired':
        return 'Expired pending requests';
      default:
        return 'Requests will appear here when available';
    }
  }
}

class RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAction;

  const RequestCard({super.key, required this.request, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final userProfiles = request['user_profiles'] ?? {};
    final equipment = request['equipment'] ?? {};

    final userName =
        '${userProfiles['first_name'] ?? 'Unknown'} ${userProfiles['last_name'] ?? 'User'}'
            .trim(); // ✅ Added .trim()
    final studentId = userProfiles['student_id'] ?? 'N/A';
    final equipmentName = equipment['name'] ?? 'Unknown Equipment';
    final equipmentBrand = equipment['brand'] ?? '';
    final status = request['status'] ?? '';

    final borrowDate =
        DateTime.tryParse(request['borrow_date'] ?? '') ?? DateTime.now();
    final returnDate =
        DateTime.tryParse(request['return_date'] ?? '') ?? DateTime.now();
    final requestId = request['request_id'] ?? 0;
    final borrowerId = request['borrower_id'] ?? '';
    final equipmentId = request['equipment_id'] ?? 0;
    final purpose = request['purpose'] ?? '';

    final dateFormatter = DateFormat('MMM dd, yyyy');
    final timeFormatter = DateFormat('hh:mm a');

    // Determine if overdue (for active items)
    final isOverdue = status == 'active' && DateTime.now().isAfter(returnDate);

    // Get status color and badge
    Color statusColor;
    String statusBadge;

    switch (status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange;
        statusBadge = 'Pending';
        break;
      case 'approved':
        statusColor = Colors.green;
        statusBadge = 'Approved';
        break;
      case 'active':
        statusColor = isOverdue ? Colors.red : Colors.blue;
        statusBadge = isOverdue ? 'Overdue' : 'Active';
        break;
      case 'returned':
        statusColor = Colors.green;
        statusBadge = 'Returned';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusBadge = 'Cancelled';
        break;
      case 'expired':
        statusColor = Colors.orange;
        statusBadge = 'Expired';
        break;
      default:
        statusColor = Colors.grey;
        statusBadge = status.toUpperCase();
    }

    // ✅ FIXED: Safe way to get user initials
    String getUserInitials(String name) {
      if (name.isEmpty) return 'U'; // Default to 'U' for User

      final parts = name
          .trim()
          .split(' ')
          .where((part) => part.isNotEmpty)
          .toList();
      if (parts.isEmpty) return 'U';

      if (parts.length == 1) {
        return parts[0][0].toUpperCase();
      } else {
        return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isOverdue
            ? Border.all(color: Colors.red.withOpacity(0.3))
            : null,
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
          // Header: User info and status
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withOpacity(0.1),
                child: Text(
                  getUserInitials(userName), // ✅ FIXED: Use safe method
                  style: GoogleFonts.poppins(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName.isNotEmpty
                          ? userName
                          : 'Unknown User', // ✅ FIXED: Handle empty names
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      studentId,
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusBadge,
                  style: GoogleFonts.poppins(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          // ... rest of your existing code stays the same
          const SizedBox(height: 16),

          // Equipment info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getEquipmentIcon(equipmentName),
                  size: 24,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipmentName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (equipmentBrand.isNotEmpty)
                      Text(
                        equipmentBrand,
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Date info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Borrow Date:',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${dateFormatter.format(borrowDate)} ${timeFormatter.format(borrowDate)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Return Date:',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${dateFormatter.format(returnDate)} ${timeFormatter.format(returnDate)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: isOverdue ? Colors.red : Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Purpose
          if (purpose.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Purpose:',
              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              purpose,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action buttons
          _buildActionButtons(
            context,
            status,
            requestId,
            borrowerId,
            equipmentName,
            equipmentId,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    String status,
    int requestId,
    String borrowerId,
    String equipmentName,
    int equipmentId,
  ) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showRejectDialog(
                  context,
                  requestId,
                  borrowerId,
                  equipmentName,
                ),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _approveRequest(
                  context,
                  requestId,
                  borrowerId,
                  equipmentName,
                ),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );

      case 'returned':
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text(
                'Successfully returned',
                style: GoogleFonts.poppins(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );

      case 'cancelled':
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.cancel, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Text(
                'Cancelled by user',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );

      case 'expired':
        return Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Request expired',
                      style: GoogleFonts.poppins(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _reactivateExpiredRequest(context, requestId),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reactivate'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
              ),
            ),
          ],
        );

      case 'approved':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _handOutEquipment(context, requestId, equipmentId),
            icon: const Icon(Icons.handshake, size: 16),
            label: const Text('Hand Out Equipment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B326B),
              foregroundColor: Colors.white,
            ),
          ),
        );

      case 'active':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _sendReminder(
                  context,
                  requestId,
                  borrowerId,
                  equipmentName,
                ),
                icon: const Icon(Icons.notifications, size: 16),
                label: const Text('Send Reminder'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showExtendDialog(context, requestId),
                icon: const Icon(Icons.schedule, size: 16),
                label: const Text('Extend'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () =>
                    _markAsReturned(context, requestId, equipmentId),
                icon: const Icon(Icons.assignment_return, size: 16),
                label: const Text('Mark Returned'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  IconData _getEquipmentIcon(String equipmentName) {
    final name = equipmentName.toLowerCase();
    if (name.contains('laptop') || name.contains('macbook')) {
      return Icons.laptop_mac;
    } else if (name.contains('projector')) {
      return Icons.video_camera_front;
    } else if (name.contains('cable') || name.contains('hdmi')) {
      return Icons.cable;
    } else if (name.contains('tablet') || name.contains('ipad')) {
      return Icons.tablet_mac;
    } else if (name.contains('audio') ||
        name.contains('speaker') ||
        name.contains('microphone')) {
      return Icons.headset;
    }
    return Icons.inventory_2;
  }

  void _approveRequest(
    BuildContext context,
    int requestId,
    String borrowerId,
    String equipmentName,
  ) async {
    try {
      await RequestManagementService.approveRequest(
        requestId,
        borrowerId,
        equipmentName,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        onAction(); // Refresh the list
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRejectDialog(
    BuildContext context,
    int requestId,
    String borrowerId,
    String equipmentName,
  ) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to reject this request?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await RequestManagementService.rejectRequest(
                  requestId,
                  borrowerId,
                  equipmentName,
                  reason: reasonController.text.trim().isNotEmpty
                      ? reasonController.text.trim()
                      : null,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Request rejected successfully!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  onAction();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error rejecting request: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handOutEquipment(
    BuildContext context,
    int requestId,
    int equipmentId,
  ) async {
    try {
      await RequestManagementService.handOutEquipment(requestId, equipmentId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Equipment handed out successfully!'),
            backgroundColor: Colors.blue,
          ),
        );
        onAction();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error handing out equipment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _markAsReturned(
    BuildContext context,
    int requestId,
    int equipmentId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Returned'),
        content: const Text('Confirm that this equipment has been returned?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await RequestManagementService.markAsReturned(requestId, equipmentId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Equipment marked as returned!'),
              backgroundColor: Colors.green,
            ),
          );
          onAction();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error marking as returned: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _sendReminder(
    BuildContext context,
    int requestId,
    String borrowerId,
    String equipmentName,
  ) async {
    try {
      await RequestManagementService.sendReminder(
        requestId,
        borrowerId,
        equipmentName,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder sent successfully!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending reminder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _reactivateExpiredRequest(BuildContext context, int requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reactivate Request'),
        content: const Text(
          'This will change the status back to pending. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text(
              'Reactivate',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await supabase
            .from('borrow_requests')
            .update({'status': 'pending'})
            .eq('request_id', requestId);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request reactivated successfully!'),
              backgroundColor: Colors.blue,
            ),
          );
          onAction();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error reactivating request: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showExtendDialog(BuildContext context, int requestId) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Extend Borrowing Period'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select new return date:'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (date != null) {
                    setState(() {
                      selectedDate = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        selectedDate.hour,
                        selectedDate.minute,
                      );
                    });
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await RequestManagementService.extendBorrowing(
                    requestId,
                    selectedDate,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Borrowing period extended!'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                    onAction();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error extending period: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Extend'),
            ),
          ],
        ),
      ),
    );
  }
}
