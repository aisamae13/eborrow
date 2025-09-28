import '../../main.dart';
import 'dart:typed_data';

class EquipmentManagementService {
  // Get all equipment with filtering options
  static Future<List<Map<String, dynamic>>> getAllEquipment({
    String? searchQuery,
    String? category,
    String? status,
  }) async {
    try {
      var query = supabase.from('equipment').select('*');

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'name.ilike.%$searchQuery%,brand.ilike.%$searchQuery%,description.ilike.%$searchQuery%',
        );
      }

      if (category != null && category.isNotEmpty && category != 'all') {
        query = query.eq('category', category);
      }

      if (status != null && status.isNotEmpty && status != 'all') {
        query = query.eq('status', status);
      }

      final equipment = await query.order('created_at', ascending: false);
      return equipment;
    } catch (e) {
      throw Exception('Failed to load equipment: $e');
    }
  }

  // Get equipment categories
  static Future<List<String>> getCategories() async {
    try {
      final result = await supabase
          .from('equipment')
          .select('category')
          .not('category', 'is', null);

      final categories = result
          .map<String>((item) => item['category'].toString())
          .toSet()
          .toList();

      categories.sort();
      return categories;
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

  // Add new equipment
  static Future<int> addEquipment({
    required String name,
    required String brand,
    required String category,
    required String description,
    String status = 'available',
    String? imageUrl,
  }) async {
    try {
      final result = await supabase
          .from('equipment')
          .insert({
            'name': name,
            'brand': brand,
            'category': category,
            'description': description,
            'status': status,
            'image_url': imageUrl,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('equipment_id')
          .single();

      return result['equipment_id'];
    } catch (e) {
      throw Exception('Failed to add equipment: $e');
    }
  }

  // Update equipment
  static Future<void> updateEquipment({
    required int equipmentId,
    required String name,
    required String brand,
    required String category,
    required String description,
    required String status,
    String? imageUrl,
  }) async {
    try {
      await supabase
          .from('equipment')
          .update({
            'name': name,
            'brand': brand,
            'category': category,
            'description': description,
            'status': status,
            'image_url': imageUrl,
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
          .inFilter('status', [
            'pending',
            'approved',
            'active',
          ]); // ✅ Fixed: .in_ to .inFilter

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
