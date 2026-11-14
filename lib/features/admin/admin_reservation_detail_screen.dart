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

  // ✅ BARU: Hitung sisa yang belum dibayar
  int get _outstandingBalance {
    if (_reservation == null) return 0;
    final balance = _reservation!.totalAmount - _totalPaid;
    return balance > 0 ? balance : 0;
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
            // ✅ BARU: Guest & Stay Dossier (Premium)
            _buildGuestStayDossier(res, nights),
            const SizedBox(height: 24),

            // ✅ BARU: Premium Payment Summary
            _buildPremiumPaymentSummary(res, nights),
            const SizedBox(height: 24),

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

            // ✅ BARU: Premium Payment History Card
            _buildPremiumPaymentHistoryCard(),
            const SizedBox(height: 32),

            // ✅ ACTION BUTTONS (DIPERBAIKI)
            _buildActionButtons(res),
          ],
        ),
      ),
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

  // ✅ WIDGET 1: Guest & Stay Dossier Premium
  Widget _buildGuestStayDossier(Reservation res, int nights) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryGold.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.hotel_outlined,
                  color: AppColors.primaryGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  res.roomName ?? 'Room',
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkCharcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(res.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  res.status.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(res.status),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: Colors.grey),

          // Grid: Res Number + Duration
          Row(
            children: [
              Expanded(
                child: _buildDossierTile(
                  icon: Icons.confirmation_num_outlined,
                  label: 'Res. Number',
                  value: res.reservationNumber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDossierTile(
                  icon: Icons.nights_stay_outlined,
                  label: 'Duration',
                  value: '$nights Night(s)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Grid: Check-in + Check-out
          Row(
            children: [
              Expanded(
                child: _buildDossierTile(
                  icon: Icons.login,
                  label: 'Check-in',
                  value: DateFormat('dd MMM yyyy').format(res.checkIn),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDossierTile(
                  icon: Icons.logout,
                  label: 'Check-out',
                  value: DateFormat('dd MMM yyyy').format(res.checkOut),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Grid: Guests + Rooms
          Row(
            children: [
              Expanded(
                child: _buildDossierTile(
                  icon: Icons.people_alt_outlined,
                  label: 'Guests',
                  value: '${res.adults} Adt, ${res.children} Chd',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDossierTile(
                  icon: Icons.meeting_room_outlined,
                  label: 'Rooms',
                  value: '${res.roomCount} Room(s)',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, color: Colors.grey),
          const SizedBox(height: 16),

          // Guest Identity
          const Text(
            'Guest Identity',
            style: TextStyle(
              fontFamily: 'Lato',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textGrey,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          _buildIdentityRow(
            Icons.person_outline,
            res.guestName ?? 'Unknown Guest',
          ),
          const SizedBox(height: 6),
          _buildIdentityRow(Icons.email_outlined, res.guestEmail ?? 'No Email'),

          // Special Requests (jika ada)
          if (res.specialRequests != null &&
              res.specialRequests!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Special Request',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          res.specialRequests!,
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 12,
                            color: AppColors.darkCharcoal,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ✅ WIDGET 2: Premium Payment Summary (Dark + Gold)
  Widget _buildPremiumPaymentSummary(Reservation res, int nights) {
    final int discountAmount = res.discountAmount ?? 0;
    final int voucherDiscountAmount = res.voucherDiscountAmount ?? 0;
    final int originalSubtotal =
        res.totalAmount + discountAmount + voucherDiscountAmount;
    final bool hasDiscount = discountAmount > 0 || voucherDiscountAmount > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkCharcoal,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Summary',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 16,
              color: Colors.white70,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),

          // Rate Breakdown
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'IDR ${_formatPrice(res.pricePerNight)} × $nights nights × ${res.roomCount} room(s)',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'IDR ${_formatPrice(originalSubtotal)}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  decoration: hasDiscount
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
            ],
          ),

          // Promo Discount
          if (discountAmount > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Promo (${res.promoCode ?? 'Code'})',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '- IDR ${_formatPrice(discountAmount)}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],

          // Voucher Discount
          if (voucherDiscountAmount > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Voucher Loyalty',
                  style: TextStyle(color: Colors.purpleAccent, fontSize: 12),
                ),
                Text(
                  '- IDR ${_formatPrice(voucherDiscountAmount)}',
                  style: const TextStyle(
                    color: Colors.purpleAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],

          const Divider(height: 32, color: Colors.white24),

          // TOTAL DUE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL DUE',
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'IDR ${_formatPrice(res.totalAmount)}',
                style: const TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGold,
                ),
              ),
            ],
          ),          
        ],
      ),
    );
  }

  // ✅ WIDGET 3: Premium Payment History Card
  Widget _buildPremiumPaymentHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.primaryGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Payment History',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkCharcoal,
                ),
              ),
              const Spacer(),
              if (!_isLoadingPayments && _payments.isNotEmpty)
                Text(
                  '${_payments.where((p) => p.isVerified).length} verified',
                  style: TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
            ],
          ),
          const Divider(height: 28, color: Colors.grey),

          if (_isLoadingPayments)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.primaryGold),
              ),
            )
          else if (_payments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'No payments recorded yet.',
                style: TextStyle(color: AppColors.textGrey, fontFamily: 'Lato'),
                textAlign: TextAlign.center,
              ),
            )
          else
            Column(
              children: [
                ..._payments.map(
                  (payment) => _buildPaymentTileWithActions(payment),
                ),

                // ✅ Outstanding Balance Card (Orange)
                if (_outstandingBalance > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange.shade50, Colors.orange.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Outstanding Balance',
                                style: TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Remaining to be paid',
                                style: TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 10,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'IDR ${_formatPrice(_outstandingBalance)}',
                          style: const TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  )
                // ✅ Fully Paid Card (Green)
                else if (_payments.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade50, Colors.green.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FULLY PAID',
                                style: TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'All payments verified',
                                style: TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 10,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // ✅ WIDGET 4: Payment Tile dengan Tombol Verify/Reject (Fitur Khas Reservation)
  Widget _buildPaymentTileWithActions(OrderPayment payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: payment.status == 'pending'
            ? Colors.orange.shade50
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: payment.isVerified
              ? Colors.green.shade100
              : (payment.isRejected
                    ? Colors.red.shade100
                    : Colors.orange.shade200),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: payment.statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              payment.isVerified
                  ? Icons.check_circle_outline
                  : (payment.isRejected
                        ? Icons.cancel_outlined
                        : Icons.hourglass_empty),
              color: payment.statusColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.paymentType,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Lato',
                    color: AppColors.darkCharcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  payment.formattedDate,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
                if (payment.isRejected && payment.rejectionReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Note: ${payment.rejectionReason}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ✅ Tombol aksi untuk payment pending
          if (payment.status == 'pending')
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _verifyPayment(payment.id),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _rejectPayment(payment.id),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  payment.formattedAmount,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Playfair Display',
                    color: AppColors.darkCharcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
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
        ],
      ),
    );
  }

  // ✅ Helper: Tile kecil untuk Dossier
  Widget _buildDossierTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textGrey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.darkCharcoal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ✅ Helper: Baris identitas guest
  Widget _buildIdentityRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primaryGold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Lato',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.darkCharcoal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
