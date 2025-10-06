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
    final pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
      });
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  Widget _buildImageSection() {
    final hasImage = _pickedImage != null || _existingImageUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Equipment Image',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        if (hasImage) ...[
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _pickedImage != null
                  ? Image.file(
                      _pickedImage!,
                      fit: BoxFit.cover,
                    )
                  : _existingImageUrl != null
                      ? Image.network(
                          _existingImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
            ),
          ),
        ] else ...[
          Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey[300]!,
                style: BorderStyle.solid,
              ),
              color: Colors.grey[50],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  color: Colors.grey[400],
                  size: 32,
                ),
                const SizedBox(height: 4),
                Text(
                  'No image selected',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isSmallScreen ? screenWidth * 0.95 : 500,
        height: screenHeight * 0.9,
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
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
                          fontSize: isSmallScreen ? 18 : 20,
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

            SizedBox(height: isSmallScreen ? 16 : 24),

            // Form wrapped in Expanded with SingleChildScrollView
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter equipment name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Brand and Model Row with responsive layout
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 400) {
                            // Stack vertically on small screens
                            return Column(
                              children: [
                                TextFormField(
                                  controller: _brandController,
                                  decoration: InputDecoration(
                                    labelText: 'Brand *',
                                    hintText: 'e.g., Apple',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    prefixIcon: const Icon(Icons.business),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter brand';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _modelController,
                                  decoration: InputDecoration(
                                    labelText: 'Model *',
                                    hintText: 'e.g., A2338',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    prefixIcon: const Icon(Icons.model_training),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter model';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            );
                          } else {
                            // Side by side on larger screens
                            return Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _brandController,
                                    decoration: InputDecoration(
                                      labelText: 'Brand *',
                                      hintText: 'e.g., Apple',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      prefixIcon: const Icon(Icons.business),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 16,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter brand';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _modelController,
                                    decoration: InputDecoration(
                                      labelText: 'Model *',
                                      hintText: 'e.g., A2338',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      prefixIcon: const Icon(Icons.model_training),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 16,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter model';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            );
                          }
                        }
                      ),

                      const SizedBox(height: 16),

                      // Category and Status Row with responsive layout
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 400) {
                            // Stack vertically on small screens
                            return Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  value: _selectedCategory,
                                  decoration: InputDecoration(
                                    labelText: 'Category *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    prefixIcon: const Icon(Icons.category),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 16,
                                    ),
                                  ),
                                  isExpanded: true,
                                  items: _categories.map((category) {
                                    return DropdownMenuItem(
                                      value: category,
                                      child: Text(
                                        category,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCategory = value!;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: _selectedStatus,
                                  decoration: InputDecoration(
                                    labelText: 'Status *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    prefixIcon: const Icon(Icons.info),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 16,
                                    ),
                                  ),
                                  isExpanded: true,
                                  items: _statuses.map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Text(
                                        status.toUpperCase(),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedStatus = value!;
                                    });
                                  },
                                ),
                              ],
                            );
                          } else {
                            // Side by side on larger screens
                            return Row(
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
                                        horizontal: 8,
                                        vertical: 16,
                                      ),
                                    ),
                                    isExpanded: true,
                                    items: _categories.map((category) {
                                      return DropdownMenuItem(
                                        value: category,
                                        child: Text(
                                          category,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedCategory = value!;
                                      });
                                    },
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
                                      prefixIcon: const Icon(Icons.info),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 16,
                                      ),
                                    ),
                                    isExpanded: true,
                                    items: _statuses.map((status) {
                                      return DropdownMenuItem(
                                        value: status,
                                        child: Text(
                                          status.toUpperCase(),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedStatus = value!;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            );
                          }
                        }
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Image Section
                      _buildImageSection(),

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
                                Flexible(
                                  child: Text(
                                    'Equipment Info',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue[700],
                                    ),
                                    overflow: TextOverflow.ellipsis,
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

            SizedBox(height: isSmallScreen ? 16 : 24),

            // 🔧 FIXED: Action buttons - Made them equal height
            Column(
              children: [
                // Main action buttons with equal height
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
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
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _updateEquipment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2B326B),
                            foregroundColor: Colors.white,
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
                              : Text(
                                  'Update',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12, // 🔧 FIXED: Smaller font for Update Equipment
                                  ),
                                  textAlign: TextAlign.center, // 🔧 FIXED: Center align text
                                ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Image action buttons with equal height
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Image Options',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _pickImage,
                                icon: const Icon(Icons.photo_library, size: 16), // 🔧 FIXED: Smaller icon
                                label: Flexible( // 🔧 FIXED: Wrap with Flexible to prevent overflow
                                  child: Text(
                                    (_pickedImage != null || _existingImageUrl != null)
                                        ? 'Change Image'
                                        : 'Pick Image',
                                    style: const TextStyle(fontSize: 8), // 🔧 FIXED: Smaller font
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1, // 🔧 FIXED: Ensure single line
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2B326B),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 8), // 🔧 FIXED: Reduce padding
                                ),
                              ),
                            ),
                          ),
                          if (_pickedImage != null || _existingImageUrl != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _removeImage,
                                  icon: const Icon(Icons.delete_forever, size: 16), // 🔧 FIXED: Smaller icon
                                  label: const Flexible( // 🔧 FIXED: Wrap with Flexible to prevent overflow
                                    child: Text(
                                      'Remove Image', // 🔧 FIXED: Full text instead of "Remov..."
                                      style: TextStyle(fontSize: 8), // 🔧 FIXED: Smaller font
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1, // 🔧 FIXED: Ensure single line
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 8), // 🔧 FIXED: Reduce padding
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }


  Future<void> _updateEquipment() async {
    if (!_formKey.currentState!.validate()) return;

    // FIXED CHANGE DETECTION: Check ALL fields
    final hasImageChange = _pickedImage != null ||
        (widget.equipment['image_url'] != null && _existingImageUrl == null) ||
        (widget.equipment['image_url'] == null && _existingImageUrl != null);

    // Get original specifications as string for comparison
    String originalSpecs = '';
    final specs = widget.equipment['specifications'];
    if (specs != null && specs is Map) {
      originalSpecs = specs.entries.map((e) => '${e.key}:${e.value}').join(', ');
    } else if (specs is String) {
      originalSpecs = specs;
    }

    // Get original category for comparison
    String originalCategory = '';
    final dynamic categoryData = widget.equipment['category'];
    if (categoryData is Map<String, dynamic>) {
      originalCategory = categoryData['name']?.toString() ?? '';
    } else {
      originalCategory = categoryData?.toString() ?? '';
    }

    // Get original status for comparison
    String originalStatus = '';
    final dynamic statusData = widget.equipment['status'];
    if (statusData is Map<String, dynamic>) {
      originalStatus = statusData['name']?.toString().toLowerCase() ?? '';
    } else {
      originalStatus = statusData?.toString().toLowerCase() ?? '';
    }

    final hasDataChange =
        _nameController.text.trim() != (widget.equipment['name'] ?? '') ||
        _brandController.text.trim() != (widget.equipment['brand'] ?? '') ||
        _modelController.text.trim() != (widget.equipment['model'] ?? '') ||
        _descriptionController.text.trim() != (widget.equipment['description'] ?? '') ||
        _specificationsController.text.trim() != originalSpecs ||
        _selectedCategory != originalCategory ||
        _selectedStatus != originalStatus;

    // Only show "No changes were made" if BOTH image and data haven't changed
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
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}