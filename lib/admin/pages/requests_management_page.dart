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
  Key _tabViewKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    // CHANGED: Length is now 7 to include 'Overdue'
    _tabController = TabController(length: 7, vsync: this);
  }

  // Forces a full rebuild of the TabBarView and switches to the correct tab.
  void _refreshAllTabsAndSwitch({String? targetStatus}) {
    setState(() {
      // Force a rebuild of all tabs (reload data in RequestListTab)
      _tabViewKey = UniqueKey();

      // Switch to the appropriate tab based on target status
      if (targetStatus != null) {
        final targetIndex = _getTabIndexForStatus(targetStatus);
        if (targetIndex != -1) {
          _tabController.animateTo(targetIndex);
        }
      }
    });
  }

  // Helper to get tab index from status
  int _getTabIndexForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0;
      case 'approved':
        return 1;
      case 'active':
        return 2;
      case 'overdue': // <--- ADDED
        return 3;
      case 'returned':
        return 4; // Index shifted
      case 'cancelled':
        return 5; // Index shifted
      case 'expired':
        return 6; // Index shifted
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
            Tab(text: 'Overdue'), // <--- ADDED
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
              status: 'overdue', onGlobalAction: _refreshAllTabsAndSwitch), // <--- ADDED
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
  bool get wantKeepAlive => false; // Don't keep state alive to force refresh

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

  // Auto-trigger refresh after any action
  Future<void> _refreshRequests() async {
    await Future.delayed(const Duration(milliseconds: 300)); // Small delay for backend to process
    _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return RefreshIndicator(
      key: _refreshKey,
      onRefresh: () async {
        _loadRequests();
        await _requestsFuture; // Wait for the future to complete
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
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
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
            return ListView( // Wrap in ListView so pull-to-refresh works
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
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
                          _getEmptyStateMessage(widget.status),
                          style: GoogleFonts.poppins(color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              return RequestCard(
                request: requests[index],
                onAction: widget.onGlobalAction,
                onLocalRefresh: _refreshRequests, // Pass refresh callback
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
      case 'overdue': // <--- ADDED
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
      case 'overdue': // <--- ADDED
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
  final VoidCallback onLocalRefresh; // Add this

  const RequestCard({
    super.key,
    required this.request,
    required this.onAction,
    required this.onLocalRefresh, // Add this
  });

  @override
  Widget build(BuildContext context) {
    final userProfiles = request['user_profiles'] ?? {};
    final equipment = request['equipment'] ?? {};

    // ➡️ ADDED: Check for rejection reason
    final rejectionReason = request['rejection_reason'] as String?;

    // ➡️ ADDED: Determine if it was rejected by admin
    // We assume if a rejection_reason is present, it was admin-rejected.
    // (A borrower cancellation wouldn't set this field).
    final isAdminRejected = rejectionReason != null && rejectionReason.isNotEmpty;


    // ➡️ ADDED: Extract avatar URL
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
      case 'overdue': // <--- ADDED
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
        // CHANGED: Use simplified check for coloring the background
        color: isCurrentOverdue ? Colors.red.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isCurrentOverdue // CHANGED: Use simplified check for border
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
          Row(
            children: [
              // ➡️ MODIFIED: CircleAvatar to display Network Image or Initials
              CircleAvatar(
                radius: 20,
                // 1. Check if we have a valid avatar URL to use for the image
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null,

                // 2. Set background color: Neutral for image, or status-based for initials
                backgroundColor: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? Colors.grey // Neutral background when image is loaded
                    : statusColor.withOpacity(0.1), // Original background for initials

                // 3. Fallback: Only show initials (the existing child logic) if NO avatar URL is set
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Text(
                        getUserInitials(userName),
                        style: GoogleFonts.poppins(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null, // No child when an image is loaded
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName.isNotEmpty ? userName : 'Unknown User',
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
          const SizedBox(height: 16),
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
                      // CHANGED: Use simplified check for return date color
                      '${dateFormatter.format(returnDate)} ${timeFormatter.format(returnDate)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: isCurrentOverdue ? Colors.red : Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
            child: OutlinedButton(
              onPressed: () => _showRejectDialog(
                context,
                requestId,
                borrowerId,
                equipmentName,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text('Reject', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _approveRequest(
                context,
                requestId,
                borrowerId,
                equipmentName,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text('Approve', style: TextStyle(fontSize: 12)),
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

    case 'active': // Standard, non-overdue borrowing period
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _sendReminder(
                    context,
                    requestId,
                    borrowerId,
                    equipmentName,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange, // Standard reminder color
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  child: const Text('Remind', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showExtendDialog(context, requestId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue, // Standard extension color
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  child: const Text('Extend', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _markAsReturned(context, requestId, equipmentId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text('Mark Returned', style: TextStyle(fontSize: 12)),
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
            'Action Required: Item is Overdue',
            style: GoogleFonts.poppins(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _sendReminder(
                    context,
                    requestId,
                    borrowerId,
                    equipmentName,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red, // URGENT: Red for overdue follow-up
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  child: const Text('Remind', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showExtendDialog(context, requestId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange, // Slightly less urgent, but modification is possible
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  child: const Text('Extend', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _markAsReturned(context, requestId, equipmentId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, // Final positive action
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text('Mark Returned', style: TextStyle(fontSize: 12)),
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
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Successfully returned',
                style: GoogleFonts.poppins(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
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
            Icon(Icons.cancel, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                isAdminRejected ? 'Rejected by Admin' : 'Cancelled by user',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Request expired',
                  style: GoogleFonts.poppins(
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _reactivateExpiredRequest(context, requestId),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text('Reactivate', style: TextStyle(fontSize: 12)),
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

  // FIX 1: Approve Request (Pending -> Approved)
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
      onLocalRefresh(); // Refresh current tab first
      await Future.delayed(const Duration(milliseconds: 100));
      onAction(targetStatus: 'approved'); // Then switch tabs
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
              labelText: 'Reason *', // <-- CHANGED: Remove (optional)
              hintText: 'Enter rejection reason',
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
            // ADDED: Validation
            if (reasonController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please provide a rejection reason'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }

            try {
              await RequestManagementService.rejectRequest(
                requestId,
                borrowerId,
                equipmentName,
                reason: reasonController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Request rejected successfully!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  onLocalRefresh(); // Refresh current tab first
                  await Future.delayed(const Duration(milliseconds: 100));
                  onAction(targetStatus: 'cancelled'); // Stay on Pending tab, forces refresh
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

  // FIX 2: Hand Out Equipment (Approved -> Active)
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
        // ✅ CORRECT: Request is now 'active', navigate to Active tab
        onLocalRefresh(); // Refresh current tab first
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

  // FIX 3: Mark as Returned (Active -> Returned)
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
          // ✅ CORRECT: Request is now 'returned', navigate to Returned tab
          onLocalRefresh(); // Refresh current tab first
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

  // FIX 4: Reactivate Expired Request (Expired -> Pending)
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
          // ✅ CORRECT: Request is now 'pending', navigate to Pending tab
          onLocalRefresh(); // Refresh current tab first
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
                    onLocalRefresh(); // Refresh current tab first
      await Future.delayed(const Duration(milliseconds: 100));
                    onAction(targetStatus: 'active'); // Stay on Active tab
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