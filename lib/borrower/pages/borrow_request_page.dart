import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../models/equipment_model.dart';
import 'request_submitted_page.dart';
import '../models/borrow_request.dart';
// NOTE: NotificationService import is not needed here as it's not directly called.
// If it was imported, it is safe to keep it, but the call should be gone.

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

  late DateTime _borrowDate;
  late DateTime _returnDate;

  bool _hasStudentId = true;

  @override
  void initState() {
    super.initState();
    _borrowDate = DateTime.now();
    _returnDate = _borrowDate.add(const Duration(hours: 2));
    _checkStudentId();
  }

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _checkStudentId() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _hasStudentId = false;
        });
      }
      return;
    }

    try {
      final profile = await supabase
          .from('user_profiles')
          .select('student_id')
          .eq('id', user.id)
          .single();
      final studentId = profile['student_id'];
      if (mounted) {
        setState(() {
          _hasStudentId = studentId != null && studentId.isNotEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasStudentId = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isBorrowDate) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isBorrowDate ? _borrowDate : _returnDate,
      firstDate: isBorrowDate ? DateTime.now() : _borrowDate,
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null) {
      if (mounted) {
        setState(() {
          if (isBorrowDate) {
            _borrowDate = pickedDate;
            if (_returnDate.isBefore(_borrowDate)) {
              _returnDate = _borrowDate.add(const Duration(hours: 2));
            }
          } else {
            _returnDate = pickedDate;
          }
        });
      }
    }
  }

  Future<void> _selectTime(BuildContext context, bool isBorrowDate) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        isBorrowDate ? _borrowDate : _returnDate,
      ),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              // Change the background color of the AM/PM toggle
              dayPeriodColor: WidgetStateColor.resolveWith(
                (states) => states.contains(MaterialState.selected)
                    ? Color(0xFF2B326B) // Selected AM/PM background color
                    : Colors.grey[200] ??
                          Colors.grey, // Unselected AM/PM background color
              ),
              // Change the text color of the AM/PM text
              dayPeriodTextColor: MaterialStateColor.resolveWith(
                (states) => states.contains(MaterialState.selected)
                    ? Colors
                          .white // Selected AM/PM text color
                    : Colors.black, // Unselected AM/PM text color
              ),
              // You can also change the border color
              dayPeriodBorderSide: BorderSide(
                color: Color(0xFF2B326B), // Border color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      if (mounted) {
        setState(() {
          if (isBorrowDate) {
            _borrowDate = DateTime(
              _borrowDate.year,
              _borrowDate.month,
              _borrowDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
            if (_returnDate.isBefore(_borrowDate)) {
              _returnDate = _borrowDate.add(const Duration(hours: 2));
            }
          } else {
            _returnDate = DateTime(
              _returnDate.year,
              _returnDate.month,
              _returnDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
          }
        });
      }
    }
  }

  // PASTE THE NEW FUNCTION HERE
  Future<void> _confirmAndSubmitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ready to Proceed?'),
        content: const Text(
          'This will send your request to the IT Admin. Please note that this does NOT reserve the item. Approval is first-come, first-served in person.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B326B),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm & Submit'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // If the user confirmed, then call your original submit function
      _submitBorrowRequest();
    }
  }

  Future<void> _submitBorrowRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_hasStudentId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please add your Student ID to your profile before requesting equipment.',
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
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'User is not logged in.';
      }

      // ✅ ADD: Check current active requests before submitting
      final activeRequests = await supabase
          .from('borrow_requests')
          .select('request_id')
          .eq('borrower_id', userId)
          .inFilter('status', ['pending', 'approved', 'active']);

      if (activeRequests.length >= 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'You have reached the maximum limit of 5 concurrent borrow requests. Please wait for some to be completed.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // 1. INSERT THE REQUEST. THE DATABASE TRIGGER HANDLES THE NOTIFICATION.
      final response = await supabase
          .from('borrow_requests')
          .insert({
            'borrower_id': userId,
            'equipment_id': widget.equipment.equipmentId,
            'borrow_date': _borrowDate.toIso8601String(),
            'return_date': _returnDate.toIso8601String(),
            'status': 'pending',
            'purpose': _purposeController.text.trim(),
          })
          .select('*, equipment(name)')
          .single();

      if (mounted) {
        // Create a BorrowRequest object from the response
        final newRequest = BorrowRequest.fromMap(response);

        // Navigate to the success screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => RequestSubmittedPage(request: newRequest),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error submitting request: ${e.toString()}';

        // ✅ ADD: Better error handling for specific cases
        if (e.toString().contains('maximum limit of 5 concurrent')) {
          errorMessage = 'You can only have 5 active requests at a time. Please wait for some to be completed.';
        } else if (e.toString().contains('student_id')) {
          errorMessage = 'Please add your Student ID to your profile first.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
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
              _buildClickableInfoRow(
                'Borrow Date',
                '${dateFormat.format(_borrowDate)} at ${timeFormat.format(_borrowDate)}',
                () => _selectDate(context, true),
                () => _selectTime(context, true),
              ),
              const SizedBox(height: 12),
              _buildClickableInfoRow(
                'Return Date',
                '${dateFormat.format(_returnDate)} at ${timeFormat.format(_returnDate)}',
                () => _selectDate(context, false),
                () => _selectTime(context, false),
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
                    borderSide: BorderSide(
                      color: const Color.fromARGB(255, 26, 40, 147),
                    ),
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
                  onPressed: _isLoading || !_hasStudentId
                      ? null
                      : _confirmAndSubmitRequest,
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
              if (!_hasStudentId)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    'You must have a student ID in your profile to borrow equipment.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClickableInfoRow(
    String label,
    String value,
    VoidCallback onDateTap,
    VoidCallback onTimeTap,
  ) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    final borrowDateString = dateFormat.format(_borrowDate);
    final borrowTimeString = timeFormat.format(_borrowDate);

    final returnDateString = dateFormat.format(_returnDate);
    final returnTimeString = timeFormat.format(_returnDate);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: Colors.grey[600])),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Flexible para sa DATE
              Flexible(
                child: GestureDetector(
                  onTap: onDateTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label == 'Borrow Date'
                              ? borrowDateString
                              : returnDateString,
                          textAlign: TextAlign.end,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Flexible para sa TIME
              Flexible(
                child: GestureDetector(
                  onTap: onTimeTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label == 'Borrow Date'
                              ? borrowTimeString
                              : returnTimeString,
                          textAlign: TextAlign.end,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}