import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/equipment_management_service.dart';

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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias, // ✅ CHANGED: Helps contain child widgets
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ CHANGED: Replaced fixed-height SizedBox with a flexible AspectRatio
          AspectRatio(
            aspectRatio: 16 / 10, // Keeps image proportions consistent
            child: Container(
              color: Colors.grey[100],
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultIcon(category);
                      },
                    )
                  : _buildDefaultIcon(category),
            ),
          ),

          // ✅ CHANGED: Replaced fixed-height SizedBox with Expanded
          // This makes the content area fill the remaining space.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Status Badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 10),
                            const SizedBox(width: 4),
                            Text(
                              _getStatusText(status),
                              style: GoogleFonts.poppins(
                                color: statusColor,
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Brand
                  if (brand.isNotEmpty)
                    Text(
                      brand,
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // Category
                  Text(
                    category,
                    style: GoogleFonts.poppins(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // This Spacer pushes the buttons to the bottom
                  const Spacer(),

                  // Horizontal Action Buttons with Labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabeledButton(
                        'QR',
                        Icons.qr_code,
                        Colors.blue,
                        () => _showQRCode(context, equipmentId, name),
                      ),
                      _buildLabeledButton(
                        'Edit',
                        Icons.edit,
                        Colors.orange,
                        onEdit,
                      ),
                      _buildLabeledButton(
                        'More',
                        Icons.more_vert,
                        Colors.grey[600]!,
                        () => _showOptionsMenu(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Labeled button for better UX
  Widget _buildLabeledButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 10,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Image or Icon
                Container(
                  width: 80,
                  height: 80,
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
                              return _buildDefaultIcon(category);
                            },
                          ),
                        )
                      : _buildDefaultIcon(category),
                ),

                const SizedBox(width: 16),

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
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: statusColor, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  _getStatusText(status),
                                  style: GoogleFonts.poppins(
                                    color: statusColor,
                                    fontSize: 12,
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
                            fontSize: 14,
                          ),
                        ),

                      Text(
                        category,
                        style: GoogleFonts.poppins(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),

                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: GoogleFonts.poppins(
                            color: Colors.grey[700],
                            fontSize: 12,
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

            const SizedBox(height: 16),

            // ✅ Horizontal Action Buttons Row for List View
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildListActionButton(
                    'View QR Code',
                    Icons.qr_code,
                    Colors.blue,
                    () => _showQRCode(context, equipmentId, name),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildListActionButton(
                    'Edit',
                    Icons.edit,
                    Colors.orange,
                    onEdit,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildListActionButton(
                    'Options',
                    Icons.more_horiz,
                    Colors.grey[600]!,
                    () => _showOptionsMenu(context),
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
  ) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
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

  Widget _buildDefaultIcon(String category) {
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

    return Center(
      child: Icon(iconData, size: isListView ? 32 : 48, color: iconColor),
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
    final qrData = EquipmentManagementService.generateQRData(
      equipmentId,
      equipmentName,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                'QR Code - $equipmentName',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 200,
          height: 200,
          child: QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Print/Share functionality coming soon!'),
                ),
              );
            },
            child: const Text('Print'),
          ),
        ],
      ),
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

            // Status Change Options
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

            // Other Options
            _buildOptionItem(Icons.edit, 'Edit Equipment', Colors.blue, () {
              Navigator.pop(context);
              onEdit();
            }),
            _buildOptionItem(Icons.delete, 'Delete Equipment', Colors.red, () {
              Navigator.pop(context);
              onDelete();
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
