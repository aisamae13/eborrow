import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../main.dart';
import 'equipment_detail_page.dart';
import 'package:eborrow/borrower/models/equipment_model.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Equipment>> _equipmentFuture;
  late Future<List<String>> _categoriesFuture;
  String selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _showAvailableOnly = false;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _fetchCategories();
    _equipmentFuture = _fetchEquipment();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Future<List<String>> _fetchCategories() async {
    try {
      final response = await supabase
          .from('equipment_categories')
          .select('category_name')
          .order('category_name');

      final categoryList = response
          .map((map) => map['category_name'] as String)
          .toList();

      return ['All', ...categoryList];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching categories: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      rethrow;
    }
  }

  Future<List<Equipment>> _fetchEquipment() async {
    try {
      // Use left join instead of inner join to get all equipment
      var query = supabase
          .from('equipment')
          .select('*, equipment_categories(category_name)');

      if (_searchQuery.isNotEmpty) {
        query = query.or(
          'name.ilike.%$_searchQuery%,brand.ilike.%$_searchQuery%,model.ilike.%$_searchQuery%',
        );
      }

      if (selectedCategory != 'All') {
        // Filter by category name from the join OR from the category field
        final categoryData = await supabase
            .from('equipment_categories')
            .select('category_id')
            .eq('category_name', selectedCategory)
            .maybeSingle();

        if (categoryData != null) {
          query = query.eq('category_id', categoryData['category_id']);
        }
      }

      if (_showAvailableOnly) {
        query = query.eq('status', 'available');
      }

      final response = await query.order('created_at', ascending: false);

      final equipmentList = response.map((map) {
        // Flatten the nested structure for backward compatibility
        final flatMap = Map<String, dynamic>.from(map);

        // Extract category name from join or use the category field
        if (map['equipment_categories'] != null &&
            map['equipment_categories']['category_name'] != null) {
          flatMap['categoryName'] = map['equipment_categories']['category_name'];
        } else if (map['category'] != null) {
          flatMap['categoryName'] = map['category'];
        } else {
          flatMap['categoryName'] = 'Unknown';
        }

        // Remove the nested object
        flatMap.remove('equipment_categories');

        return Equipment.fromMap(flatMap);
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

  void _refreshData() {
    setState(() {
      _equipmentFuture = _fetchEquipment();
    });
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
          _equipmentFuture = _fetchEquipment();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Catalog',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w500,
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
              decoration: InputDecoration(
                hintText: 'Search equipment...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF4A55A2)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF4A55A2)),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged();
                        },
                      )
                    : null,
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
          FutureBuilder<List<String>>(
            future: _categoriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SizedBox(
                  height: 60,
                  child: Center(
                    child: Text('Error loading categories: ${snapshot.error}'),
                  ),
                );
              }

              final categories = snapshot.data!;
              return Container(
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
                            _equipmentFuture = _fetchEquipment();
                          });
                        },
                        selectedColor: const Color(0xFF4A55A2),
                        checkmarkColor: Colors.white,
                        labelStyle: GoogleFonts.poppins(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading equipment',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(color: Colors.grey[500]),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final equipmentList = snapshot.data!;
                if (equipmentList.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      selectedCategory = 'All';
                      _showAvailableOnly = false;
                      _equipmentFuture = _fetchEquipment();
                    });
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: equipmentList.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EquipmentDetailPage(
                                equipment: equipmentList[index],
                              ),
                            ),
                          );
                        },
                        child: _buildEquipmentCard(equipmentList[index]),
                      );
                    },
                  ),
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
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Filter Options',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2B326B),
                      ),
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Show Available Only'),
                      value: _showAvailableOnly,
                      onChanged: (bool value) {
                        dialogSetState(() {
                          _showAvailableOnly = value;
                        });
                      },
                      activeColor: const Color(0xFF2B326B),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2B326B),
                            side: const BorderSide(color: Color(0xFF2B326B)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Close'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _refreshData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2B326B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
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
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filter',
            style: GoogleFonts.poppins(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  IconData _getIconForCategory(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'laptops':
        return Icons.laptop_mac;
      case 'projectors':
        return Icons.video_camera_front_outlined;
      case 'hdmi cables':
      case 'cables':
        return Icons.cable;
      case 'audio':
      case 'audio equipment':
        return Icons.headset_outlined;
      case 'tablets':
        return Icons.tablet_mac;
      case 'monitors':
        return Icons.monitor;
      case 'keyboards':
        return Icons.keyboard;
      case 'mice':
      case 'mouse':
        return Icons.mouse;
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
                        style: GoogleFonts.poppins(
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
                      style: GoogleFonts.poppins(
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
                      specsString.isNotEmpty ? specsString : equipment.brand ?? 'No details',
                      style: GoogleFonts.poppins(
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