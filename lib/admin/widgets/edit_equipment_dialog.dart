import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/equipment_management_service.dart';


class EditEquipmentDialog extends StatefulWidget {
  final Map<String, dynamic> equipment;
  final VoidCallback onEquipmentUpdated;

  const EditEquipmentDialog({
    super.key,
    required this.equipment,
    required this.onEquipmentUpdated,
  });

  @override
  State<EditEquipmentDialog> createState() => _EditEquipmentDialogState();
}

class _EditEquipmentDialogState extends State<EditEquipmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _specificationsController = TextEditingController();
  final _descriptionController = TextEditingController();

  // IMAGE PICKER STATE
  File? _pickedImage;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  late String _selectedCategory;
  late String _selectedStatus;
  bool _isLoading = false;

  final List<String> _categories = [
    'Laptops',
    'Projectors',
    'Cables',
    'Audio Equipment',
    'Tablets',
    'Monitors',
    'Keyboards',
    'Mice',
    'Other',
  ];

  final List<String> _statuses = [
    'available',
    'borrowed',
    'maintenance',
    'retired',
  ];

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    _nameController.text = widget.equipment['name'] ?? '';
    _brandController.text = widget.equipment['brand'] ?? '';
    _modelController.text = widget.equipment['model'] ?? '';

    final specs = widget.equipment['specifications'];
    if (specs != null && specs is Map) {
      _specificationsController.text = specs.entries
          .map((e) => '${e.key}:${e.value}')
          .join(', ');
    } else if (specs is String) {
      _specificationsController.text = specs;
    }

    _descriptionController.text = widget.equipment['description'] ?? '';

    // INITIALIZE IMAGE URL
    _existingImageUrl = widget.equipment['image_url'];

    final dynamic categoryData = widget.equipment['category'];
    if (categoryData is Map<String, dynamic>) {
      _selectedCategory = categoryData['name']?.toString() ?? _categories.first;
    } else {
      _selectedCategory = categoryData?.toString() ?? _categories.first;
    }

    final dynamic statusData = widget.equipment['status'];
    if (statusData is Map<String, dynamic>) {
      _selectedStatus = statusData['name']?.toString().toLowerCase() ?? _statuses.first;
    } else {
      _selectedStatus = statusData?.toString().toLowerCase() ?? _statuses.first;
    }

    if (!_categories.contains(_selectedCategory)) {
      if (_selectedCategory.isNotEmpty) {
        _categories.add(_selectedCategory);
      }
    }

    if (!_statuses.contains(_selectedStatus)) {
        _selectedStatus = _statuses.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _specificationsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
  try {
    // Show source selection dialog
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select Image Source',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Choose where to get the equipment image from:',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
          ),
        ],
      ),
    );

    if (source == null) return;

    // Pick the image
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
        _existingImageUrl = null; // Clear existing URL if new image is picked
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image selected: ${image.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  } on PlatformException catch (e) {
    print('Platform Exception: ${e.code} - ${e.message}');

    if (mounted) {
      String errorMessage = 'Failed to pick image';

      if (e.code == 'channel-error') {
        errorMessage = 'Connection error. Please restart the app and try again.';
      } else if (e.code == 'photo_access_denied') {
        errorMessage = 'Photo access denied. Please enable permissions in Settings.';
      } else if (e.code == 'camera_access_denied') {
        errorMessage = 'Camera access denied. Please enable permissions in Settings.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: e.code.contains('denied')
            ? SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () {
                  // Open app settings (requires permission_handler package)
                  // AppSettings.openAppSettings();
                },
              )
            : null,
        ),
      );
    }
  } catch (e) {
    print('Error picking image: $e');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  void _removeImage() {
    setState(() {
      _pickedImage = null; // Remove the currently picked file
      _existingImageUrl = null; // Mark the existing URL for deletion from DB
    });
  }


  @override
  Widget build(BuildContext context) {
    final equipmentId = widget.equipment['equipment_id'] ?? 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.edit, color: const Color(0xFF2B326B), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Equipment',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2B326B),
                        ),
                      ),
                      Text(
                        'ID: $equipmentId',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Equipment Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Equipment Name *',
                          hintText: 'e.g., MacBook Pro 13"',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.inventory_2),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Equipment name is required';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _brandController,
                        decoration: InputDecoration(
                          labelText: 'Brand *',
                          hintText: 'e.g., Apple, Dell, HP',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.business),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Brand is required';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _modelController,
                        decoration: InputDecoration(
                          labelText: 'Model',
                          hintText: 'e.g., MacBook Pro 13", Latitude 5520',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.computer),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Category and Status Row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: InputDecoration(
                                labelText: 'Category *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: const Icon(Icons.category),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                isDense: true,
                              ),
                              // 🎯 FIX: Missing 'items' added here
                              items: _categories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(
                                    category,
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value!;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Category is required';
                                }
                                return null;
                              },
                              isExpanded: true,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedStatus,
                              decoration: InputDecoration(
                                labelText: 'Status *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: Icon(
                                  _getStatusIcon(_selectedStatus),
                                  color: _getStatusColor(_selectedStatus),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                isDense: true,
                              ),
                              // 🎯 FIX: Missing 'items' added here
                              items: _statuses.map((status) {
                                return DropdownMenuItem(
                                  value: status,
                                  child: Text(
                                    status[0].toUpperCase() +
                                        status.substring(1),
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedStatus = value!;
                                });
                              },
                              isExpanded: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _specificationsController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Specifications',
                          hintText: 'e.g., RAM:16GB, Storage:512GB SSD, Processor:Intel i7',
                          helperText: 'Use format - Key:Value, Key:Value',
                          helperMaxLines: 2,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.settings),
                          alignLabelWithHint: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          hintText:
                              'Add any additional details about this equipment...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.description),
                          alignLabelWithHint: true,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // IMAGE PICKER AND PREVIEW
                      _buildImageSection(),

                      const SizedBox(height: 24),

                      // Status Warning (if borrowed)
                      if (_selectedStatus == 'borrowed')
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning,
                                color: Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This equipment is currently borrowed. Changing the status will not affect active borrow requests.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // History/Info Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Equipment Info',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              'Equipment ID:',
                              equipmentId.toString(),
                            ),
                            _buildInfoRow(
                              'Created:',
                              _formatDate(widget.equipment['created_at']),
                            ),
                            if (widget.equipment['updated_at'] != null)
                              _buildInfoRow(
                                'Last Updated:',
                                _formatDate(widget.equipment['updated_at']),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateEquipment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2B326B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Save',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    Widget imageWidget;
    IconData icon;
    String label;
    bool hasImage = _pickedImage != null || _existingImageUrl != null;

    if (_pickedImage != null) {
      imageWidget = Image.file(_pickedImage!, fit: BoxFit.cover);
      icon = Icons.file_present;
      label = 'New Image Selected';
    } else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      imageWidget = Image.network(
        _existingImageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 40, color: Colors.red),
      );
      icon = Icons.link;
      label = 'Existing Image';
    } else {
      imageWidget = const Icon(Icons.image_not_supported, size: 40, color: Colors.grey);
      icon = Icons.add_a_photo;
      label = 'No Image';
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: hasImage ? Colors.blue : Colors.grey),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: const Color(0xFF2B326B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Image Preview Area
          Center(
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasImage
                  ? imageWidget
                  : Center(
                      child: Text(
                        'Image Preview',
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _pickImage,
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: Text(hasImage ? 'Change Image' : 'Pick Image'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: const Color(0xFF2B326B),
                  ),
                ),
              ),

              if (hasImage) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _removeImage,
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text('Remove Image'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }


  Future<void> _updateEquipment() async {
    if (!_formKey.currentState!.validate()) return;

    final hasImageChange = _pickedImage != null || (widget.equipment['image_url'] != null && _existingImageUrl == null) || (widget.equipment['image_url'] == null && _existingImageUrl != null);

    final hasDataChange =
        _nameController.text.trim() != (widget.equipment['name'] ?? '') ||
        _brandController.text.trim() != (widget.equipment['brand'] ?? '') ||
        _modelController.text.trim() != (widget.equipment['model'] ?? '') ||
        _descriptionController.text.trim() != (widget.equipment['description'] ?? '');

    if (!hasDataChange && !hasImageChange) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No changes were made'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Handle Image Upload/Deletion
      String? finalImageUrl = _existingImageUrl;

      if (_pickedImage != null) {
        // Upload new image and get the URL
        finalImageUrl = await EquipmentManagementService.uploadEquipmentImage(
          file: _pickedImage!,
          equipmentId: widget.equipment['equipment_id'],
        );
      } else if (_existingImageUrl == null && widget.equipment['image_url'] != null) {
        // Existing URL was cleared, delete old file from storage
        await EquipmentManagementService.deleteEquipmentImage(
            widget.equipment['image_url']);
        finalImageUrl = null;
      }

      // 2. Update Database Record
      await EquipmentManagementService.updateEquipment(
        equipmentId: widget.equipment['equipment_id'],
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        category: _selectedCategory,
        specifications: _specificationsController.text.trim(),
        description: _descriptionController.text.trim(),
        status: _selectedStatus,
        // Pass the newly uploaded URL or null
        imageUrl: finalImageUrl,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Equipment updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onEquipmentUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating equipment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue[600]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';

    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'N/A';
    }
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
}