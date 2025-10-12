import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/request_management_service.dart';
import '../../main.dart';
import '../widgets/borrow_countdown_timer.dart';

class RequestsManagementPage extends StatefulWidget {
  const RequestsManagementPage({super.key});

  @override
  State<RequestsManagementPage> createState() => _RequestsManagementPageState();
}

class _RequestsManagementPageState extends State<RequestsManagementPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  Key _tabViewKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  void _refreshAllTabsAndSwitch({String? targetStatus}) {
    setState(() {
      _tabViewKey = UniqueKey();

      if (targetStatus != null) {
        final targetIndex = _getTabIndexForStatus(targetStatus);
        if (targetIndex != -1) {
          _tabController.animateTo(targetIndex);
        }
      }
    });
  }

  int _getTabIndexForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0;
      case 'approved':
        return 1;
      case 'active':
        return 2;
      case 'overdue':
        return 3;
      case 'returned':
        return 4;
      case 'cancelled':
        return 5;
      case 'expired':
        return 6;
      default:
        return -1;
    }
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
            fontSize: 24,
            fontWeight: FontWeight.w500,
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
            Tab(text: 'Overdue'),
            Tab(text: 'Returned'),
            Tab(text: 'Cancelled'),
            Tab(text: 'Expired'),
          ],
        ),
      ),
      body: TabBarView(
        key: _tabViewKey,
        controller: _tabController,
        children: [
          RequestsTab(
              status: 'pending', onGlobalAction: _refreshAllTabsAndSwitch),
          RequestsTab(
              status: 'approved', onGlobalAction: _refreshAllTabsAndSwitch),
          RequestsTab(
              status: 'active', onGlobalAction: _refreshAllTabsAndSwitch),
          RequestsTab(
              status: 'overdue', onGlobalAction: _refreshAllTabsAndSwitch),
          RequestsTab(
              status: 'returned', onGlobalAction: _refreshAllTabsAndSwitch),
          RequestsTab(
              status: 'cancelled', onGlobalAction: _refreshAllTabsAndSwitch),
          RequestsTab(
              status: 'expired', onGlobalAction: _refreshAllTabsAndSwitch),
        ],
      ),
    );
  }
}

class RequestsTab extends StatefulWidget {
  final String status;
  final void Function({String? targetStatus}) onGlobalAction;

  const RequestsTab(
      {super.key, required this.status, required this.onGlobalAction});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> with AutomaticKeepAliveClientMixin {
  late Future<List<Map<String, dynamic>>> _requestsFuture;
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  bool get wantKeepAlive => false;

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

  Future<void> _refreshRequests() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      key: _refreshKey,
      onRefresh: () async {
        _loadRequests();
        await _requestsFuture;
      },
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2B326B),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading requests',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getStatusIcon(widget.status),
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No ${widget.status} requests',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getEmptyStateMessage(widget.status),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return RequestCard(
                request: request,
                onAction: widget.onGlobalAction,
                onLocalRefresh: _refreshRequests,
              );
            },
          );
        },
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'approved':
        return Icons.check_circle;
      case 'active':
        return Icons.handshake;
      case 'overdue':
        return Icons.warning_amber;
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

  String _getEmptyStateMessage(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'New requests will appear here';
      case 'approved':
        return 'Approved requests ready for pickup';
      case 'active':
        return 'Currently borrowed equipment, on time';
      case 'overdue':
        return 'Urgent: These items are past their return date!';
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
  final void Function({String? targetStatus}) onAction;
  final VoidCallback onLocalRefresh;

  const RequestCard({
    super.key,
    required this.request,
    required this.onAction,
    required this.onLocalRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final userProfiles = request['user_profiles'] ?? {};
    final equipment = request['equipment'] ?? {};

    final rejectionReason = request['rejection_reason'] as String?;
    final isAdminRejected = rejectionReason != null && rejectionReason.isNotEmpty;
    final avatarUrl = userProfiles['avatar_url'] as String?;

    final userName =
        '${userProfiles['first_name'] ?? 'Unknown'} ${userProfiles['last_name'] ?? 'User'}'
            .trim();
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
        statusColor = Colors.blue;
        statusBadge = 'Active';
        break;
      case 'overdue':
        statusColor = Colors.red;
        statusBadge = 'Overdue';
        break;
      case 'returned':
        statusColor = Colors.green;
        statusBadge = 'Returned';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        final rejectionReason = request['rejection_reason'] as String?;

        if (rejectionReason != null && rejectionReason.isNotEmpty) {
           statusBadge = 'Rejected';
        } else {
           statusBadge = 'Cancelled';
        }
        break;
      case 'expired':
        statusColor = Colors.orange;
        statusBadge = 'Expired';
        break;
      default:
        statusColor = Colors.grey;
        statusBadge = status.toUpperCase();
    }

    final isCurrentOverdue = status.toLowerCase() == 'overdue';

    String getUserInitials(String name) {
      if (name.isEmpty) return 'U';

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
        color: isCurrentOverdue ? Colors.red.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isCurrentOverdue
            ? Border.all(color: Colors.red.withOpacity(0.3))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: statusColor.withOpacity(0.2),
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(
                        getUserInitials(userName),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: statusColor,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: const Color(0xFF2B326B),
                      ),
                    ),
                    Text(
                      studentId,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
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
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusBadge,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                _getEquipmentIcon(equipmentName),
                size: 24,
                color: const Color(0xFF2B326B),
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
                        fontSize: 15,
                        color: const Color(0xFF2B326B),
                      ),
                    ),
                    if (equipmentBrand.isNotEmpty)
                      Text(
                        equipmentBrand,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text('Borrow Date:',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey[600])),
                    const Spacer(),
                    Text(
                      '${dateFormatter.format(borrowDate)} ${timeFormatter.format(borrowDate)}',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.event_available,
                        size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text('Return Date:',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey[600])),
                    const Spacer(),
                    Text(
                      '${dateFormatter.format(returnDate)} ${timeFormatter.format(returnDate)}',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // UPDATED: Add countdown timer that stops auto-refreshing for overdue
          if (['approved','active','overdue'].contains(status.toLowerCase())) ...[
            const SizedBox(height: 12),
            BorrowCountdownTimer(
              borrowDate: borrowDate,
              returnDate: returnDate,
              status: status, // Pass the status parameter as required
              compact: false,
              onFinished: () {
                // Only refresh if the current status is NOT already overdue
                // This prevents unnecessary refreshes when already overdue
                if (context.mounted && status.toLowerCase() != 'overdue') {
                  onLocalRefresh();
                }
              },
            ),
          ],
          if (purpose.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Purpose: $purpose',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.blue[800],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildActionButtons(
            context,
            status,
            requestId,
            borrowerId,
            equipmentName,
            equipmentId,
            isAdminRejected,
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
  bool isAdminRejected,
) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _approveRequest(context, requestId, borrowerId, equipmentName),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Approve', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showRejectDialog(context, requestId, borrowerId, equipmentName),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Reject', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      );

    case 'approved':
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _handOutEquipment(context, requestId, equipmentId),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2B326B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          child: const Text('Hand Out Equipment', style: TextStyle(fontSize: 12)),
        ),
      );

    case 'active':
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _sendReminder(context, requestId, borrowerId, equipmentName),
                  icon: const Icon(Icons.notifications, size: 16),
                  label: const Text('Remind', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showExtendDialog(context, requestId),
                  icon: const Icon(Icons.access_time, size: 16),
                  label: const Text('Extend', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _markAsReturned(context, requestId, equipmentId),
              icon: const Icon(Icons.assignment_return, size: 16),
              label: const Text('Mark as Returned', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      );

    case 'overdue':
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⚠️ This equipment is overdue! Please contact the borrower immediately.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _sendReminder(context, requestId, borrowerId, equipmentName),
                  icon: const Icon(Icons.priority_high, size: 16),
                  label: const Text('Send Urgent Reminder', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showExtendDialog(context, requestId),
                  icon: const Icon(Icons.access_time, size: 16),
                  label: const Text('Extend', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _markAsReturned(context, requestId, equipmentId),
              icon: const Icon(Icons.assignment_return, size: 16),
              label: const Text('Mark as Returned', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      );

    case 'returned':
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 6),
            Text(
              'Equipment successfully returned',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );

    case 'cancelled':
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info, color: Colors.grey, size: 16),
            const SizedBox(width: 6),
            Text(
              isAdminRejected ? 'Request rejected by admin' : 'Request cancelled by user',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );

    case 'expired':
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.orange, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'This request expired due to inactivity',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _reactivateExpiredRequest(context, requestId),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reactivate Request', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B326B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
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
        const SnackBar(
          content: Text('Request approved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      onLocalRefresh();
      await Future.delayed(const Duration(milliseconds: 100));
      onAction(targetStatus: 'approved');
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
              labelText: 'Rejection Reason (Optional)',
              hintText: 'Enter reason for rejection...',
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
            Navigator.pop(context);
            try {
              await RequestManagementService.rejectRequest(
                requestId,
                borrowerId,
                equipmentName,
                // reasonController.text.trim(), // Remove or change to named argument if supported
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Request rejected successfully!'),
                    backgroundColor: Colors.red,
                  ),
                );
                onLocalRefresh();
                await Future.delayed(const Duration(milliseconds: 100));
                onAction(targetStatus: 'cancelled');
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
        onLocalRefresh();
        await Future.delayed(const Duration(milliseconds: 100));
        onAction(targetStatus: 'active');
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
              content: Text('Equipment marked as returned successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          onLocalRefresh();
          await Future.delayed(const Duration(milliseconds: 100));
          onAction(targetStatus: 'returned');
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B326B),
            ),
            child: const Text('Reactivate', style: TextStyle(color: Colors.white)),
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
              backgroundColor: Colors.green,
            ),
          );
          onLocalRefresh();
          await Future.delayed(const Duration(milliseconds: 100));
          onAction(targetStatus: 'pending');
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
              ListTile(
                title: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      selectedDate = pickedDate;
                    });
                  }
                },
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
                Navigator.pop(context);
                try {
                  await supabase
                      .from('borrow_requests')
                      .update({'return_date': selectedDate.toIso8601String()})
                      .eq('request_id', requestId);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Borrowing period extended successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    onLocalRefresh();
                    await Future.delayed(const Duration(milliseconds: 100));
                    onAction(targetStatus: 'active');
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