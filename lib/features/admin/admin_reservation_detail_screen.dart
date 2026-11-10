import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/reservation_model.dart';
import '../../core/models/payment_model.dart'; // ✅ BARU
import '../../core/services/reservation_service.dart';
import '../../core/services/payment_service.dart'; // ✅ BARU

class AdminReservationDetailScreen extends StatefulWidget {
  final String reservationId;
  const AdminReservationDetailScreen({super.key, required this.reservationId});

  @override
  State<AdminReservationDetailScreen> createState() =>
      _AdminReservationDetailScreenState();
}

class _AdminReservationDetailScreenState
    extends State<AdminReservationDetailScreen> {
  bool _isLoading = true;
  Reservation? _reservation;

  // ✅ BARU: State untuk Payment History
  List<OrderPayment> _payments = [];
  bool _isLoadingPayments = true;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    final data = await ReservationService.getReservationById(
      widget.reservationId,
    );
    if (mounted) {
      setState(() {
        _reservation = data;
        _isLoading = false;
      });
      // ✅ Fetch payments setelah data reservasi didapat
      _fetchPayments();
    }
  }

  // ✅ 1. Ambil Payment History
  Future<void> _fetchPayments() async {
    if (_reservation == null) return;
    setState(() => _isLoadingPayments = true);

    final payments = await PaymentService.getPaymentsByReservationId(
      _reservation!.id,
    );

    if (mounted) {
      setState(() {
        _payments = payments;
        _isLoadingPayments = false;
      });
    }
  }

  // ✅ 2. Hitung Total yang Sudah Dibayar (Verified)
  int get _totalPaid {
    return _payments
        .where((p) => p.status.toLowerCase() == 'verified')
        .fold(0, (sum, item) => sum + item.amount);
  }

  // ✅ 3. Cek Apakah Sudah Fully Paid
  bool get _isFullyPaid {
    if (_reservation == null) return false;
    return _totalPaid >= _reservation!.totalAmount;
  }

  // ✅ 4. Verifikasi Pembayaran (Approve)
  Future<void> _verifyPayment(String paymentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Payment'),
        content: const Text('Are you sure you want to verify this payment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Verify', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await PaymentService.updatePaymentStatus(paymentId, 'verified');

      // Auto-confirm reservation jika sudah fully paid
      if (_isFullyPaid) {
        await ReservationService.updateReservationStatus(
          _reservation!.id,
          'confirmed',
        );
      }

      if (mounted) {
        await _fetchPayments();
        await _fetchDetail();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verified!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // ✅ 5. Reject Payment
  Future<void> _rejectPayment(String paymentId) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g., Transfer amount incorrect, blurry proof',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && reasonController.text.isNotEmpty) {
      await PaymentService.updatePaymentStatus(
        paymentId,
        'rejected',
        rejectionReason: reasonController.text,
      );
      if (mounted) {
        await _fetchPayments();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Action'),
        content: Text(
          'Are you sure you want to change status to $newStatus?\nAn email will be sent to the guest.',
          style: const TextStyle(fontFamily: 'Lato'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
            ),
            child: const Text(
              'Yes, Update',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ReservationService.updateReservationStatus(
        _reservation!.id,
        newStatus,
      );
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status updated to $newStatus & email sent!'),
              backgroundColor: Colors.green,
            ),
          );
          await _fetchDetail();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update status'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _completeReservation(String reservationId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check Out & Complete?'),
        content: const Text(
          'This will mark the reservation as completed and award loyalty points to the guest.',
          style: TextStyle(fontFamily: 'Lato'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text(
              'Yes, Complete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ReservationService.completeReservation(
        reservationId,
      );
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check-out successful! Loyalty points awarded.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
          await _fetchDetail();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to complete reservation'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatPrice(int price) => price.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange.shade700;
      case 'confirmed':
        return Colors.green.shade700;
      case 'checked_in':
        return Colors.blue.shade700;
      case 'checked_out':
        return Colors.grey.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      case 'completed':
        return Colors.teal.shade700;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGold),
        ),
      );
    }
    if (_reservation == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.darkCharcoal,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'Reservation not found',
            style: TextStyle(fontFamily: 'Lato', color: AppColors.textGrey),
          ),
        ),
      );
    }

    final res = _reservation!;
    final nights = res.checkOut.difference(res.checkIn).inDays;

    final int discountAmount = res.discountAmount ?? 0;
    final int voucherDiscountAmount = res.voucherDiscountAmount ?? 0;
    final int originalSubtotal =
        res.totalAmount + discountAmount + voucherDiscountAmount;
    final bool hasDiscount = discountAmount > 0 || voucherDiscountAmount > 0;
    final Color statusColor = _getStatusColor(res.status);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        title: const Text(
          'Reservation Details',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  res.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Lato',
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Guest Information Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Guest Information',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.person,
                    'Name',
                    res.guestName ?? 'Unknown Guest',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.email_outlined,
                    'Email Address',
                    res.guestEmail ?? 'No Email',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Room Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    res.roomName ?? 'Room',
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    Icons.confirmation_num,
                    'Res. Number',
                    res.reservationNumber,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.calendar_today,
                    'Check-in',
                    DateFormat('dd MMMM yyyy').format(res.checkIn),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.calendar_today_outlined,
                    'Check-out',
                    DateFormat('dd MMMM yyyy').format(res.checkOut),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.nights_stay,
                    'Duration',
                    '$nights Night(s)',
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.people,
                    'Guests',
                    '${res.adults} Adults, ${res.children} Children',
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.meeting_room,
                    'Rooms',
                    '${res.roomCount} Room(s)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Pricing & Audit Details Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pricing & Audit Details',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'IDR ${_formatPrice(res.pricePerNight)} x $nights nights x ${res.roomCount} room(s)',
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 13,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'IDR ${_formatPrice(originalSubtotal)}',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 14,
                          color: AppColors.darkCharcoal,
                          decoration: hasDiscount
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                  if (discountAmount > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Promo Code: ${res.promoCode ?? '-'}',
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 13,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '- IDR ${_formatPrice(discountAmount)}',
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (voucherDiscountAmount > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Voucher Loyalty Discount',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 13,
                            color: Colors.purple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '- IDR ${_formatPrice(voucherDiscountAmount)}',
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    if (res.voucherId != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Voucher DB ID: ${res.voucherId}',
                        style: const TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 10,
                          color: AppColors.textGrey,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'FINAL TOTAL AMOUNT',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      Text(
                        'IDR ${_formatPrice(res.totalAmount)}',
                        style: const TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (res.specialRequests != null &&
                res.specialRequests!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Special Requests',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Lato',
                        fontSize: 14,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      res.specialRequests!,
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        color: AppColors.textGrey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ✅ PAYMENT HISTORY (BARU)
            const Text(
              'Payment History',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 12),

            if (_isLoadingPayments)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_payments.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No payments recorded yet.',
                  style: TextStyle(color: AppColors.textGrey),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ..._payments
                  .map(
                    (payment) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            payment.isVerified
                                ? Icons.check_circle
                                : (payment.isRejected
                                      ? Icons.cancel
                                      : Icons.hourglass_empty),
                            color: payment.statusColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${payment.paymentType} • ${payment.formattedDate}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  payment.formattedAmount,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                if (payment.isRejected &&
                                    payment.rejectionReason != null)
                                  Text(
                                    'Note: ${payment.rejectionReason}',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // ✅ TOMBOL AKSI UNTUK PAYMENT PENDING
                          if (payment.status == 'pending') ...[
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              onPressed: () => _verifyPayment(payment.id),
                              tooltip: 'Verify',
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _rejectPayment(payment.id),
                              tooltip: 'Reject',
                            ),
                          ] else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: payment.statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                payment.statusLabel,
                                style: TextStyle(
                                  color: payment.statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),

            const SizedBox(height: 32),

            // ✅ ACTION BUTTONS (DIPERBAIKI)
            _buildActionButtons(res),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryGold),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 12,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkCharcoal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryGold),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Lato',
              fontSize: 12,
              color: AppColors.textGrey,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Lato',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.darkCharcoal,
          ),
        ),
      ],
    );
  }

  // ✅ LOGIKA TOMBOL DINAMIS BARU
  Widget _buildActionButtons(Reservation res) {
    List<Widget> buttons = [];

    if (res.status == 'pending') {
      // ✅ CONFIRM button ONLY jika sudah FULLY PAID
      if (_isFullyPaid) {
        buttons.add(
          _buildButton(
            'CONFIRM RESERVATION',
            Colors.green,
            () => _updateStatus('confirmed'),
          ),
        );
      } else {
        // Tampilkan info jika belum lunas
        buttons.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Waiting for full payment to confirm reservation.',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // ✅ CANCEL button ONLY jika BELUM fully paid
      if (!_isFullyPaid) {
        buttons.add(
          _buildButton(
            'CANCEL RESERVATION',
            Colors.red,
            () => _updateStatus('cancelled'),
          ),
        );
      }
    } else if (res.status == 'confirmed') {
      buttons.add(
        _buildButton(
          'CHECK IN GUEST',
          Colors.blue,
          () => _updateStatus('checked_in'),
        ),
      );
    } else if (res.status == 'checked_in') {
      buttons.add(
        _buildButton(
          'CHECK OUT & COMPLETE',
          Colors.teal,
          () => _completeReservation(res.id),
        ),
      );
    } else if (res.status == 'completed' || res.status == 'cancelled') {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'This reservation is already finalized.',
            style: TextStyle(
              fontFamily: 'Lato',
              color: AppColors.textGrey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      children: buttons
          .map(
            (btn) =>
                Padding(padding: const EdgeInsets.only(bottom: 12), child: btn),
          )
          .toList(),
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Lato',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
