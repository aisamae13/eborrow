import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'catalogpage.dart';
import 'main.dart';

class BorrowRequestPage extends StatefulWidget {
  final Equipment equipment;
  const BorrowRequestPage({super.key, required this.equipment});

  @override
  State<BorrowRequestPage> createState() => _BorrowRequestPageState();
}

class _BorrowRequestPageState extends State<BorrowRequestPage> {
  final _purposeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late final DateTime _borrowDate;
  late final DateTime _returnDate;

  @override
  void initState() {
    super.initState();
    _borrowDate = DateTime.now();
    _returnDate = _borrowDate.add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _submitBorrowRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'User is not logged in.';
      }

      await supabase.from('borrow_requests').insert({
        'borrower_id': userId,
        'equipment_id': widget.equipment.equipmentId,
        'borrow_date': _borrowDate.toIso8601String(),
        'return_date': _returnDate.toIso8601String(),
        'status': 'pending',
        'purpose': _purposeController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Request submitted! Please see the IT Admin for approval.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back to the catalog, clearing the detail and request pages
        Navigator.of(context).popUntil((route) => route.isFirst);
        // Note: You might need to add logic to switch the bottom nav index back to catalog
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting request: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Borrow Request',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2B326B),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.equipment.name,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildInfoRow('Borrow Date', dateFormat.format(_borrowDate)),
              const SizedBox(height: 12),
              _buildInfoRow(
                'Return Date',
                '${dateFormat.format(_returnDate)} (${timeFormat.format(_returnDate)})',
              ),
              const Divider(height: 40),
              Text(
                'Purpose',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _purposeController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'e.g., For class presentation in Room 501',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the purpose for borrowing.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitBorrowRequest,
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
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : Text(
                          'Submit Request',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: Colors.grey[600])),
        Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
