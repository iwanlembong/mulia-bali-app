import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/order_model.dart';
import '../../core/services/order_service.dart';
import '../../core/services/email_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/review_service.dart'; // ✅ TAMBAHKAN INI
import '../../core/widgets/review_modal.dart'; // ✅ TAMBAHKAN INI

// ✅ TAMBAHKAN BARIS INI:
import '../booking/booking_payment_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isLoading = true;
  Order? _order;

  bool _isCancelling = false; // ✅ BARU

  // ✅ TAMBAHKAN BARIS INI DI SINI:
  Set<String> _reviewedItemIds = {}; 

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'IDR ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchOrder();
  }

  Future<void> _fetchOrder() async {
    setState(() => _isLoading = true);
    final order = await OrderService.getOrderById(widget.orderId);
    // ✅ 1. AMBIL DATA REVIEW DARI DATABASE
    final reviewedIds = await ReviewService.getUserReviewedItemIds();

    if (mounted) {
      setState(() {
        _order = order;
        _reviewedItemIds = reviewedIds; // ✅ 2. SIMPAN KE VARIABEL STATE
        _isLoading = false;
      });

      // ✅ DEBUG PRINT
      print('🔍 [DEBUG] Order loaded:');
      print('   Total Amount: ${_order!.totalAmount}');
      print('   Discount Amount: ${_order!.discountAmount}');
      print('   Promo Code: ${_order!.promoCode}');
    }
  }

  // ✅ METHOD BARU: Navigasi ke halaman pembayaran
  Future<void> _handlePayNow() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingPaymentScreen(orderId: _order!.id),
      ),
    );

    // Jika upload berhasil (mengembalikan true), refresh halaman detail ini
    if (result == true && mounted) {
      _fetchOrder();
    }
  }

  Future<void> _handleCancelOrder() async {
    // ✅ 1. Konfirmasi dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text(
          'Are you sure you want to cancel this booking? This action cannot be undone.',
          style: TextStyle(fontFamily: 'Lato'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // ✅ 2. Tampilkan loading
    setState(() => _isCancelling = true);

    // ✅ 3. Panggil service untuk cancel
    final success = await OrderService.cancelOrder(_order!.id);

    if (mounted) {
      setState(() => _isCancelling = false);

      if (success) {
        // ✅ KIRIM EMAIL CANCELLATION (User initiated)
        if (_order!.userEmail != null &&
            _order!.userEmail!.isNotEmpty &&
            _order!.userEmail != 'No Email') {
          final guestName = _order!.userName ?? 'Valued Guest';
          final htmlContent = EmailService.generateStatusUpdateTemplate(
            _order!,
            guestName,
            'cancelled',
          );

          print(
            '📧 [USER] Mengirim email cancellation ke: ${_order!.userEmail}',
          );
          EmailService.sendEmail(
            to: _order!.userEmail!,
            subject: 'Booking Cancelled - ${_order!.orderNumber}',
            htmlContent: htmlContent,
          );
        }

        // ✅ 4. Refresh data order
        _fetchOrder();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel booking. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ HELPER: Membangun UI berdasarkan status pembayaran untuk order pending
  Widget _buildPendingActions() {
    final hasProof =
        _order!.paymentProofUrl != null && _order!.paymentProofUrl!.isNotEmpty;
    final rejectionReason = _order!.rejectionReason;

    // ✅ KONDISI 1: Ada Bukti TAPI Ada Catatan Revisi dari Admin
    if (hasProof && rejectionReason != null && rejectionReason.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50, // Merah muda untuk peringatan
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 24),
                SizedBox(width: 12),
                Text(
                  'Revision Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 16,
                    fontFamily: 'Playfair Display',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Admin Note:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade900,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              rejectionReason, // Tampilkan alasan admin
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 14,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handlePayNow, // Arahkan ke halaman upload ulang
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text(
                  'RE-UPLOAD PAYMENT PROOF',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ✅ KONDISI 2: Ada Bukti, Belum Diverifikasi (Normal)
    if (hasProof) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.hourglass_empty, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Awaiting Admin Verification',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                      fontSize: 16,
                      fontFamily: 'Playfair Display',
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Payment proof has been sent. The admin will process your booking shortly.',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 13,
                      fontFamily: 'Lato',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ✅ KONDISI 3: Belum Upload Bukti (Tombol Pay & Cancel)
    if (!_isCancelling) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handlePayNow,
              icon: const Icon(Icons.payment_outlined),
              label: const Text(
                'PAY NOW',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _handleCancelOrder,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text(
                'CANCEL BOOKING',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange.shade700;
      case 'confirmed':
        return Colors.blue.shade700;
      case 'completed':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return AppColors.textGrey;
    }
  }

  IconData _getItemTypeIcon(String itemType) {
    switch (itemType) {
      case 'spa':
        return Icons.spa;
      case 'dining':
        return Icons.restaurant;
      case 'wedding':
        return Icons.favorite;
      default:
        return Icons.shopping_bag;
    }
  }

  Color _getItemTypeColor(String itemType) {
    switch (itemType) {
      case 'spa':
        return const Color(0xFF8B7355);
      case 'dining':
        return const Color(0xFF6B8E23);
      case 'wedding':
        return Colors.pink.shade600;
      default:
        return AppColors.primaryGold;
    }
  }

  String _getItemTypeLabel(String itemType) {
    switch (itemType) {
      case 'spa':
        return 'SPA & WELLNESS';
      case 'dining':
        return 'DINING';
      case 'wedding':
        return 'WEDDING';
      default:
        return 'SERVICE';
    }
  }

  String _formatMetadata(OrderItem item) {
    final meta = item.metadata;
    final parts = <String>[];

    // Spa: date, time, duration
    if (item.itemType == 'spa') {
      if (meta['date'] != null) parts.add('📅 ${meta['date']}');
      if (meta['time'] != null) parts.add('🕐 ${meta['time']}');
      if (meta['duration'] != null) parts.add('⏱️ ${meta['duration']} mins');
    }
    // Dining: date, time, guests, restaurant
    else if (item.itemType == 'dining') {
      if (meta['date'] != null) parts.add('📅 ${meta['date']}');
      if (meta['time'] != null) parts.add('🕐 ${meta['time']}');
      if (meta['guests'] != null) parts.add('👥 ${meta['guests']} guests');
      if (meta['restaurant_name'] != null)
        parts.add('🍽️ ${meta['restaurant_name']}');
    }
    // Wedding: event_date, guests, venue
    else if (item.itemType == 'wedding') {
      if (meta['event_date'] != null) parts.add('📅 ${meta['event_date']}');
      if (meta['guests'] != null) parts.add('👥 ${meta['guests']} guests');
      if (meta['venue_preference'] != null)
        parts.add(' ${meta['venue_preference']}');
    }

    return parts.isEmpty ? '' : parts.join('  •  ');
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

    if (_order == null) {
      return Scaffold(
        backgroundColor: AppColors.offWhite,
        appBar: AppBar(
          backgroundColor: AppColors.darkCharcoal,
          foregroundColor: Colors.white,
          title: const Text('Order Details'),
        ),
        body: const Center(child: Text('Order not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        title: const Text(
          'Order Details',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Order Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ORDER NUMBER',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 10,
                          color: AppColors.textGrey,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(_order!.status)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _order!.statusLabel,
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(_order!.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _order!.orderNumber,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Booking Date',
                    _order!.formattedDate,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.access_time,
                    'Order Time',
                    DateFormat('HH:mm').format(_order!.orderDate),
                  ),
                  if (_order!.notes != null && _order!.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.note, 'Notes', _order!.notes!),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ✅ Items Header
            const Text(
              'Booked Items',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 12),

            // ✅ Items List
            if (_order!.items.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'No items in this order.',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
              )
            else
              // ✅ DIPERBARUI: Mengirimkan reviewedIds dan callback review
              ..._order!.items.map((item) => _buildItemCard(
                item, 
                _reviewedItemIds, 
                () {
                  // ✅ Callback saat tombol review item diklik
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) => ReviewModal(
                      itemType: item.itemType, // ✅ Kirim tipe item spesifik (spa/dining/wedding)
                      itemId: item.itemId,     // ✅ Kirim ID item spesifik
                      onReviewSubmitted: () {
                        _fetchOrder(); // Refresh halaman
                      },
                    ),
                  );
                }
              )).toList(),

            const SizedBox(height: 24),

            // ✅ Total Summary dengan Rincian Promo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.darkCharcoal,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Subtotal (Harga Awal sebelum diskon)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(
                          _order!.totalAmount +
                              _order!.discountAmount +
                              _order!.voucherDiscountAmount,
                        ),
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 14,
                          color: Colors.white,
                          decoration:
                              (_order!.discountAmount > 0 ||
                                  _order!.voucherDiscountAmount > 0)
                              ? TextDecoration
                                    .lineThrough // Coret jika ada diskon
                              : TextDecoration.none,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 2. Diskon Promo Code (Hanya muncul jika ada)
                  if (_order!.discountAmount > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Discount (${_order!.promoCode ?? 'Promo'})',
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 13,
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '- ${_currencyFormat.format(_order!.discountAmount)}',
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 14,
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 3. Diskon Voucher (Hanya muncul jika ada)
                  if (_order!.voucherDiscountAmount > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Voucher Discount',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 13,
                            color: Colors.purple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '- ${_currencyFormat.format(_order!.voucherDiscountAmount)}',
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 14,
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 4. Divider (Hanya sekali sebelum Total)
                  const Divider(height: 1, color: Colors.white24),
                  const SizedBox(height: 12),

                  // 5. Total Akhir (Amount yang harus dibayar)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL AMOUNT',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(_order!.totalAmount),
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
            ),

            const SizedBox(height: 24),

            // ✅ BAGIAN ACTION BUTTONS (PAY NOW / WAITING / CANCEL)
            if (_order!.status == 'pending') _buildPendingActions(),

            // ✅ 2. BARU: Jika status Confirmed atau Completed (Download Invoice)
            if (_order!.status == 'confirmed' ||
                _order!.status == 'completed') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    // Tampilkan feedback loading sederhana
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Generating Invoice...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );

                    try {
                      // Panggil service PDF yang sudah kita buat
                      await PdfService.generateOrderInvoice(_order!);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invoice berhasil dibuat!'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      print('❌ Error generating PDF: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Failed to create invoice. Try again.',
                            ),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text(
                    'DOWNLOAD INVOICE',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkCharcoal,
                    side: const BorderSide(color: AppColors.darkCharcoal),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],          

            // ✅ Loading indicator saat cancelling
            if (_isCancelling)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGold,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // ✅ Contact Support
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryGold.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.help_outline,
                    color: AppColors.primaryGold,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Need help with your booking?',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Contact our concierge team for assistance.',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 11,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.email_outlined,
                      color: AppColors.primaryGold,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Contact feature coming soon'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }


  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 11,
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

  // ✅ DIPERBARUI: Tambahkan parameter reviewedIds dan onReviewPressed
  Widget _buildItemCard(
    OrderItem item,
    Set<String> reviewedIds,
    VoidCallback onReviewPressed,
  ) {
    final metadata = _formatMetadata(item);
    final color = _getItemTypeColor(item.itemType);

    // ✅ CEK STATUS REVIEW UNTUK ITEM INI
    final isReviewed = reviewedIds.contains(item.itemId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Type Badge + Item Name
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getItemTypeIcon(item.itemType),
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getItemTypeLabel(item.itemType),
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.itemName,
                        style: const TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '× ${item.quantity}',
                  style: const TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),

            // Metadata
            if (metadata.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.offWhite,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  metadata,
                  style: const TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 12,
                    color: AppColors.textGrey,
                    height: 1.5,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_currencyFormat.format(item.unitPrice)} × ${item.quantity}',
                  style: const TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
                Text(
                  _currencyFormat.format(item.totalPrice),
                  style: TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),

            // ✅ BARU: TOMBOL REVIEW DI DALAM SETIAP ITEM CARD
            if (_order!.status == 'completed') ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              if (isReviewed)
                // ✅ TAMPILAN JIKA ITEM INI SUDAH DIREVIEW
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'REVIEWED',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                // ✅ TAMPILAN JIKA ITEM INI BELUM DIREVIEW
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        onReviewPressed, // ✅ Panggil callback dari parent
                    icon: const Icon(Icons.rate_review, size: 16),
                    label: const Text(
                      'WRITE A REVIEW',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGold,
                      side: const BorderSide(color: AppColors.primaryGold),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
