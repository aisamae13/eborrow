import 'package:eborrow/models/equipment_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'borrow_request_page.dart';
import 'main.dart';

class EquipmentDetailPage extends StatefulWidget {
  final Equipment equipment;

  const EquipmentDetailPage({super.key, required this.equipment});

  @override
  State<EquipmentDetailPage> createState() => _EquipmentDetailPageState();
}

class _EquipmentDetailPageState extends State<EquipmentDetailPage> {
  // We've removed the _isLoading variable and _requestToBorrow function from here.

 void _showReportIssueDialog() {
    final descriptionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.report_problem_outlined,
                    color: Colors.red,
                    size: 80, // Increased icon size
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Report an Issue',
                  style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "Please describe the problem with this equipment...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton( // Use OutlinedButton for the outline effect
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2B326B),
                        side: const BorderSide(color: Color(0xFF2B326B)), // Sets the border color
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (descriptionController.text.trim().isNotEmpty) {
                          _submitIssueReport(descriptionController.text.trim());
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B326B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitIssueReport(String description) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'User not found.';
      }
      await supabase.from('issues').insert({
        'reporter_id': userId,
        'equipment_id': widget.equipment.equipmentId,
        'description': description,
        'status': 'open',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue reported successfully. Thank you!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reporting issue: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = widget.equipment.status.toLowerCase() == 'available';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Equipment Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2B326B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.report_problem_outlined),
            onPressed: _showReportIssueDialog,
            tooltip: 'Report an Issue',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 250,
              width: double.infinity,
              color: Colors.grey[200],
              child: (widget.equipment.imageUrl != null && widget.equipment.imageUrl!.isNotEmpty)
                  ? Image.network(
                      widget.equipment.imageUrl!,
                      fit: BoxFit.contain,
                    )
                  : const Center(
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 100,
                        color: Colors.grey,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isAvailable ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.equipment.status.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: isAvailable ? Colors.green[800] : Colors.red[800],
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.equipment.name,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (widget.equipment.brand != null)
                    Text(
                      'Brand: ${widget.equipment.brand}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  const Divider(height: 32),
                  _buildDetailSection(
                    'Specifications',
                    widget.equipment.specifications.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
                  ),
                  if (widget.equipment.description != null)
                    _buildDetailSection(
                      'Description',
                      widget.equipment.description!,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: ElevatedButton(
          // The button now only navigates to the next page
          onPressed: isAvailable
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BorrowRequestPage(equipment: widget.equipment),
                    ),
                  );
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2B326B),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
          child: Text(
            isAvailable ? 'Request to Borrow' : 'Currently Borrowed',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.grey[800],
            height: 1.5,
          ),
        ),
        const Divider(height: 32),
      ],
    );
  }
}