import 'package:flutter/material.dart';

// New model class to match the data from Supabase
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
  });

  Color getStatusColor() {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'returned':
        return Colors.green;
      case 'rejected':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  factory BorrowRequest.fromMap(Map<String, dynamic> map) {
    return BorrowRequest(
      requestId: map['request_id'],
      borrowerId: map['borrower_id'],
      equipmentId: map['equipment_id'],
      equipmentName: map['equipment']?['name'] ?? 'Unknown Equipment',
      borrowDate: DateTime.parse(map['borrow_date']),
      returnDate: DateTime.parse(map['return_date']),
      purpose: map['purpose'],
      status: map['status'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
