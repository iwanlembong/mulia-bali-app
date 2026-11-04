import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/reservation_model.dart';
import '../../core/services/reservation_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/review_service.dart'; // ✅ 1. TAMBAHKAN IMPORT INI
import '../../core/widgets/review_modal.dart';    // ✅ 1. TAMBAHKAN IMPORT INI

class ReservationDetailScreen extends StatefulWidget {
  final String reservationId;

  const ReservationDetailScreen({super.key, required this.reservationId});

  @override
  State<ReservationDetailScreen> createState() => _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  bool _isLoading = true;
  Reservation? _reservation;
  bool _isCancelling = false;
  
  // ✅ 2. TAMBAHKAN STATE UNTUK MENYIMPAN ID KAMAR YANG SUDAH DIREVIEW
  Set<String> _reviewedItemIds = {};

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    final data = await ReservationService.getReservationById(widget.reservationId);
    
    // ✅ 3. AMBIL DATA REVIEW SAAT FETCH DETAIL
    final reviewedIds = await ReviewService.getUserReviewedItemIds();

    if (mounted) {
      setState(() {
        _reservation = data;
        _reviewedItemIds = reviewedIds; // ✅ SIMPAN KE STATE
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Reservation'),
        content: const Text(
          'Are you sure you want to cancel this room reservation? This action cannot be undone.',
          style: TextStyle(fontFamily: 'Lato'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Reservation'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);
    final success = await ReservationService.cancelReservation(_reservation!.id);

    if (mounted) {
      setState(() => _isCancelling = false);
      if (success) {
        _fetchDetail(); // Refresh UI
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reservation cancelled successfully'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel reservation'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
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
        backgroundColor: AppColors.offWhite,
        appBar: AppBar(backgroundColor: AppColors.darkCharcoal, foregroundColor: Colors.white),
        body: const Center(child: Text('Reservation not found', style: TextStyle(fontFamily: 'Lato', color: AppColors.textGrey))),
      );
    }

    final res = _reservation!;
    final nights = res.checkOut.difference(res.checkIn).inDays;

    final int discountAmount = res.discountAmount ?? 0;
    final int voucherDiscountAmount = res.voucherDiscountAmount ?? 0;
    final int originalSubtotal = res.totalAmount + discountAmount + voucherDiscountAmount;
    final bool hasDiscount = discountAmount > 0 || voucherDiscountAmount > 0;

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
            // Status Badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: (res.status == 'pending' ? Colors.orange : (res.status == 'confirmed' ? Colors.green : Colors.grey)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  res.status.toUpperCase(),
                  style: TextStyle(
                    color: res.status == 'pending' ? Colors.orange.shade700 : (res.status == 'confirmed' ? Colors.green.shade700 : Colors.grey.shade700),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Lato',
                    letterSpacing: 1,
                  ),
                ),
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
                  _buildDetailRow(Icons.confirmation_num, 'Reservation No.', res.reservationNumber),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.calendar_today, 'Check-in', DateFormat('dd MMMM yyyy, EEEE').format(res.checkIn)),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.calendar_today_outlined, 'Check-out', DateFormat('dd MMMM yyyy, EEEE').format(res.checkOut)),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.nights_stay, 'Duration', '$nights Night${nights > 1 ? 's' : ''}'),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.people, 'Guests', '${res.adults} Adults, ${res.children} Children'),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.meeting_room, 'Rooms', '${res.roomCount} Room(s)'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Pricing Card
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pricing Details', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('IDR ${_formatPrice(res.pricePerNight)} x $nights nights x ${res.roomCount} room(s)', style: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.textGrey)),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'IDR ${_formatPrice(originalSubtotal)}',
                        style: TextStyle(fontFamily: 'Lato', fontSize: 14, color: AppColors.darkCharcoal, decoration: hasDiscount ? TextDecoration.lineThrough : TextDecoration.none),
                      ),
                    ],
                  ),
                  if (discountAmount > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Discount (${res.promoCode ?? '-'})', style: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: Colors.green)),
                        Text('- IDR ${_formatPrice(discountAmount)}', style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ],
                  if (voucherDiscountAmount > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Voucher Loyalty Discount', style: TextStyle(fontFamily: 'Lato', fontSize: 13, color: Colors.purple)),
                        Text('- IDR ${_formatPrice(voucherDiscountAmount)}', style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount', style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                      Text('IDR ${_formatPrice(res.totalAmount)}', style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryGold)),
                    ],
                  ),
                ],
              ),
            ),

            if (res.specialRequests != null && res.specialRequests!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Special Requests', style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                    const SizedBox(height: 8),
                    Text(res.specialRequests!, style: const TextStyle(fontFamily: 'Lato', fontSize: 14, color: AppColors.textGrey, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            if (res.status == 'cancelled' && res.rejectionReason != null && res.rejectionReason!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [Icon(Icons.error_outline, color: Colors.red.shade700, size: 24), const SizedBox(width: 8), const Text('Reservation Cancelled by Admin', style: TextStyle(fontFamily: 'Lato', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red))],
                    ),
                    const SizedBox(height: 8),
                    Text('Reason: ${res.rejectionReason}', style: const TextStyle(fontFamily: 'Lato', fontSize: 14, color: Colors.red, height: 1.5)),
                    const SizedBox(height: 8),
                    const Text('Please contact our concierge or make a new reservation with the correct payment details.', style: TextStyle(fontFamily: 'Lato', fontSize: 12, color: AppColors.textGrey, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            const SizedBox(height: 32),

            if (res.status == 'pending') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await context.push<bool>('/payment-instruction/${res.id}');
                    if (result == true && mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('PAY NOW / UPLOAD PROOF', style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ),
              const SizedBox(height: 12),
              if (!_isCancelling)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _handleCancel,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('CANCEL RESERVATION', style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
              if (_isCancelling)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.primaryGold))),
            ],

            if (res.status == 'confirmed' || res.status == 'completed' || res.status == 'checked_in') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating Invoice...')));
                    try {
                      await PdfService.generateReservationInvoice(res);
                    } catch (e) {
                      print('❌ Error generating PDF: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate invoice.'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('DOWNLOAD INVOICE', style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.darkCharcoal, side: const BorderSide(color: AppColors.darkCharcoal), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ),
            ],

            // ✅ 4. BARU: LOGIKA TOMBOL REVIEW (Hanya untuk Completed)
            if (res.status == 'completed') ...[
              const SizedBox(height: 16),
              
              if (_reviewedItemIds.contains(res.propertyId))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'REVIEWED',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) => ReviewModal(
                          itemType: 'property', // Tipe untuk kamar hotel
                          itemId: res.propertyId, // ✅ Menggunakan Property ID
                          onReviewSubmitted: () {
                            Navigator.pop(context);
                            _fetchDetail(); // Refresh halaman detail
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Thank you for your review!'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.rate_review, size: 18),
                    label: const Text(
                      'WRITE A REVIEW',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGold,
                      side: const BorderSide(color: AppColors.primaryGold),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
}