class Equipment {
  final int equipmentId;
  final String name;
  final String? model;
  final String? brand;
  final int categoryId;
  final String categoryName;
  final String qrCode;
  final String? description;
  final Map<String, dynamic> specifications;
  final String status;
  final String? imageUrl;

  Equipment({
    required this.equipmentId,
    required this.name,
    this.model,
    this.brand,
    required this.categoryId,
    required this.categoryName,
    required this.qrCode,
    this.description,
    required this.specifications,
    required this.status,
    this.imageUrl,
  });

  factory Equipment.fromMap(Map<String, dynamic> map) {
    // Handle category name from multiple possible sources
    String getCategoryName() {
      // First, check if it's already flattened
      if (map['categoryName'] != null) {
        return map['categoryName'];
      }
      // Check nested structure from join
      if (map['equipment_categories']?['category_name'] != null) {
        return map['equipment_categories']['category_name'];
      }
      // Fallback to category varchar field
      if (map['category'] != null) {
        return map['category'];
      }
      return 'Uncategorized';
    }

    // Handle specifications - JSONB can come as Map or need parsing
    Map<String, dynamic> getSpecifications() {
      final specs = map['specifications'];
      if (specs == null) return {};
      if (specs is Map<String, dynamic>) return specs;
      if (specs is Map) return Map<String, dynamic>.from(specs);
      return {};
    }

    return Equipment(
      equipmentId: map['equipment_id'] as int,
      name: map['name'] as String,
      model: map['model'] as String?,
      brand: map['brand'] as String?,
      categoryId: map['category_id'] as int,
      categoryName: getCategoryName(),
      qrCode: map['qr_code'] as String,
      description: map['description'] as String?,
      specifications: getSpecifications(),
      status: map['status'] as String? ?? 'available',
      imageUrl: map['image_url'] as String?,
    );
  }
}