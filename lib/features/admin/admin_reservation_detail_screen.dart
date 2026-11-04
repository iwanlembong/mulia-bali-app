import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/reservation_model.dart';
import '../../core/services/reservation_service.dart';

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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold),
            child: const Text('Yes, Update', style: TextStyle(color: Colors.white)),
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
          _fetchDetail();
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
            child: const Text('Yes, Complete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ReservationService.completeReservation(reservationId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check-out successful! Loyalty points awarded.'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchDetail();
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

  // ✅ BARU: Helper untuk warna status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange.shade700;
      case 'confirmed': return Colors.green.shade700;
      case 'checked_in': return Colors.blue.shade700;
      case 'checked_out': return Colors.grey.shade700;
      case 'cancelled': return Colors.red.shade700;
      case 'completed': return Colors.teal.shade700;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
      );
    }
    if (_reservation == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppColors.darkCharcoal, foregroundColor: Colors.white),
        body: const Center(child: Text('Reservation not found', style: TextStyle(fontFamily: 'Lato', color: AppColors.textGrey))),
      );
    }

    final res = _reservation!;
    final nights = res.checkOut.difference(res.checkIn).inDays;

    // ✅ 1. Hitung Variabel Diskon untuk Audit
    final int discountAmount = res.discountAmount ?? 0;
    final int voucherDiscountAmount = res.voucherDiscountAmount ?? 0;
    final int originalSubtotal = res.totalAmount + discountAmount + voucherDiscountAmount;
    final bool hasDiscount = discountAmount > 0 || voucherDiscountAmount > 0;
    final Color statusColor = _getStatusColor(res.status);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        title: const Text(
          'Reservation Details',
          style: TextStyle(fontFamily: 'Playfair Display', fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge (Dinamis)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  res.status.toUpperCase(), // ✅ Diperbaiki dari statusLabel
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
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Guest Information', style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.person, 'Name', res.guestName ?? 'Unknown Guest'),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.email_outlined, 'Email Address', res.guestEmail ?? 'No Email'),
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
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(res.roomName ?? 'Room', style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.confirmation_num, 'Res. Number', res.reservationNumber),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.calendar_today, 'Check-in', DateFormat('dd MMMM yyyy').format(res.checkIn)),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.calendar_today_outlined, 'Check-out', DateFormat('dd MMMM yyyy').format(res.checkOut)),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.nights_stay, 'Duration', '$nights Night(s)'),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.people, 'Guests', '${res.adults} Adults, ${res.children} Children'),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.meeting_room, 'Rooms', '${res.roomCount} Room(s)'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ✅ 2. BARU: Pricing & Audit Details Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pricing & Audit Details',
                    style: TextStyle(fontFamily: 'Playfair Display', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal),
                  ),
                  const SizedBox(height: 16),

                  // A. Subtotal (Perhitungan Dasar)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'IDR ${_formatPrice(res.pricePerNight)} x $nights nights x ${res.roomCount} room(s)',
                          style: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.textGrey),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'IDR ${_formatPrice(originalSubtotal)}',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 14,
                          color: AppColors.darkCharcoal,
                          decoration: hasDiscount ? TextDecoration.lineThrough : TextDecoration.none,
                        ),
                      ),
                    ],
                  ),

                  // B. Diskon Promo (Jika Ada)
                  if (discountAmount > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Promo Code: ${res.promoCode ?? '-'}',
                          style: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '- IDR ${_formatPrice(discountAmount)}',
                          style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ],

                  // C. Diskon Voucher Loyalty (Jika Ada)
                  if (voucherDiscountAmount > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Voucher Loyalty Discount',
                          style: TextStyle(fontFamily: 'Lato', fontSize: 13, color: Colors.purple, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '- IDR ${_formatPrice(voucherDiscountAmount)}',
                          style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple),
                        ),
                      ],
                    ),
                    // Tampilkan ID Voucher untuk keperluan audit admin
                    if (res.voucherId != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Voucher DB ID: ${res.voucherId}',
                        style: const TextStyle(fontFamily: 'Lato', fontSize: 10, color: AppColors.textGrey, fontStyle: FontStyle.italic),
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ],

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // D. Total Akhir
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'FINAL TOTAL AMOUNT',
                        style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal),
                      ),
                      Text(
                        'IDR ${_formatPrice(res.totalAmount)}',
                        style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryGold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (res.specialRequests != null && res.specialRequests!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Special Requests', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Lato', fontSize: 14, color: AppColors.darkCharcoal)),
                    const SizedBox(height: 8),
                    Text(
                      res.specialRequests!,
                      style: const TextStyle(fontFamily: 'Lato', color: AppColors.textGrey, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Action Buttons (Dynamic based on status)
            _buildActionButtons(res),
          ],
        ),
      ),
    );
  }

  // ✅ Helper untuk Guest Info
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryGold),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontFamily: 'Lato', fontSize: 12, color: AppColors.textGrey)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkCharcoal)),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ Helper untuk Room Info
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryGold),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(fontFamily: 'Lato', fontSize: 12, color: AppColors.textGrey)),
        ),
        Text(value, style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkCharcoal)),
      ],
    );
  }

  Widget _buildActionButtons(Reservation res) {
    List<Widget> buttons = [];

    if (res.status == 'pending') {
      buttons.add(_buildButton('CONFIRM RESERVATION', Colors.green, () => _updateStatus('confirmed')));
      buttons.add(_buildButton('CANCEL RESERVATION', Colors.red, () => _updateStatus('cancelled')));
    } else if (res.status == 'confirmed') {
      buttons.add(_buildButton('CHECK IN GUEST', Colors.blue, () => _updateStatus('checked_in')));
    } else if (res.status == 'checked_in') {
      buttons.add(_buildButton('CHECK OUT & COMPLETE', Colors.teal, () => _completeReservation(res.id)));
    } else if (res.status == 'completed' || res.status == 'cancelled') {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('This reservation is already finalized.', style: TextStyle(fontFamily: 'Lato', color: AppColors.textGrey, fontStyle: FontStyle.italic)),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      children: buttons.map((btn) => Padding(padding: const EdgeInsets.only(bottom: 12), child: btn)).toList(),
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
        child: Text(text, style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }
}