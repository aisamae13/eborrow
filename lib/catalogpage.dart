import 'package:flutter/material.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  String selectedCategory = 'All';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Sample equipment data
  final List<Equipment> equipmentList = [
    Equipment(
      name: 'MacBook Pro 13"',
      category: 'Laptops',
      availability: 'Available',
      specs: 'M2 Chip, 8GB RAM, 256GB SSD',
      imageIcon: Icons.laptop_mac,
    ),
    Equipment(
      name: 'Dell XPS 15',
      category: 'Laptops',
      availability: 'Borrowed',
      specs: 'Intel i7, 16GB RAM, 512GB SSD',
      imageIcon: Icons.laptop_windows,
    ),
    Equipment(
      name: 'Epson Projector',
      category: 'Projectors',
      availability: 'Available',
      specs: '3LCD, 3300 lumens, WXGA',
      imageIcon: Icons.video_camera_front,
    ),
    Equipment(
      name: 'HDMI Cable 2m',
      category: 'Cables',
      availability: 'Available',
      specs: 'High-speed HDMI 2.1',
      imageIcon: Icons.cable,
    ),
    Equipment(
      name: 'Sony Headphones',
      category: 'Audio',
      availability: 'Available',
      specs: 'Wireless, Noise Cancelling',
      imageIcon: Icons.headset,
    ),
    Equipment(
      name: 'iPad Pro',
      category: 'Tablets',
      availability: 'Available',
      specs: '11-inch, M2 chip, 128GB',
      imageIcon: Icons.tablet_mac,
    ),
  ];

  List<String> get categories {
    final cats = equipmentList.map((e) => e.category).toSet().toList();
    return ['All', ...cats];
  }

  List<Equipment> get filteredEquipment {
    return equipmentList.where((equipment) {
      final matchesCategory = selectedCategory == 'All' || equipment.category == selectedCategory;
      final matchesSearch = searchQuery.isEmpty ||
          equipment.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          equipment.category.toLowerCase().contains(searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The new App Bar matching the Home Page design.
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
          // The filter icon is moved into the App Bar actions
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {
              _showFilterDialog();
            },
          ),
          const SizedBox(width: 16), // Spacing for the icon
        ],
        // The yellow line is now part of the app bar's bottom property.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(
            color: const Color(0xFFFFC107),
            height: 4.0,
          ),
        ),
      ),
      body: Column(
        children: [
          // The Search Bar and Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Category Filter Chips
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
                      setState(() {
                        selectedCategory = category;
                      });
                    },
                    selectedColor: const Color(0xFF4A55A2),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),

          // Equipment Grid
          Expanded(
            child: filteredEquipment.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filteredEquipment.length,
                    itemBuilder: (context, index) {
                      return _buildEquipmentCard(filteredEquipment[index]);
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
                trailing: Switch(
                  value: false,
                  onChanged: (value) {
                    // Implement filter logic
                  },
                ),
              ),
              ListTile(
                title: const Text('Sort by Name'),
                trailing: const Icon(Icons.keyboard_arrow_right),
                onTap: () {
                  // Implement sort logic
                },
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
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
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
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentCard(Equipment equipment) {
    final isAvailable = equipment.availability == 'Available';

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
          // Equipment Image/Icon Container
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
                  // Equipment Icon
                  Center(
                    child: Icon(
                      equipment.imageIcon,
                      size: 60,
                      color: Colors.grey[400],
                    ),
                  ),
                  // Status Badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
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

          // Equipment Details
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Equipment Name
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

                  // Equipment Specs
                  Flexible(
                    child: Text(
                    equipment.specs,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
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

// Equipment model class
class Equipment {
  final String name;
  final String category;
  final String availability;
  final String specs;
  final IconData imageIcon;

  Equipment({
    required this.name,
    required this.category,
    required this.availability,
    required this.specs,
    required this.imageIcon,
  });
}
