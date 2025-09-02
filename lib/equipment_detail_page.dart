import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'borrow_request_page.dart';
import 'catalogpage.dart';
import 'main.dart';

// 1. Converted to a StatefulWidget
class EquipmentDetailPage extends StatefulWidget {
  final Equipment equipment;

  const EquipmentDetailPage({super.key, required this.equipment});

  @override
  State<EquipmentDetailPage> createState() => _EquipmentDetailPageState();
}

class _EquipmentDetailPageState extends State<EquipmentDetailPage> {
  // 2. Added a loading state variable
  bool _isLoading = false;

  // 3. New function to handle the borrow request logic
  Future<void> _requestToBorrow() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        // This will be caught by the catch block below
        throw 'User is not logged in. Please sign in again.';
      }

      final borrowDate = DateTime.now();
      // Using the 2-hour borrow limit from our workflow
      final returnDate = borrowDate.add(const Duration(hours: 2));

      // Insert a new row into the 'borrow_requests' table
      await supabase.from('borrow_requests').insert({
        'borrower_id': userId,
        'equipment_id': widget.equipment.equipmentId,
        'borrow_date': borrowDate.toIso8601String(),
        'return_date': returnDate.toIso8601String(),
        'status': 'pending',
        'purpose': 'General Use', // Placeholder purpose
      });

      // On success, we simply navigate back to the catalog page.
      // This navigation is the user's confirmation that it worked.
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // If an error occurs, we stay on the page and show a SnackBar.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting request: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      // This ensures the loading indicator always stops,
      // whether the request succeeds or fails.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showReportIssueDialog() {
    final descriptionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Report an Issue'),
          content: TextField(
            controller: descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: "Please describe the problem...",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (descriptionController.text.trim().isNotEmpty) {
                  _submitIssueReport(descriptionController.text.trim());
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Submit'),
            ),
          ],
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
        // Add this 'actions' block
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
            // ... (The rest of the body is unchanged)
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
                        color: isAvailable
                            ? Colors.green[800]
                            : Colors.red[800],
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        // 4. The button is now updated to handle the loading state and call the new function
        child: ElevatedButton(
          onPressed: isAvailable
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          BorrowRequestPage(equipment: widget.equipment),
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
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
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
