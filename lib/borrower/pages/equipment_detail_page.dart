import 'package:eborrow/borrower/models/equipment_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'borrow_request_page.dart';
import '../../main.dart';

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
                const Align(
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        "Please describe the problem with this equipment...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      // Use OutlinedButton for the outline effect
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2B326B),
                        side: const BorderSide(
                          color: Color(0xFF2B326B),
                        ), // Sets the border color
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
    // --- 🚀 NEW STATUS LOGIC ---
    final statusLower = widget.equipment.status.toLowerCase();
    final isAvailable = statusLower == 'available';
    final isMaintenance = statusLower == 'maintenance';
    final isRetired = statusLower == 'retired';
    final isUnavailable = !isAvailable;

    // Determine colors and message based on status
    Color statusBgColor;
    Color statusFgColor;
    String statusMessage;

    if (isAvailable) {
      statusBgColor = Colors.green[100]!;
      statusFgColor = Colors.green[800]!;
      statusMessage = '';
    } else if (isMaintenance) {
      statusBgColor = Colors.orange[100]!;
      statusFgColor = Colors.orange[800]!;
      statusMessage = 'This item is currently **In Maintenance** and cannot be borrowed.';
    } else if (isRetired) {
      statusBgColor = Colors.grey[300]!;
      statusFgColor = Colors.grey[800]!; // Dark gray for retired
      statusMessage = 'This item has been **Retired** and is permanently unavailable.';
    } else {
      // Default to Borrowed for all other unavailable statuses
      statusBgColor = Colors.red[100]!;
      statusFgColor = Colors.red[800]!;
      statusMessage = 'This item is currently **Borrowed** and is unavailable.';
    }

    // Define the action for the button's onPressed property
    VoidCallback? onPressedAction = isAvailable
        ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    BorrowRequestPage(equipment: widget.equipment),
              ),
            );
          }
        : null; // Null disables the button
    // --- END NEW STATUS LOGIC ---

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Details',
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
              child:
                  (widget.equipment.imageUrl != null &&
                      widget.equipment.imageUrl!.isNotEmpty)
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
                  // --- 🚀 UPDATED STATUS BADGE DISPLAY ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor, // Use calculated color
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.equipment.status.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: statusFgColor, // Use calculated color
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  // --- END UPDATED STATUS BADGE DISPLAY ---
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
                    widget.equipment.specifications.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join('\n'),
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
      // --- 🚀 UPDATED BOTTOM NAVIGATION BAR ---
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isUnavailable)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  statusMessage.replaceAll('**', ''), // Display message without markdown
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: onPressedAction, // Null disables the button when unavailable
              style: ElevatedButton.styleFrom(
                // Use a light gray color when disabled for better UX
                backgroundColor: isAvailable
                    ? const Color(0xFF2B326B)
                    : Colors.grey[400],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: Text(
                isAvailable ? 'Request to Borrow' : 'Not Available', // Text changes when disabled
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isAvailable ? Colors.white : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
      // --- END UPDATED BOTTOM NAVIGATION BAR ---
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