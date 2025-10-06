import 'package:eborrow/admin/services/equipment_management_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../pages/equipment_issues_page.dart';

class EquipmentCard extends StatelessWidget {
  final Map<String, dynamic> equipment;
  final bool isListView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(String) onStatusChange;
  final VoidCallback onRefresh;

  const EquipmentCard({
    super.key,
    required this.equipment,
    this.isListView = false,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final name = equipment['name'] ?? 'Unknown Equipment';
    final brand = equipment['brand'] ?? '';
    final category = equipment['category'] ?? '';
    final status = equipment['status'] ?? 'available';
    final description = equipment['description'] ?? '';
    final equipmentId = equipment['equipment_id'] ?? 0;
    final imageUrl = equipment['image_url'];

    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    if (isListView) {
      return _buildListCard(
        context,
        name,
        brand,
        category,
        status,
        description,
        equipmentId,
        imageUrl,
        statusColor,
        statusIcon,
      );
    } else {
      return _buildGridCard(
        context,
        name,
        brand,
        category,
        status,
        description,
        equipmentId,
        imageUrl,
        statusColor,
        statusIcon,
      );
    }
  }
  Future<void> _deleteEquipment(BuildContext context) async {
  final equipmentId = equipment['equipment_id'];
  final equipmentName = equipment['name'] ?? 'this equipment';

  // Show confirmation dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Delete Equipment',
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
            'Are you sure you want to delete this equipment?',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory_2, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    equipmentName,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '⚠️ This action cannot be undone.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.red[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Delete',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  // Show loading indicator
  if (context.mounted) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Deleting equipment...',
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  try {
    // Delete from Supabase
    await supabase
        .from('equipment')
        .delete()
        .eq('equipment_id', equipmentId);

    if (context.mounted) {
      Navigator.pop(context); // Close loading dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Equipment deleted successfully',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // Refresh the list
      onRefresh();
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context); // Close loading dialog

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Failed to delete equipment: ${e.toString()}',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
Future<int> _getIssueCount(int equipmentId) async {
  try {
    final response = await supabase
        .from('issues')
        .select('issue_id')
        .eq('equipment_id', equipmentId)
        .neq('status', 'resolved'); // Only count unresolved issues

    return response.length;
  } catch (e) {
    return 0;
  }
}
  Widget _buildGridCard(
    BuildContext context,
    String name,
    String brand,
    String category,
    String status,
    String description,
    int equipmentId,
    String? imageUrl,
    Color statusColor,
    IconData statusIcon,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 1024;

    // Responsive font sizes
    final nameFontSize = isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0);
    final brandFontSize = isSmallScreen ? 10.0 : (isMediumScreen ? 11.0 : 12.0);
    final categoryFontSize = isSmallScreen ? 9.0 : 10.0;
    final statusFontSize = isSmallScreen ? 7.0 : 8.0;
    final buttonLabelSize = isSmallScreen ? 9.0 : 10.0;
    final iconSize = isSmallScreen ? 14.0 : 16.0;
    final statusIconSize = isSmallScreen ? 9.0 : 10.0;

    // Responsive padding
    final cardPadding = isSmallScreen ? 6.0 : 8.0;
    final buttonPadding = isSmallScreen ? 4.0 : 6.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              color: Colors.grey[100],
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultIcon(category, screenWidth);
                      },
                    )
                  : _buildDefaultIcon(category, screenWidth),
            ),
          ),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Name and Status Badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: nameFontSize,
                                    height: 1.2,
                                  ),
                                  maxLines: isSmallScreen ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: isSmallScreen ? 4 : 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 4 : 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(statusIcon, color: statusColor, size: statusIconSize),
                                    SizedBox(width: isSmallScreen ? 2 : 4),
                                    Text(
                                      _getStatusText(status),
                                      style: GoogleFonts.poppins(
                                        color: statusColor,
                                        fontSize: statusFontSize,
                                        fontWeight: FontWeight.w500,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: isSmallScreen ? 2 : 4),

                          // Brand
                          if (brand.isNotEmpty)
                            Text(
                              brand,
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontSize: brandFontSize,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                          // Category
                          Text(
                            category,
                            style: GoogleFonts.poppins(
                              color: Colors.grey[500],
                              fontSize: categoryFontSize,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          SizedBox(height: isSmallScreen ? 4 : 8),

                          // Horizontal Action Buttons with Labels
                          Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLabeledButton(
                              'QR',
                              Icons.qr_code,
                              Colors.blue,
                              () => _showQRCode(context, equipmentId, name),
                              buttonPadding,
                              iconSize,
                              buttonLabelSize,
                            ),
                            // ADD ISSUES BUTTON HERE
                            FutureBuilder<int>(
                              future: _getIssueCount(equipmentId),
                              builder: (context, snapshot) {
                                final issueCount = snapshot.data ?? 0;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _buildLabeledButton(
                                      'Issues',
                                      Icons.report_problem_outlined,
                                      issueCount > 0 ? Colors.red : Colors.grey,
                                      () => _navigateToEquipmentIssues(context, equipmentId, name),
                                      buttonPadding,
                                      iconSize,
                                      buttonLabelSize,
                                    ),
                                    if (issueCount > 0)
                                      Positioned(
                                        right: -4,
                                        top: -4,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          child: Text(
                                            '$issueCount',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            _buildLabeledButton(
                              'Edit',
                              Icons.edit,
                              Colors.orange,
                              onEdit,
                              buttonPadding,
                              iconSize,
                              buttonLabelSize,
                            ),
                            _buildLabeledButton(
                              'More',
                              Icons.more_vert,
                              Colors.grey[600]!,
                              () => _showOptionsMenu(context),
                              buttonPadding,
                              iconSize,
                              buttonLabelSize,
                            ),
                          ],
                        ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
void _navigateToEquipmentIssues(BuildContext context, int equipmentId, String equipmentName) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EquipmentIssuesPage(
        equipmentId: equipmentId,
        equipmentName: equipmentName,
      ),
    ),
  );
}
  Widget _buildLabeledButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    double padding,
    double iconSize,
    double labelSize,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: iconSize),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: labelSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(
    BuildContext context,
    String name,
    String brand,
    String category,
    String status,
    String description,
    int equipmentId,
    String? imageUrl,
    Color statusColor,
    IconData statusIcon,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 1024;

    // Responsive sizes for list view
    final imageSize = isSmallScreen ? 60.0 : (isMediumScreen ? 70.0 : 80.0);
    final nameFontSize = isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0);
    final brandFontSize = isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0);
    final categoryFontSize = isSmallScreen ? 10.0 : (isMediumScreen ? 11.0 : 12.0);
    final descriptionFontSize = isSmallScreen ? 11.0 : 12.0;
    final statusFontSize = isSmallScreen ? 10.0 : 12.0;
    final statusIconSize = isSmallScreen ? 12.0 : 14.0;
    final buttonFontSize = isSmallScreen ? 11.0 : 12.0;
    final buttonIconSize = isSmallScreen ? 14.0 : 16.0;
    final cardPadding = isSmallScreen ? 12.0 : 16.0;
    final spacing = isSmallScreen ? 12.0 : 16.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          children: [
            Row(
              children: [
                // Image or Icon
                Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildDefaultIcon(category, screenWidth);
                            },
                          ),
                        )
                      : _buildDefaultIcon(category, screenWidth),
                ),

                SizedBox(width: spacing),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: nameFontSize,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 4 : 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 6 : 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: statusColor, size: statusIconSize),
                                const SizedBox(width: 4),
                                Text(
                                  _getStatusText(status),
                                  style: GoogleFonts.poppins(
                                    color: statusColor,
                                    fontSize: statusFontSize,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      if (brand.isNotEmpty)
                        Text(
                          brand,
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: brandFontSize,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                      Text(
                        category,
                        style: GoogleFonts.poppins(
                          color: Colors.grey[500],
                          fontSize: categoryFontSize,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (description.isNotEmpty && !isSmallScreen) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: GoogleFonts.poppins(
                            color: Colors.grey[700],
                            fontSize: descriptionFontSize,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: spacing),

            // Action Buttons Row - Responsive layout
            isSmallScreen
                ? Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildListActionButton(
                              'QR Code',
                              Icons.qr_code,
                              Colors.blue,
                              () => _showQRCode(context, equipmentId, name),
                              buttonFontSize,
                              buttonIconSize,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildListActionButton(
                              'Edit',
                              Icons.edit,
                              Colors.orange,
                              onEdit,
                              buttonFontSize,
                              buttonIconSize,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: _buildListActionButton(
                          'Options',
                          Icons.more_horiz,
                          Colors.grey[600]!,
                          () => _showOptionsMenu(context),
                          buttonFontSize,
                          buttonIconSize,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _buildListActionButton(
                          'View QR Code',
                          Icons.qr_code,
                          Colors.blue,
                          () => _showQRCode(context, equipmentId, name),
                          buttonFontSize,
                          buttonIconSize,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildListActionButton(
                          'Edit',
                          Icons.edit,
                          Colors.orange,
                          onEdit,
                          buttonFontSize,
                          buttonIconSize,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildListActionButton(
                          'Options',
                          Icons.more_horiz,
                          Colors.grey[600]!,
                          () => _showOptionsMenu(context),
                          buttonFontSize,
                          buttonIconSize,
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildListActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    double fontSize,
    double iconSize,
  ) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize, color: color),
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        side: BorderSide(color: color.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildDefaultIcon(String category, double screenWidth) {
    IconData iconData;
    Color iconColor;

    switch (category.toLowerCase()) {
      case 'laptops':
        iconData = Icons.laptop_mac;
        iconColor = Colors.blue;
        break;
      case 'projectors':
        iconData = Icons.video_camera_front;
        iconColor = Colors.purple;
        break;
      case 'cables':
        iconData = Icons.cable;
        iconColor = Colors.orange;
        break;
      case 'tablets':
        iconData = Icons.tablet_mac;
        iconColor = Colors.green;
        break;
      case 'audio equipment':
        iconData = Icons.headset;
        iconColor = Colors.red;
        break;
      default:
        iconData = Icons.inventory_2;
        iconColor = Colors.grey;
    }

    // Responsive icon size based on screen width
    final iconSize = isListView
        ? (screenWidth < 600 ? 28.0 : 32.0)
        : (screenWidth < 600 ? 40.0 : 48.0);

    return Center(
      child: Icon(iconData, size: iconSize, color: iconColor),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'borrowed':
        return Colors.orange;
      case 'maintenance':
        return Colors.red;
      case 'retired':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Icons.check_circle;
      case 'borrowed':
        return Icons.schedule;
      case 'maintenance':
        return Icons.build;
      case 'retired':
        return Icons.archive;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    return status[0].toUpperCase() + status.substring(1);
  }

  void _showQRCode(
  BuildContext context,
  int equipmentId,
  String equipmentName,
) {
  // ✅ FIX: Use the actual QR code from the database
  final qrCode = equipment['qr_code'] ?? 'UNKNOWN-${equipmentId.toString().padLeft(3, '0')}';

  final screenWidth = MediaQuery.of(context).size.width;
  final isSmallScreen = screenWidth < 600;
  final dialogWidth = isSmallScreen ? screenWidth * 0.9 : 400.0;
  final qrSize = isSmallScreen ? 200.0 : 240.0;

  showDialog(
  context: context,
  builder: (context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Container(
      width: dialogWidth,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85, // Add max height
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView( // ✅ Add scroll capability
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2B326B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.qr_code_2,
                color: Color(0xFF2B326B),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Equipment QR Code',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2B326B),
              ),
            ),
            const SizedBox(height: 8),

            // QR Code Number
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFC107)),
              ),
              child: Text(
                qrCode,
                style: GoogleFonts.robotoMono(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2B326B),
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // QR Code with styled container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrCode,
                version: QrVersions.auto,
                size: qrSize,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
                gapless: true,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF2B326B),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF2B326B),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Equipment Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Name:', equipmentName),
                  const SizedBox(height: 8),
                  _buildInfoRow('Brand:', equipment['brand'] ?? 'N/A'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Category:', equipment['category'] ?? 'N/A'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B326B),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
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

// Helper method for info rows
Widget _buildInfoRow(String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          textAlign: TextAlign.end,
        ),
      ),
    ],
  );
}

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Equipment Options',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _buildOptionItem(
              Icons.check_circle,
              'Mark as Available',
              Colors.green,
              () {
                Navigator.pop(context);
                onStatusChange('available');
              },
            ),
            _buildOptionItem(
              Icons.build,
              'Mark for Maintenance',
              Colors.red,
              () {
                Navigator.pop(context);
                onStatusChange('maintenance');
              },
            ),
            _buildOptionItem(Icons.archive, 'Mark as Retired', Colors.grey, () {
              Navigator.pop(context);
              onStatusChange('retired');
            }),

            const Divider(),

            _buildOptionItem(Icons.edit, 'Edit Equipment', Colors.blue, () {
              Navigator.pop(context);
              onEdit();
            }),
            _buildOptionItem(Icons.delete, 'Delete Equipment', Colors.red, () {
              Navigator.pop(context);
              _deleteEquipment(context);
            }),
          ],
        ),
      ),
    );
  }
  Widget _buildOptionItem(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }
}