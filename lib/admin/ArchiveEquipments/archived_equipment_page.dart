import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/equipment_management_service.dart';
import '../widgets/equipmeent_card.dart';

class ArchivedEquipmentPage extends StatefulWidget {
  const ArchivedEquipmentPage({Key? key}) : super(key: key);

  @override
  State<ArchivedEquipmentPage> createState() => _ArchivedEquipmentPageState();
}

class _ArchivedEquipmentPageState extends State<ArchivedEquipmentPage> {
  late Future<List<Map<String, dynamic>>> _archivedFuture;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _archivedFuture = EquipmentManagementService.getAllEquipment(
      status: 'retired',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Archived Equipment', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF2B326B),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, color: Colors.white),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          )
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _archivedFuture,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snap.hasError || (snap.data ?? []).isEmpty) {
            return Center(
              child: Text(
                snap.hasError ? 'Error loading archived' : 'No archived equipment',
                style: GoogleFonts.poppins(fontSize: 18),
              ),
            );
          }
          final list = snap.data!;
          return _isGridView
            ? GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.7),
                itemCount: list.length,
                itemBuilder: (_, i) => EquipmentCard(
                  equipment: list[i],
                  isListView: false,
                  onEdit: () {},        // disable edit if desired
                  onArchive: () {},     // no further archiving
                  onStatusChange: (_) {}, 
                  onRefresh: () {},
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) => EquipmentCard(
                  equipment: list[i],
                  isListView: true,
                  onEdit: () {},
                  onArchive: () {},
                  onStatusChange: (_) {},
                  onRefresh: () {},
                ),
              );
        },
      ),
    );
  }
}