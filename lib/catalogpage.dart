import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> with AutomaticKeepAliveClientMixin {
  late Future<List<Equipment>> _equipmentFuture;
  String selectedCategory = 'All';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Keep the widget alive when switching tabs
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _equipmentFuture = _fetchEquipment();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Equipment>> _fetchEquipment() async {
    try {
      final response = await supabase
          .from('equipment')
          .select('*, equipment_categories(category_name)');

      final equipmentList = response.map((map) {
        return Equipment.fromMap(map);
      }).toList();

      return equipmentList;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching equipment: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      rethrow;
    }
  }

  List<String> get categories => [
    'All',
    'Laptops',
    'Projectors',
    'HDMI Cables',
    'Audio',
    'Tablets',
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Catalog',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2B326B),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showFilterDialog,
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(color: const Color(0xFFFFC107), height: 4.0),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                if (mounted) {
                  setState(() {
                    searchQuery = value;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: 'Search equipment...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF4A55A2)),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (mounted) {
                        setState(() {
                          selectedCategory = category;
                        });
                      }
                    },
                    selectedColor: const Color(0xFF4A55A2),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Equipment>>(
              future: _equipmentFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error.toString()}'),
                  );
                }

                final equipmentList = snapshot.data!;
                final filteredList = equipmentList.where((equipment) {
                  final matchesCategory =
                      selectedCategory == 'All' ||
                      equipment.categoryName == selectedCategory;
                  final matchesSearch =
                      searchQuery.isEmpty ||
                      equipment.name.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      );
                  return matchesCategory && matchesSearch;
                }).toList();

                if (filteredList.isEmpty) {
                  return _buildEmptyState();
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    return _buildEquipmentCard(filteredList[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Filter Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Show Available Only'),
                trailing: Switch(value: false, onChanged: (value) {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No equipment found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filter',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  IconData _getIconForCategory(String categoryName) {
    switch (categoryName) {
      case 'Laptops':
        return Icons.laptop_mac;
      case 'Projectors':
        return Icons.video_camera_front_outlined;
      case 'HDMI Cables':
        return Icons.cable;
      case 'Audio':
        return Icons.headset_outlined;
      case 'Tablets':
        return Icons.tablet_mac;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Widget _buildEquipmentCard(Equipment equipment) {
    final isAvailable = equipment.status.toLowerCase() == 'available';
    final fallbackIcon = _getIconForCategory(equipment.categoryName);

    String specsString = [
      equipment.specifications['RAM'],
      equipment.specifications['Storage'],
      equipment.specifications['Resolution'],
      equipment.specifications['Length'],
      equipment.specifications['Technology'],
    ].where((s) => s != null).join(', ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child:
                        (equipment.imageUrl != null &&
                            equipment.imageUrl!.isNotEmpty)
                        ? Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.network(
                              equipment.imageUrl!,
                              fit: BoxFit.contain,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  fallbackIcon,
                                  size: 60,
                                  color: Colors.grey[400],
                                );
                              },
                            ),
                          )
                        : Icon(fallbackIcon, size: 60, color: Colors.grey[400]),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isAvailable ? 'Available' : 'Borrowed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      equipment.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(
                      specsString,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Equipment class remains the same
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
      categoryName:
          map['equipment_categories']?['category_name'] ?? 'Uncategorized',
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