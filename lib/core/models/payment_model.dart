import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class OrderPayment {
  final String id;
  final String? orderId;
  final String? reservationId;
  final int amount;
  final String paymentType;
  final String paymentProofUrl;
  final DateTime paymentDate;
  final String status;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? rejectionReason;
  final DateTime createdAt;

  OrderPayment({
    required this.id,
    this.orderId,
    this.reservationId,
    required this.amount,
    required this.paymentType,
    required this.paymentProofUrl,
    required this.paymentDate,
    required this.status,
    this.verifiedBy,
    this.verifiedAt,
    this.rejectionReason,
    required this.createdAt,
  });

  // ✅ Factory untuk mengubah Map (dari Supabase) menjadi Object OrderPayment
  factory OrderPayment.fromMap(Map<String, dynamic> map) {
    return OrderPayment(
      id: map['id'] as String,
      orderId: map['order_id'] as String?,
      reservationId: map['reservation_id'] as String?,
      // ⚠️ SAFE CASTING: BIGINT di Supabase kadang jadi String, kadang int. Kita amankan keduanya.
      amount: map['amount'] is int 
          ? map['amount'] as int 
          : int.parse(map['amount'].toString()),
      paymentType: map['payment_type'] as String? ?? 'DP',
      paymentProofUrl: map['payment_proof_url'] as String,
      paymentDate: DateTime.parse(map['payment_date'] as String),
      status: map['status'] as String? ?? 'pending',
      verifiedBy: map['verified_by'] as String?,
      verifiedAt: map['verified_at'] != null ? DateTime.parse(map['verified_at'] as String) : null,
      rejectionReason: map['rejection_reason'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // ✅ Helper: Format Nominal ke Rupiah
  String get formattedAmount {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'IDR ', decimalDigits: 0).format(amount);
  }

  // ✅ Helper: Format Tanggal
  String get formattedDate {
    return DateFormat('dd MMM yyyy').format(paymentDate);
  }

  // ✅ Helper: Warna Status (untuk UI)
  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'verified':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      default: // pending
        return Colors.orange.shade700;
    }
  }

  // ✅ Helper: Label Status (Huruf kapital di awal)
  String get statusLabel {
    return status.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  // ✅ Helper: Cek apakah sudah diverifikasi
  bool get isVerified => status.toLowerCase() == 'verified';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isRejected => status.toLowerCase() == 'rejected';

  // ✅ Convert kembali ke Map (jika perlu untuk update/insert)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'reservation_id': reservationId,
      'amount': amount,
      'payment_type': paymentType,
      'payment_proof_url': paymentProofUrl,
      'payment_date': paymentDate.toIso8601String().split('T').first,
      'status': status,
      'verified_by': verifiedBy,
      'verified_at': verifiedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}