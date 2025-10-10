import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/borrow_request.dart';
import '../../admin/widgets/borrow_countdown_timer.dart';

void showRequestDetailPopup(BuildContext context, BorrowRequest item) {
  // Determine if this is an admin rejection (cancelled with rejection reason)
  final bool isAdminRejection = item.status.toLowerCase() == 'cancelled' &&
                                 item.rejectionReason != null &&
                                 item.rejectionReason!.isNotEmpty;

  // Helper to get the correct display status
  String getDisplayStatus() {
    if (isAdminRejection) {
      return 'Rejected';
    }
    return item.formattedStatus;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
    ),
    builder: (context) {
      return Padding(
        // Use media query for dynamic bottom padding (handles keyboard/safe area)
        padding: EdgeInsets.fromLTRB(
            20.0, 20.0, 20.0, MediaQuery.of(context).viewInsets.bottom + 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title / Equipment Name
            Text(
              item.equipmentName,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade800,
              ),
            ),

            const Divider(height: 20),

            // Status and Dates
            _buildDetailRow('Status', getDisplayStatus(), item.getStatusColor()),
            _buildDetailRow('Requested Date', DateFormat('MMM dd, yyyy hh:mm a').format(item.borrowDate)),
            _buildDetailRow('Return Date', DateFormat('MMM dd, yyyy hh:mm a').format(item.returnDate)),

            const SizedBox(height: 15),

            // ADDED: Countdown Timer for approved, active, and overdue requests
            if (['approved','active','overdue'].contains(item.status.toLowerCase())) ...[
              Text(
                'Time Status',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              BorrowCountdownTimer(
                borrowDate: item.borrowDate,
                returnDate: item.returnDate,
                compact: false,
                onFinished: () {
                  // Optional: Close popup and refresh parent when status changes
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 15),
            ],

            // Purpose
            if (item.purpose != null && item.purpose!.isNotEmpty)
              _buildSection('Purpose', item.purpose!),

            // Rejection Reason (for both 'rejected' status and 'cancelled' with rejection reason)
            if ((item.status.toLowerCase() == 'rejected' || isAdminRejection) &&
                item.rejectionReason != null &&
                item.rejectionReason!.isNotEmpty)
              _buildSection('Rejection Reason', item.rejectionReason!, color: Colors.red.shade700),

            const SizedBox(height: 20),
          ],
        ),
      );
    },
  );
}

// Helper widget for a simple detail row
Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120, // Aligning the labels
          child: Text(
            '$label:',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
      ],
    ),
  );
}

// Helper widget for purpose/reason sections
Widget _buildSection(String title, String content, {Color? color}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color ?? Colors.black,
        ),
      ),
      const SizedBox(height: 5),
      Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          content,
          style: GoogleFonts.poppins(fontSize: 14),
        ),
      ),
      const SizedBox(height: 15),
    ],
  );
}