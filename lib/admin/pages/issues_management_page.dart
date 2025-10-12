import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';

class IssuesManagementPage extends StatefulWidget {
  const IssuesManagementPage({super.key});

  @override
  State<IssuesManagementPage> createState() => _IssuesManagementPageState();
}

class _IssuesManagementPageState extends State<IssuesManagementPage> {
  late Future<List<Map<String, dynamic>>> _issuesFuture;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  void _loadIssues() {
    setState(() {
      _issuesFuture = _fetchIssues();
    });
  }

Future<List<Map<String, dynamic>>> _fetchIssues() async {
  try {
    final baseQuery = supabase.from('issues');

    // Build the query based on filter
    final PostgrestFilterBuilder query;
    if (_selectedFilter != 'all') {
      query = baseQuery
          .select('''
            *,
            user_profiles!reporter_id(first_name, last_name, email),
            equipment(name, brand, qr_code)
          ''')
          .eq('status', _selectedFilter);
    } else {
      query = baseQuery
          .select('''
            *,
            user_profiles!reporter_id(first_name, last_name, email),
            equipment(name, brand, qr_code)
          ''');
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    debugPrint('Error fetching issues: $e');
    return [];
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Issue Reports',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2B326B),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(color: const Color(0xFFFFC107), height: 4.0),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16), // 🎨 Top spacing
          _buildFilterBar(),
          const SizedBox(height: 16), // 🎨 Spacing
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadIssues(),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _issuesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6E8F0),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFFBCC0D0),
                              offset: Offset(6, 6),
                              blurRadius: 12,
                            ),
                            BoxShadow(
                              color: Colors.white,
                              offset: Offset(-6, -6),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2B326B)),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState();
                  }

                  final issues = snapshot.data ?? [];

                  if (issues.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20), // 🎨 Consistent padding
                    itemCount: issues.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16), // 🎨 Consistent spacing
                        child: _buildIssueCard(issues[index]),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E8F0),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFBCC0D0),
            offset: Offset(3, 3),
            blurRadius: 8,
          ),
          BoxShadow(
            color: Colors.white,
            offset: Offset(-3, -3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Issues',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2B326B),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Open', 'open'),
                const SizedBox(width: 8),
                _buildFilterChip('In Progress', 'in_progress'),
                const SizedBox(width: 8),
                _buildFilterChip('Resolved', 'resolved'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
        _loadIssues();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDEE2F0) : const Color(0xFFE6E8F0),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: const Color(0xFF2B326B), width: 1.5)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2B326B).withOpacity(0.13),
                    offset: const Offset(2, 2),
                    blurRadius: 6,
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    offset: Offset(-2, -2),
                    blurRadius: 6,
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Color(0xFFBCC0D0),
                    offset: Offset(2, 2),
                    blurRadius: 6,
                  ),
                  const BoxShadow(
                    color: Colors.transparent,
                    offset: Offset(-2, -2),
                    blurRadius: 6,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getFilterIcon(value),
              size: 16,
              color: isSelected ? const Color(0xFF2B326B) : const Color(0xFF2B326B).withOpacity(0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: const Color(0xFF2B326B),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'all':
        return Icons.list_alt;
      case 'open':
        return Icons.error_outline;
      case 'in_progress':
        return Icons.pending_outlined;
      case 'resolved':
        return Icons.check_circle_outline;
      default:
        return Icons.filter_list;
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFE6E8F0),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFBCC0D0),
              offset: Offset(6, 6),
              blurRadius: 12,
            ),
            BoxShadow(
              color: Colors.white,
              offset: Offset(-6, -6),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Error loading issues',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2B326B),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadIssues,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B326B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFE6E8F0),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFBCC0D0),
              offset: Offset(6, 6),
              blurRadius: 12,
            ),
            BoxShadow(
              color: Colors.white,
              offset: Offset(-6, -6),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: const Color(0xFF2B326B).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No issues found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2B326B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'all'
                  ? 'No reported issues yet'
                  : 'No $_selectedFilter issues',
              style: GoogleFonts.poppins(
                color: const Color(0xFF2B326B).withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueCard(Map<String, dynamic> issue) {
    final status = issue['status'] ?? 'open';
    final statusColor = _getStatusColor(status);
    final reporter = issue['user_profiles'];
    final equipment = issue['equipment'];
    final createdAt = DateTime.parse(issue['created_at']);
    final timeAgo = _getTimeAgo(createdAt);

    return Container(
      padding: const EdgeInsets.all(16), // 🔧 Same padding as original
      decoration: BoxDecoration(
        color: const Color(0xFFE6E8F0), // 🎨 Neumorphic background
        borderRadius: BorderRadius.circular(16), // 🎨 Rounded corners
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFBCC0D0),
            offset: Offset(6, 6),
            blurRadius: 12,
          ),
          BoxShadow(
            color: Colors.white,
            offset: Offset(-6, -6),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E8F0),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    // 🎨 Inner neumorphic effect for status badge
                    BoxShadow(
                      color: const Color(0xFFBCC0D0).withOpacity(0.7),
                      offset: const Offset(2, 2),
                      blurRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.9),
                      offset: const Offset(-2, -2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getStatusIcon(status), size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      _formatStatus(status),
                      style: GoogleFonts.poppins(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                timeAgo,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF2B326B).withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined, 
                size: 20, 
                color: const Color(0xFF2B326B).withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  equipment?['name'] ?? 'Unknown Equipment',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2B326B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (equipment?['brand'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 28),
                Flexible( // 🔧 Prevent overflow
                  child: Text(
                    '${equipment['brand']} • ${equipment['qr_code'] ?? 'N/A'}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF2B326B).withOpacity(0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE6E8F0),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                // 🎨 Inner neumorphic effect for description
                BoxShadow(
                  color: Color(0xFFBCC0D0),
                  offset: Offset(3, 3),
                  blurRadius: 6,
                ),
                BoxShadow(
                  color: Colors.white,
                  offset: Offset(-3, -3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.description_outlined, 
                  size: 18, 
                  color: const Color(0xFF2B326B).withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    issue['description'] ?? 'No description provided',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF2B326B).withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.person_outline, 
                size: 18, 
                color: const Color(0xFF2B326B).withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reported by: ${reporter?['first_name'] ?? ''} ${reporter?['last_name'] ?? ''}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF2B326B).withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis, // 🔧 Prevent overflow
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Email: ${reporter?['email'] ?? 'N/A'}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF2B326B).withOpacity(0.6),
                      ),
                      overflow: TextOverflow.ellipsis, // 🔧 Prevent overflow
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status != 'resolved')
                _buildNeumorphicButton(
                  onPressed: () => _showStatusDialog(issue),
                  icon: Icons.edit_outlined,
                  label: 'Update Status',
                  isOutlined: false,
                ),
              _buildNeumorphicButton(
                onPressed: () => _showIssueDetails(issue),
                icon: Icons.visibility_outlined,
                label: 'View Details',
                isOutlined: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNeumorphicButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isOutlined,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE6E8F0),
          borderRadius: BorderRadius.circular(8),
          border: isOutlined 
              ? Border.all(color: const Color(0xFF2B326B), width: 1)
              : null,
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFBCC0D0),
              offset: Offset(2, 2),
              blurRadius: 4,
            ),
            BoxShadow(
              color: Colors.white,
              offset: Offset(-2, -2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: const Color(0xFF2B326B),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: const Color(0xFF2B326B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusDialog(Map<String, dynamic> issue) {
    final currentStatus = issue['status'] ?? 'open';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFFE6E8F0), // 🎨 Neumorphic background
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE6E8F0),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFFBCC0D0),
                    offset: Offset(3, 3),
                    blurRadius: 6,
                  ),
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-3, -3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(
                Icons.sync_alt,
                color: Color(0xFF2B326B),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Update Status',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: const Color(0xFF2B326B),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select new status for this issue:',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF2B326B).withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            _buildStatusOption(issue, 'open', 'Open', currentStatus),
            const Divider(height: 1),
            _buildStatusOption(issue, 'in_progress', 'In Progress', currentStatus),
            const Divider(height: 1),
            _buildStatusOption(issue, 'resolved', 'Resolved', currentStatus),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: const Color(0xFF2B326B).withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(Map<String, dynamic> issue, String status, String label, String currentStatus) {
    final isCurrentStatus = currentStatus == status;
    final statusColor = _getStatusColor(status);

    return InkWell(
      onTap: isCurrentStatus ? null : () async {
        Navigator.pop(context);
        await _updateIssueStatus(issue['issue_id'], status);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isCurrentStatus ? const Color(0xFFE6E8F0) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE6E8F0),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFFBCC0D0),
                    offset: Offset(2, 2),
                    blurRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-2, -2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                _getStatusIcon(status),
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isCurrentStatus 
                          ? const Color(0xFF2B326B).withOpacity(0.5) 
                          : const Color(0xFF2B326B),
                    ),
                  ),
                  if (isCurrentStatus)
                    Text(
                      'Current status',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF2B326B).withOpacity(0.5),
                      ),
                    ),
                ],
              ),
            ),
            if (isCurrentStatus)
              Icon(Icons.check_circle, color: statusColor, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _updateIssueStatus(int issueId, String newStatus) async {
    try {
      await supabase.from('issues').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('issue_id', issueId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Issue status updated to ${_formatStatus(newStatus)}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadIssues();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showIssueDetails(Map<String, dynamic> issue) {
    final reporter = issue['user_profiles'];
    final equipment = issue['equipment'];
    final createdAt = DateTime.parse(issue['created_at']);
    final updatedAt = issue['updated_at'] != null
        ? DateTime.parse(issue['updated_at'])
        : null;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFFE6E8F0), // 🎨 Neumorphic background
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6E8F0),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFBCC0D0),
                            offset: Offset(3, 3),
                            blurRadius: 6,
                          ),
                          BoxShadow(
                            color: Colors.white,
                            offset: Offset(-3, -3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.report_problem_outlined, 
                        color: Colors.red, 
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Issue Details',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2B326B),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: Color(0xFF2B326B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow('Issue ID', '#${issue['issue_id']}'),
                _buildDetailRow('Status', _formatStatus(issue['status'])),
                _buildDetailRow('Equipment', equipment?['name'] ?? 'N/A'),
                _buildDetailRow('Brand', equipment?['brand'] ?? 'N/A'),
                _buildDetailRow('QR Code', equipment?['qr_code'] ?? 'N/A'),
                _buildDetailRow('Reporter', '${reporter?['first_name'] ?? ''} ${reporter?['last_name'] ?? ''}'),
                _buildDetailRow('Email', reporter?['email'] ?? 'N/A'),
                _buildDetailRow('Reported', _formatDateTime(createdAt)),
                if (updatedAt != null)
                  _buildDetailRow('Last Updated', _formatDateTime(updatedAt)),
                const SizedBox(height: 16),
                Text(
                  'Description:',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2B326B),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6E8F0),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFBCC0D0),
                        offset: Offset(3, 3),
                        blurRadius: 6,
                      ),
                      BoxShadow(
                        color: Colors.white,
                        offset: Offset(-3, -3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Text(
                    issue['description'] ?? 'No description provided',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF2B326B).withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2B326B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF2B326B).withOpacity(0.8),
              ),
              overflow: TextOverflow.ellipsis, // 🔧 Prevent overflow
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'open':
        return Icons.error_outline;
      case 'in_progress':
        return Icons.pending_outlined;
      case 'resolved':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _formatStatus(String status) {
    return status.split('_').map((word) =>
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}