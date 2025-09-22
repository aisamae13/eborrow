import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'main.dart';
import 'models/borrow_request.dart'; // MODIFIED: Import BorrowRequest model

// MODIFIED: Class name and constructor
class ModifyRequestPage extends StatefulWidget {
  final BorrowRequest request;
  const ModifyRequestPage({super.key, required this.request});

  @override
  State<ModifyRequestPage> createState() => _ModifyRequestPageState();
}

// MODIFIED: State class name
class _ModifyRequestPageState extends State<ModifyRequestPage> {
  final _purposeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late DateTime _borrowDate;
  late DateTime _returnDate;

  @override
  void initState() {
    super.initState();
    // MODIFIED: Pre-fill form with data from the request object
    _borrowDate = widget.request.borrowDate;
    _returnDate = widget.request.returnDate;
    _purposeController.text = widget.request.purpose ?? '';
  }

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }

  // This function can be reused for picking the return date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _returnDate,
      firstDate: _borrowDate, // Can't set return date before borrow date
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null && mounted) {
      setState(() {
        // Combine the picked date with the existing time of the return date
        _returnDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _returnDate.hour,
          _returnDate.minute,
        );
      });
    }
  }

  // This function can be reused for picking the return time
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_returnDate),
    );

    if (pickedTime != null && mounted) {
      setState(() {
        _returnDate = DateTime(
          _returnDate.year,
          _returnDate.month,
          _returnDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  // ---- NEW: Function to handle the UPDATE operation ----
  Future<void> _submitModifiedRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // Prevent setting a return time that is before the borrow time
    if (_returnDate.isBefore(_borrowDate)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Return date cannot be earlier than the borrow date.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await supabase
          .from('borrow_requests')
          .update({
            'return_date': _returnDate.toIso8601String(), // <-- Corrected
            'purpose': _purposeController.text.trim(),
            'modification_count': widget.request.modificationCount + 1,
          })
          .eq('request_id', widget.request.requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Pop back to the history page
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating request: ${e.toString()}'),
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
          'Modify Request', // MODIFIED: Title
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
                widget.request.equipmentName, // MODIFIED: Get name from request
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              // MODIFIED: Only show Return Date for editing
              _buildInfoRow(
                'Return Date',
                '${dateFormat.format(_returnDate)} at ${timeFormat.format(_returnDate)}',
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Change Date'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _selectTime(context),
                    icon: const Icon(Icons.access_time, size: 16),
                    label: const Text('Change Time'),
                  ),
                ],
              ),
              const Divider(height: 20),
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
                  onPressed: _isLoading
                      ? null
                      : _submitModifiedRequest, // MODIFIED: Call new function
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
                          'Save Changes', // MODIFIED: Button text
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

  // Simplified row widget since it's no longer clickable
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: Colors.grey[600])),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
