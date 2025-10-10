import 'package:eborrow/shared/notifications/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../models/borrow_request.dart';

class ModifyRequestPage extends StatefulWidget {
  final BorrowRequest request;
  const ModifyRequestPage({super.key, required this.request});

  @override
  State<ModifyRequestPage> createState() => _ModifyRequestPageState();
}

class _ModifyRequestPageState extends State<ModifyRequestPage> {
  final _purposeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late DateTime _borrowDate;
  late DateTime _returnDate;

  @override
  void initState() {
    super.initState();
    _borrowDate = DateTime.now(); // Use current time as reference
    _returnDate = widget.request.returnDate;
    _purposeController.text = widget.request.purpose ?? '';
  }

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _returnDate,
      firstDate: DateTime.now(), // Use current time as minimum
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null && mounted) {
      setState(() {
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

  Future<void> _selectTime(BuildContext context) async {
    // Calculate the maximum allowed time (4 hours from now)
    final DateTime now = DateTime.now();
    final DateTime maxTime = now.add(const Duration(hours: 4));
    
    // If the selected date is today, we need to check time restrictions
    final bool isToday = _returnDate.year == now.year && 
                         _returnDate.month == now.month && 
                         _returnDate.day == now.day;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_returnDate),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              // Change the background color of the AM/PM toggle
              dayPeriodColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Color(0xFF2B326B) // Selected AM/PM background color
                    : Colors.grey[200] ??
                          Colors.grey, // Unselected AM/PM background color
              ),
              // Change the text color of the AM/PM text
              dayPeriodTextColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
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

    if (pickedTime != null && mounted) {
      final DateTime newReturnDate = DateTime(
        _returnDate.year,
        _returnDate.month,
        _returnDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      // Check if the selected time is within the 4-hour limit when it's today
      if (isToday) {
        if (newReturnDate.isAfter(maxTime)) {
          // Show error if time exceeds 4-hour limit
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Return time cannot be more than 4 hours from now.\nMaximum time today: ${DateFormat('hh:mm a').format(maxTime)}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
          return; // Don't update the time
        }
        
        // Check if the selected time is in the past
        if (newReturnDate.isBefore(now.add(const Duration(minutes: 15)))) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Return time must be at least 15 minutes from now.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          return; // Don't update the time
        }
      } else {
        // For future dates, just check that it's not in the past
        if (newReturnDate.isBefore(now)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Return time cannot be in the past.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          return; // Don't update the time
        }
      }

      // If all validations pass, update the return date
      setState(() {
        _returnDate = newReturnDate;
      });
    }
  }

  bool _isReturnDateValid() {
    return _returnDate.isAfter(_borrowDate);
  }

  Future<void> _submitModifiedRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isReturnDateValid()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Return date and time must be in the future.'),
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
            'return_date': _returnDate.toIso8601String(),
            'purpose': _purposeController.text.trim(),
            'modification_count': widget.request.modificationCount + 1,
          })
          .eq('request_id', widget.request.requestId);

      if (widget.request.modificationCount >= 2) {
        // Will be 3 after this update
        await NotificationService.createModificationLimitNotification(
          userId: supabase.auth.currentUser!.id,
          equipmentName: widget.request.equipmentName,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
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
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Modify Request',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2B326B),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 800, // Maximum width for larger screens
              minHeight:
                  size.height -
                  MediaQuery.of(context).padding.top -
                  kToolbarHeight -
                  120,
            ),
            child: Center(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Equipment Name - Responsive text
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        widget.request.equipmentName,
                        style: GoogleFonts.poppins(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 24),

                    // Return Date Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            'Return Date',
                            '${dateFormat.format(_returnDate)} at ${timeFormat.format(_returnDate)}',
                            isSmallScreen,
                          ),
                          
                          // ADD TIME LIMIT INFO
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Maximum borrow time: 4 hours from current time',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 12),

                          // Responsive button layout
                          if (isSmallScreen)
                            // Stack buttons vertically on small screens
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _selectDate(context),
                                  icon: const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                  ),
                                  label: const Text('Change Date'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF2B326B),
                                    side: const BorderSide(
                                      color: Color(0xFF2B326B),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _selectTime(context),
                                  icon: const Icon(Icons.access_time, size: 16),
                                  label: const Text('Change Time'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF2B326B),
                                    side: const BorderSide(
                                      color: Color(0xFF2B326B),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            // Side by side on larger screens
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _selectDate(context),
                                  icon: const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                  ),
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
                        ],
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 16 : 20),

                    // Purpose Section
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
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF2B326B),
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

                    SizedBox(height: isSmallScreen ? 24 : 32),

                    // Save Button - Full width and responsive
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitModifiedRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2B326B),
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 14 : 16,
                          ),
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
                                'Save Changes',
                                style: GoogleFonts.poppins(
                                  fontSize: isSmallScreen ? 14 : 16,
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
          ),
        ),
      ),
    );
  }

  // IMPROVED: Responsive info row that handles overflow better
  Widget _buildInfoRow(String label, String value, bool isSmallScreen) {
    if (isSmallScreen) {
      // Stack vertically on small screens
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      );
    } else {
      // Side by side on larger screens
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.grey[600])),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
  }
}
