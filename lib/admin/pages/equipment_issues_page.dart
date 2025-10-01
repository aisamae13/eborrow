import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';

class EquipmentIssuesPage extends StatefulWidget {
  final int equipmentId;
  final String equipmentName;

  const EquipmentIssuesPage({
    super.key,
    required this.equipmentId,
    required this.equipmentName,
  });

  @override
  State<EquipmentIssuesPage> createState() => _EquipmentIssuesPageState();
}

class _EquipmentIssuesPageState extends State<EquipmentIssuesPage> {
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
      var query = supabase
          .from('issues')
          .select('''
            *,
            user_profiles!reporter_id(first_name, last_name, email),
            equipment(name, brand, qr_code)
          ''')
          .eq('equipment_id', widget.equipmentId); // Fix: Filter by equipment ID

      if (_selectedFilter != 'all') {
        query = query.eq('status', _selectedFilter);
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Issues',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              widget.equipmentName,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2B326B),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadIssues(),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _issuesFuture,
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
                          Text(
                            'Error loading issues',
                            style: GoogleFonts.poppins(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _loadIssues,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final issues = snapshot.data ?? [];

                  if (issues.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No issues found',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedFilter == 'all'
                                ? 'This equipment has no reported issues'
                                : 'No ${_selectedFilter} issues',
                            style: GoogleFonts.poppins(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: issues.length,
                    itemBuilder: (context, index) {
                      return _buildIssueCard(issues[index]);
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
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Text(
            'Filter:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
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
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
        _loadIssues();
      },
      backgroundColor: Colors.grey[100],
      selectedColor: const Color(0xFF2B326B).withOpacity(0.2),
      checkmarkColor: const Color(0xFF2B326B),
      labelStyle: GoogleFonts.poppins(
        color: isSelected ? const Color(0xFF2B326B) : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
    );
  }

  Widget _buildIssueCard(Map<String, dynamic> issue) {
    final status = issue['status'] ?? 'open';
    final statusColor = _getStatusColor(status);
    final reporter = issue['user_profiles'];
    final createdAt = DateTime.parse(issue['created_at']);
    final timeAgo = _getTimeAgo(createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
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
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.description_outlined, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      issue['description'] ?? 'No description provided',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[800],
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
                Icon(Icons.person_outline, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reported by: ${reporter?['first_name'] ?? ''} ${reporter?['last_name'] ?? ''}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Email: ${reporter?['email'] ?? 'N/A'}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
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
                  TextButton.icon(
                    onPressed: () => _showStatusDialog(issue),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Update Status'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2B326B),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _showIssueDetails(issue),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2B326B),
                    side: const BorderSide(color: Color(0xFF2B326B)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2B326B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
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
                color: Colors.grey[600],
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
              style: GoogleFonts.poppins(color: Colors.grey[600]),
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
        color: isCurrentStatus ? Colors.grey[50] : null,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
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
                      color: isCurrentStatus ? Colors.grey[500] : Colors.grey[800],
                    ),
                  ),
                  if (isCurrentStatus)
                    Text(
                      'Current status',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[500],
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
    final createdAt = DateTime.parse(issue['created_at']);
    final updatedAt = issue['updated_at'] != null
        ? DateTime.parse(issue['updated_at'])
        : null;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    Icon(Icons.report_problem_outlined, color: Colors.red, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Issue Details',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow('Issue ID', '#${issue['issue_id']}'),
                _buildDetailRow('Status', _formatStatus(issue['status'])),
                _buildDetailRow('Equipment', widget.equipmentName),
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
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    issue['description'] ?? 'No description provided',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[800],
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
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[800],
              ),
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