import 'package:flutter/material.dart';

// The Official and Centralized Model for Borrow Requests
class BorrowRequest {
  final int requestId;
  final String borrowerId;
  final int equipmentId;
  final String equipmentName; // From joined table
  final DateTime borrowDate;
  final DateTime returnDate;
  final String? purpose;
  final String status;
  final DateTime createdAt;
  final int modificationCount;
  final String? rejectionReason;
  final String? equipmentImageUrl; // ✅ Correct: Field is declared

  BorrowRequest({
    required this.requestId,
    required this.borrowerId,
    required this.equipmentId,
    required this.equipmentName,
    required this.borrowDate,
    required this.returnDate,
    this.purpose,
    required this.status,
    required this.createdAt,
    required this.modificationCount,
    this.rejectionReason,
    this.equipmentImageUrl, // ✅ FIX: Added to the constructor
  });

  // Consolidated Status Color Logic (remains correct)
  Color getStatusColor() {
    switch (status.toLowerCase()) {
      case 'active':
      case 'borrowed':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'returned':
      case 'approved':
        return Colors.green;
      case 'rejected':
      case 'denied':
      case 'cancelled':
      case 'expired':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  String get formattedStatus {
    // If the DB status is 'rejected', return 'Rejected'
    if (status.toLowerCase() == 'rejected') {
        return 'Rejected';
    }

    if (status.isEmpty) return '';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  factory BorrowRequest.fromMap(Map<String, dynamic> map) {
    // 💡 FIX: Define equipmentMap here to safely access nested fields
    final equipmentMap = map['equipment'] as Map<String, dynamic>?;

    return BorrowRequest(
      requestId: map['request_id'],
      borrowerId: map['borrower_id'],
      equipmentId: map['equipment_id'],
      // 💡 FIX: Use the defined equipmentMap for cleaner code
      equipmentName: equipmentMap?['name'] ?? 'Unknown Equipment',
      equipmentImageUrl: equipmentMap?['image_url'] as String?, // ✅ Correct: equipmentMap is now in scope
      borrowDate: DateTime.parse(map['borrow_date']),
      returnDate: DateTime.parse(map['return_date']),
      purpose: map['purpose'],
      status: map['status'],
      createdAt: DateTime.parse(map['created_at']),
      modificationCount: map['modification_count'] ?? 0,
      rejectionReason: map['rejection_reason'] as String?,
    );
  }
}