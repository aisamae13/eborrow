import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/equipment_management_service.dart';
import '../widgets/equipmeent_card.dart';
import '../widgets/add_equipment_dialog.dart';
import '../widgets/edit_equipment_dialog.dart';

class EquipmentManagementPage extends StatefulWidget {
  const EquipmentManagementPage({super.key});

  @override
  State<EquipmentManagementPage> createState() =>
      _EquipmentManagementPageState();
}

class _EquipmentManagementPageState extends State<EquipmentManagementPage> {
  late Future<List<Map<String, dynamic>>> _equipmentFuture;
  late Future<List<String>> _categoriesFuture;

  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';
  String _selectedStatus = 'all';
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _equipmentFuture = EquipmentManagementService.getAllEquipment(
        searchQuery: _searchController.text,
        category: _selectedCategory,
        status: _selectedStatus,
      );
      _categoriesFuture = EquipmentManagementService.getCategories();
    });
  }

  void _showAddEquipmentDialog() {
    showDialog(
      context: context,
      builder: (context) => AddEquipmentDialog(onEquipmentAdded: _loadData),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Equipments',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2B326B),
        actions: [
          // Toggle Grid/List View
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list : Icons.grid_view,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          // Add Equipment
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showAddEquipmentDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          _buildSearchAndFilterBar(),

          // Equipment Stats
          _buildStatsBar(),

          // Equipment List/Grid
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _loadData();
              },
              child: FutureBuilder<List<Map<String, dynamic>>>(
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
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading equipment',
                            style: GoogleFonts.poppins(),
                          ),
                          TextButton(
                            onPressed: _loadData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final equipment = snapshot.data ?? [];

                  if (equipment.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2,
                            size: 80,
                            color: Colors.grey[400],
                          ),
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
                            'Add your first equipment to get started',
                            style: GoogleFonts.poppins(color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _showAddEquipmentDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Equipment'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2B326B),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return _isGridView
                      ? _buildGridView(equipment)
                      : _buildListView(equipment);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search equipment...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _loadData();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (_) => _loadData(),
          ),

          const SizedBox(height: 12),

          // Filter Row - FIXED LAYOUT
          Row(
            children: [
              // Category Filter
              Expanded(
                flex: 1, // ✅ Added flex to control space distribution
                child: FutureBuilder<List<String>>(
                  future: _categoriesFuture,
                  builder: (context, snapshot) {
                    final categories = ['all', ...?snapshot.data];

                    return DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, // ✅ Reduced padding
                          vertical: 12,
                        ),
                        isDense: true, // ✅ Added to make dropdown more compact
                      ),
                      isExpanded: true, // ✅ Added to prevent overflow
                      items: categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(
                            category == 'all' ? 'All Categories' : category,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                            ), // ✅ Set font size
                            overflow:
                                TextOverflow.ellipsis, // ✅ Handle text overflow
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value ?? 'all';
                        });
                        _loadData();
                      },
                    );
                  },
                ),
              ),

              const SizedBox(width: 12),

              // Status Filter
              Expanded(
                flex: 1, // ✅ Added flex to control space distribution
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, // ✅ Reduced padding
                      vertical: 12,
                    ),
                    isDense: true, // ✅ Added to make dropdown more compact
                  ),
                  isExpanded: true, // ✅ Added to prevent overflow
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('All Status', style: TextStyle(fontSize: 14)),
                    ),
                    DropdownMenuItem(
                      value: 'available',
                      child: Text('Available', style: TextStyle(fontSize: 14)),
                    ),
                    DropdownMenuItem(
                      value: 'borrowed',
                      child: Text('Borrowed', style: TextStyle(fontSize: 14)),
                    ),
                    DropdownMenuItem(
                      value: 'maintenance',
                      child: Text(
                        'Maintenance',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'retired',
                      child: Text('Retired', style: TextStyle(fontSize: 14)),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value ?? 'all';
                    });
                    _loadData();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return FutureBuilder<Map<String, int>>(
      future: EquipmentManagementService.getEquipmentStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final stats = snapshot.data!;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total', stats['total']!, Colors.blue),
              _buildStatItem('Available', stats['available']!, Colors.green),
              _buildStatItem('Borrowed', stats['borrowed']!, Colors.orange),
              _buildStatItem('Maintenance', stats['maintenance']!, Colors.red),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildGridView(List<Map<String, dynamic>> equipment) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.7, // ✅ Changed from 0.8 to 0.75 for more height
      ),
      itemCount: equipment.length,
      itemBuilder: (context, index) {
        return EquipmentCard(
          equipment: equipment[index],
          onEdit: () => _showEditDialog(equipment[index]),
          onDelete: () => _showDeleteDialog(equipment[index]),
          onStatusChange: (newStatus) =>
              _changeEquipmentStatus(equipment[index], newStatus),
          onRefresh: _loadData,
        );
      },
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> equipment) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: equipment.length,
      itemBuilder: (context, index) {
        return EquipmentCard(
          equipment: equipment[index],
          isListView: true,
          onEdit: () => _showEditDialog(equipment[index]),
          onDelete: () => _showDeleteDialog(equipment[index]),
          onStatusChange: (newStatus) =>
              _changeEquipmentStatus(equipment[index], newStatus),
          onRefresh: _loadData,
        );
      },
    );
  }

  void _showEditDialog(Map<String, dynamic> equipment) {
    showDialog(
      context: context,
      builder: (context) => EditEquipmentDialog(
        equipment: equipment,
        onEquipmentUpdated: _loadData,
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> equipment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Equipment'),
        content: Text(
          'Are you sure you want to delete "${equipment['name']}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await EquipmentManagementService.deleteEquipment(
                  equipment['equipment_id'],
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Equipment deleted successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadData();
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting equipment: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _changeEquipmentStatus(
    Map<String, dynamic> equipment,
    String newStatus,
  ) async {
    try {
      await EquipmentManagementService.updateEquipmentStatus(
        equipment['equipment_id'],
        newStatus,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: Colors.blue,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}