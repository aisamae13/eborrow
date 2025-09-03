// This file only contains the data model
// Add this if your class uses Color or other Flutter types

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
    return Equipment(
      equipmentId: map['equipment_id'],
      name: map['name'],
      model: map['model'],
      brand: map['brand'],
      categoryId: map['category_id'],
      categoryName: map['equipment_categories']?['category_name'] ?? 'Uncategorized',
      qrCode: map['qr_code'],
      description: map['description'],
      specifications: (map['specifications'] is Map<String, dynamic>)
          ? map['specifications']
          : {},
      status: map['status'],
      imageUrl: map['image_url'],
    );
  }
}