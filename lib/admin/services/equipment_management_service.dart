import 'dart:io'; // Required for File access (from image_picker)
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path; // Required for file path manipulation
import 'package:supabase_flutter/supabase_flutter.dart'; // Required for StorageException
import 'package:uuid/uuid.dart'; // Required for generating unique IDs for files

// Define helpers needed for the new functions
const Uuid _uuid = Uuid();
final supabase = Supabase.instance.client; // Ensure this matches your main.dart setup

class EquipmentManagementService {

  // --------------------------------------------------------------------------
  // 🎯 IMAGE MANAGEMENT (New Functions)
  // --------------------------------------------------------------------------

  /// Uploads a file to Supabase Storage ('equipment_images' bucket) and returns the public URL.
  static Future<String> uploadEquipmentImage({
    required File file,
    required int equipmentId,
  }) async {
    final fileExtension = path.extension(file.path);
    // Create a unique path using equipmentId and a UUID
    final imagePath = 'equipment_images/${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}/${equipmentId}_${_uuid.v4()}$fileExtension';

    try {
      await supabase.storage.from('equipment_images').upload(
            imagePath,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      // Get the public URL for the uploaded file
      final publicUrl = supabase.storage.from('equipment_images').getPublicUrl(imagePath);

      return publicUrl;

    } on StorageException catch (e) {
      throw Exception('Supabase Storage Error during upload: ${e.message}');
    } catch (e) {
      throw Exception('Image upload failed: $e');
    }
  }

  /// Deletes an image from Supabase Storage given its public URL.
  static Future<void> deleteEquipmentImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return;

    try {
        // Extract the path from the URL. We are looking for the path after the bucket name.
        final uri = Uri.parse(imageUrl);
        final segments = uri.pathSegments;
        final bucketIndex = segments.indexOf('equipment_images');

        if (bucketIndex == -1 || bucketIndex >= segments.length - 1) {
            return;
        }

        // The path to delete starts after the bucket name
        final pathToDelete = segments.sublist(bucketIndex + 1).join('/');

        if (pathToDelete.isEmpty) return;

        await supabase.storage.from('equipment_images').remove([pathToDelete]);

    } on StorageException catch (e) {
        // Safe to ignore "File not found" errors during deletion
        if (!e.message.contains('The resource was not found')) {
            print('Error deleting image: ${e.message}');
        }
    } catch (e) {
        print('General error during image deletion: $e');
    }
  }

  // --------------------------------------------------------------------------
  // USER'S EXISTING FUNCTIONS BELOW
  // --------------------------------------------------------------------------

    // Get all equipment with filtering options
    static Future<List<Map<String, dynamic>>> getAllEquipment({
        String? searchQuery,
        String? category,
        String? status,
    }) async {
        try {
            // Join with equipment_categories to get category name
            var query = supabase
                    .from('equipment')
                    .select('*, equipment_categories(category_name)');

            if (searchQuery != null && searchQuery.isNotEmpty) {
                query = query.or(
                    'name.ilike.%$searchQuery%,brand.ilike.%$searchQuery%,description.ilike.%$searchQuery%',
                );
            }

            if (category != null && category.isNotEmpty && category != 'all') {
                // Get category_id from category name
                final categoryData = await supabase
                        .from('equipment_categories')
                        .select('category_id')
                        .eq('category_name', category)
                        .maybeSingle();

                if (categoryData != null) {
                    query = query.eq('category_id', categoryData['category_id']);
                }
            }

            if (status != null && status.isNotEmpty && status != 'all') {
                query = query.eq('status', status);
            }

            final equipment = await query.order('created_at', ascending: false);

            // Transform the data to include category as a flat field for backward compatibility
            return equipment.map((item) {
                final transformed = Map<String, dynamic>.from(item);
                if (item['equipment_categories'] != null) {
                    transformed['category'] = item['equipment_categories']['category_name'];
                }
                transformed.remove('equipment_categories');
                return transformed;
            }).toList();
        } catch (e) {
            throw Exception('Failed to load equipment: $e');
        }
    }

    // Get equipment categories
    static Future<List<String>> getCategories() async {
        try {
            final result = await supabase
                    .from('equipment_categories')
                    .select('category_name')
                    .order('category_name');

            return result
                    .map<String>((item) => item['category_name'].toString())
                    .toList();
        } catch (e) {
            return [
                'Laptops',
                'Projectors',
                'Cables',
                'Audio Equipment',
                'Tablets',
            ]; // Default categories
        }
    }

       static Future<int?> _getCategoryId(String categoryName) async {
        try {
            final result = await supabase
                    .from('equipment_categories')
                    .select('category_id')
                    .eq('category_name', categoryName)
                    .maybeSingle();

            return result?['category_id'] as int?;
        } catch (e) {
            return null;
        }
    }
    static Map<String, dynamic>? _parseSpecifications(String? specsString) {
    if (specsString == null || specsString.trim().isEmpty) return null;

    final specs = <String, dynamic>{};
    final pairs = specsString.split(',');

    for (var pair in pairs) {
        final parts = pair.split(':');
        if (parts.length == 2) {
            final key = parts[0].trim();
            final value = parts[1].trim();
            if (key.isNotEmpty && value.isNotEmpty) {
                specs[key] = value;
            }
        }
    }

    return specs.isNotEmpty ? specs : null;
}
    // Add new equipment
static Future<String> addEquipment({
  required String name,
  required String brand,
  required String model,
  required String category,
  required String specifications,
  required String description,
  required String status,
  XFile? imageFile,
}) async {
  String? imageUrl;

  try {
    // Get category_id first
    final categoryId = await _getCategoryId(category);
    if (categoryId == null) {
      throw Exception('Invalid category: $category');
    }

    // Generate meaningful QR code
    final qrCode = await _generateMeaningfulQRCode(brand, category);

    // Parse specifications into proper JSON format
    final specsJson = _parseSpecifications(specifications);

    // Handle image upload if provided
    if (imageFile != null) {
      final String fileExtension = imageFile.name.split('.').last;
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final String storagePath = 'equipment_images/$fileName';

      final bytes = await imageFile.readAsBytes();
      await supabase.storage.from('equipment_images').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/${fileExtension.toLowerCase()}',
              cacheControl: '3600',
            ),
          );

      imageUrl = supabase.storage
          .from('equipment_images')
          .getPublicUrl(storagePath);
    }

    // Prepare data for database insertion
    final Map<String, dynamic> equipmentData = {
      'name': name,
      'brand': brand,
      'model': model,
      'category_id': categoryId,
      'qr_code': qrCode,  // Add the generated QR code
      'specifications': specsJson,
      'description': description,
      'status': status,
      'image_url': imageUrl,
      'created_at': DateTime.now().toIso8601String(),
    };

    // Insert the new equipment record into the database
    final response = await supabase
        .from('equipment')
        .insert(equipmentData)
        .select('equipment_id');

    if (response.isEmpty) {
      throw Exception('Failed to create equipment record');
    }

    final equipmentId = response.first['equipment_id'].toString();
    return equipmentId;
  } catch (e) {
    print('Error in addEquipment: $e');
    rethrow;
  }
}

// Helper method to generate meaningful QR code
   static Future<String> _generateMeaningfulQRCode(String brand, String category) async {
        // Get brand prefix (uppercase, letters only)
        String brandPrefix = brand.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
        if (brandPrefix.length > 6) {
            brandPrefix = brandPrefix.substring(0, 6);
        } else if (brandPrefix.isEmpty) {
            brandPrefix = 'BRAND';
        }

        // Get category abbreviation
        String categoryPrefix = _getCategoryAbbreviation(category);

        // Find next available number for this brand-category combination
        String baseQrCode = '$brandPrefix-$categoryPrefix';
        int counter = await _getNextQRNumber(baseQrCode);

        return '$baseQrCode-${counter.toString().padLeft(3, '0')}';
    }

// Helper method to get next available number
static Future<int> _getNextQRNumber(String baseQrCode) async {
        try {
            // Get all QR codes that start with this base
            final result = await supabase
                    .from('equipment')
                    .select('qr_code')
                    .like('qr_code', '$baseQrCode-%');

            if (result.isEmpty) {
                return 1; // First equipment with this combination
            }

            // Extract numbers and find the highest
            int maxNumber = 0;
            for (var item in result) {
                String qrCode = item['qr_code'] as String;
                // Extract number after last dash
                List<String> parts = qrCode.split('-');
                if (parts.length >= 3) {
                    int? number = int.tryParse(parts.last);
                    if (number != null && number > maxNumber) {
                        maxNumber = number;
                    }
                }
            }

            return maxNumber + 1; // Next available number
        } catch (e) {
            return 1; // Default to 1 if error
        }
    }

   static String _getCategoryAbbreviation(String category) {
        switch (category.toLowerCase()) {
            case 'laptops':
                return 'LAP';
            case 'projectors':
                return 'PROJ';
            case 'cables':
            case 'hdmi cables':
                return 'CBL';
            case 'audio equipment':
            case 'audio':
                return 'AUD';
            case 'tablets':
                return 'TAB';
            case 'monitors':
                return 'MON';
            case 'keyboards':
                return 'KBD';
            case 'mice':
            case 'mouse':
                return 'MSE';
            default:
                String abbr = category.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
                return abbr.length > 4 ? abbr.substring(0, 4) : (abbr.isEmpty ? 'ITEM' : abbr);
        }
    }

    // Update equipment
    static Future<void> updateEquipment({
    required int equipmentId,
    required String name,
    required String brand,
    required String model,
    required String category,
    String? specifications,
    required String description,
    required String status,
    String? imageUrl,
}) async {
    try {
        final categoryId = await _getCategoryId(category);
        if (categoryId == null) {
            throw Exception('Invalid category: $category');
        }

        // Parse specifications into proper JSON format
        final specsJson = _parseSpecifications(specifications);

        await supabase
                .from('equipment')
                .update({
                    'name': name,
                    'brand': brand,
                    'model': model,
                    'category_id': categoryId,
                    'specifications': specsJson,
                    'description': description,
                    'status': status,
                    'image_url': imageUrl, // **This handles the image URL from the dialog**
                    'updated_at': DateTime.now().toIso8601String(), // Add update timestamp
                })
                .eq('equipment_id', equipmentId);
    } catch (e) {
        throw Exception('Failed to update equipment: $e');
    }
}

    // Delete equipment (with safety check)
    static Future<void> deleteEquipment(int equipmentId) async {
        try {
            // Check if equipment is currently borrowed
            final activeRequests = await supabase
                    .from('borrow_requests')
                    .select('request_id')
                    .eq('equipment_id', equipmentId)
                    .inFilter('status', ['pending', 'approved', 'active']);

            if (activeRequests.isNotEmpty) {
                throw Exception(
                    'Cannot delete equipment that has active borrow requests',
                );
            }

            // Delete the equipment
            await supabase.from('equipment').delete().eq('equipment_id', equipmentId);
        } catch (e) {
            throw Exception('Failed to delete equipment: $e');
        }
    }

    // Update equipment status
    static Future<void> updateEquipmentStatus(
        int equipmentId,
        String newStatus,
    ) async {
        try {
            await supabase
                    .from('equipment')
                    .update({'status': newStatus})
                    .eq('equipment_id', equipmentId);
        } catch (e) {
            throw Exception('Failed to update equipment status: $e');
        }
    }

    // Generate QR code data for equipment
    static String generateQRData(int equipmentId, String equipmentName) {
        return 'EQUIPMENT:$equipmentId:$equipmentName';
    }

    // Get equipment statistics
    static Future<Map<String, int>> getEquipmentStats() async {
        try {
            final allEquipment = await supabase.from('equipment').select('status');

            final stats = <String, int>{
                'total': allEquipment.length,
                'available': 0,
                'borrowed': 0,
                'maintenance': 0,
                'retired': 0,
            };

            for (final equipment in allEquipment) {
                final status = equipment['status'] ?? 'available';
                stats[status] = (stats[status] ?? 0) + 1;
            }

            return stats;
        } catch (e) {
            return {
                'total': 0,
                'available': 0,
                'borrowed': 0,
                'maintenance': 0,
                'retired': 0,
            };
        }
    }
}