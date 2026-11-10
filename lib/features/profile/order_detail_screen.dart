import 'dart:typed_data'; // ✅ TAMBAHKAN BARIS INI

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/order_model.dart';
import '../../core/models/payment_model.dart'; // ✅ BARU
import '../../core/services/order_service.dart';
import '../../core/services/payment_service.dart'; // ✅ BARU
import '../../core/services/email_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/review_service.dart';
import '../../core/widgets/review_modal.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isLoading = true;
  Order? _order;
  bool _isCancelling = false;
  Set<String> _reviewedItemIds = {};

  // ✅ BARU: State Variables untuk Sistem Pembayaran Multi-Tahap
  List<OrderPayment> _payments = [];
  bool _isLoadingPayments = true;
  final ImagePicker _picker = ImagePicker();
  // ✅ Tambahkan ini di bawah XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isUploadingPayment = false;

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
    final reviewedIds = await ReviewService.getUserReviewedItemIds();

    if (mounted) {
      setState(() {
        _order = order;
        _reviewedItemIds = reviewedIds;
        _isLoading = false;
      });
      // ✅ Fetch pembayaran setelah data order berhasil dimuat
      _fetchPayments();
    }
  }

  // ✅ 1. Ambil Riwayat Pembayaran
  Future<void> _fetchPayments() async {
    if (_order == null) return;
    setState(() => _isLoadingPayments = true);

    List<OrderPayment> payments = [];
    if (_order!.id.isNotEmpty) {
      payments = await PaymentService.getPaymentsByOrderId(_order!.id);
    }

    if (mounted) {
      setState(() {
        _payments = payments;
        _isLoadingPayments = false;
      });
    }
  }

  // ✅ 2. Hitung Total yang Sudah Dibayar (Hanya yang 'verified')
  int get _totalPaid {
    return _payments
        .where((p) => p.status.toLowerCase() == 'verified')
        .fold(0, (sum, item) => sum + item.amount);
  }

  // ✅ 3. Hitung Sisa Tagihan
  int get _remainingBalance {
    final totalOrder = _order?.totalAmount ?? 0;
    final paid = _totalPaid;
    return (totalOrder - paid).clamp(0, totalOrder); // Pastikan tidak minus
  }

  // ✅ 4. CEK: Apakah sudah ada pembayaran yang statusnya 'pending'?
  bool get _hasPendingPayment {
    return _payments.any((p) => p.status.toLowerCase() == 'pending');
  }

  // ✅ 5. METHOD BARU: Upload dari Bytes (Jauh lebih stabil & anti-error)
  Future<void> _submitPayment(int amount, String paymentType) async {
    // 1. Validasi Gambar (Cek _imageBytes, BUKAN _selectedImage)
    if (_imageBytes == null || _imageBytes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload payment proof first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Validasi Nominal
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount must be greater than 0'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 3. Mulai Loading
    setState(() => _isUploadingPayment = true);

    try {
      final fileName = 'pay_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // ✅ UPLOAD LANGSUNG DARI BYTES (Uint8List)
      // Tidak perlu convert ke File lagi. Ini bypass semua masalah permission Android!
      await Supabase.instance.client.storage
          .from('payment_proofs') // ⚠️ PASTIKAN nama bucket sesuai dengan di Supabase Anda (pakai underscore)
          .uploadBinary(fileName, _imageBytes!);

      final proofUrl = Supabase.instance.client.storage
          .from('payment_proofs')
          .getPublicUrl(fileName);

      // 4. Simpan Data ke Database
      final success = await PaymentService.uploadPayment(
        orderId: _order!.id,
        amount: amount,
        paymentType: paymentType,
        proofUrl: proofUrl,
      );

      if (mounted) {
        setState(() {
          _isUploadingPayment = false;
          _imageBytes = null; // Reset bytes
        });

        if (success) {
          // 1. Tutup modal pembayaran terlebih dahulu
          Navigator.pop(context);

          // 2. Beri jeda 500ms agar Supabase sempat menyelesaikan proses commit ke database
          await Future.delayed(const Duration(milliseconds: 500));

          // 3. Refresh data hanya jika widget masih ter-mount (belum di-destroy)
          if (mounted) {
            await _fetchPayments(); // Ambil riwayat pembayaran terbaru
            await _fetchOrder(); // Ambil data order terbaru (jika ada update status)

            // 4. Tampilkan notifikasi sukses
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment proof submitted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save payment data. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ [CRITICAL ERROR] Gagal submit payment: $e');
      if (mounted) {
        setState(() => _isUploadingPayment = false);
        // Tampilkan error detail agar kita tahu apa yang salah
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ✅ 6. Modal Pembayaran yang Elegan
  void _showPaymentModal() {
    final amountController = TextEditingController(
      text: _remainingBalance.toString(),
    );
    String selectedType = _remainingBalance == (_order?.totalAmount ?? 0)
        ? 'DP'
        : 'Final Payment';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 24,
              left: 24,
              right: 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Submit Payment',
                      style: TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info Sisa Tagihan
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Remaining Balance',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'IDR ${_currencyFormat.format(_remainingBalance)}',
                          style: const TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tipe Pembayaran
                  const Text(
                    'Payment Type',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: ['DP', 'Installment', 'Final Payment']
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setModalState(() => selectedType = val!),
                  ),
                  const SizedBox(height: 16),

                  // Nominal
                  const Text(
                    'Amount (IDR)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      prefixText: 'IDR ',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ✅ UPLOAD BUKTI (DIPERBAIKI TOTAL)
                  const Text(
                    'Upload Proof',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      // 1. Ambil gambar
                      final pickedFile = await _picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                      );

                      // 2. Jika berhasil, ubah ke Bytes dan update state
                      if (pickedFile != null) {
                        // Baca file menjadi bytes (ini yang membuat preview 100% aman)
                        final bytes = await pickedFile.readAsBytes();

                        setState(() {
                          _imageBytes = bytes; // Simpan bytes di state
                        });

                        // Paksa Modal untuk rebuild
                        setModalState(() {});
                      }
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: _imageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              // ✅ GUNAKAN Image.memory, BUKAN Image.file
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_upload,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text('Tap to upload image'),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Tombol Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      // ✅ UBAH KONDISI: Cek _imageBytes, bukan _selectedImage
                      onPressed: (_isUploadingPayment || _imageBytes == null)
                          ? null
                          : () {
                              final rawAmount = amountController.text
                                  .replaceAll(RegExp(r'[^0-9]'), '');
                              final amount = int.tryParse(rawAmount) ?? 0;
                              _submitPayment(amount, selectedType);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isUploadingPayment
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'SUBMIT PAYMENT PROOF',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleCancelOrder() async {
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

    setState(() => _isCancelling = true);
    final success = await OrderService.cancelOrder(_order!.id);

    if (mounted) {
      setState(() => _isCancelling = false);
      if (success) {
        if (_order!.userEmail != null &&
            _order!.userEmail!.isNotEmpty &&
            _order!.userEmail != 'No Email') {
          EmailService.sendEmail(
            to: _order!.userEmail!,
            subject: 'Booking Cancelled - ${_order!.orderNumber}',
            htmlContent: EmailService.generateStatusUpdateTemplate(
              _order!,
              _order!.userName ?? 'Valued Guest',
              'cancelled',
            ),
          );
        }
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
    if (item.itemType == 'spa') {
      if (meta['date'] != null) parts.add('📅 ${meta['date']}');
      if (meta['time'] != null) parts.add('🕐 ${meta['time']}');
      if (meta['duration'] != null) parts.add('⏱️ ${meta['duration']} mins');
    } else if (item.itemType == 'dining') {
      if (meta['date'] != null) parts.add('📅 ${meta['date']}');
      if (meta['time'] != null) parts.add('🕐 ${meta['time']}');
      if (meta['guests'] != null) parts.add('👥 ${meta['guests']} guests');
      if (meta['restaurant_name'] != null)
        parts.add('🍽️ ${meta['restaurant_name']}');
    } else if (item.itemType == 'wedding') {
      if (meta['event_date'] != null) parts.add('📅 ${meta['event_date']}');
      if (meta['guests'] != null) parts.add('👥 ${meta['guests']} guests');
      if (meta['venue_preference'] != null)
        parts.add('📍 ${meta['venue_preference']}');
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
            // 1. Order Info Card
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

            // 2. Items Header & List
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
              ..._order!.items
                  .map(
                    (item) => _buildItemCard(item, _reviewedItemIds, () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (context) => ReviewModal(
                          itemType: item.itemType,
                          itemId: item.itemId,
                          onReviewSubmitted: () => _fetchOrder(),
                        ),
                      );
                    }),
                  )
                  .toList(),

            const SizedBox(height: 24),

            // 3. Total Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.darkCharcoal,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                  if (_order!.discountAmount > 0) ...[
                    const SizedBox(height: 12),
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
                  ],
                  if (_order!.voucherDiscountAmount > 0) ...[
                    const SizedBox(height: 12),
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
                  ],
                  const Divider(height: 24, color: Colors.white24),
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

            // ✅ 4. RIWAYAT PEMBAYARAN (BARU)
            if (!_isLoadingPayments && _payments.isNotEmpty) ...[
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
              const SizedBox(height: 24),
            ],

            // ✅ 5. TOMBOL AKSI PEMBAYARAN & BATAL (VERSI FLAT & ANTI-ERROR)
            if (_order!.status == 'pending' || _order!.status == 'confirmed') ...[
              
              // Kondisi A: Masih ada sisa tagihan
              if (_remainingBalance > 0)
                
                // Cek: Apakah sedang ada pembayaran yang pending?
                if (_hasPendingPayment)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hourglass_empty, color: Colors.orange, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Pending Verification',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                  fontSize: 14,
                                  fontFamily: 'Playfair Display',
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Your payment proof is being reviewed by our admin. Please wait for confirmation.',
                                style: TextStyle(color: Colors.orange, fontSize: 12, fontFamily: 'Lato'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Belum ada pending, tampilkan tombol bayar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showPaymentModal,
                      icon: const Icon(Icons.credit_card),
                      label: Text('PAY NOW (${_currencyFormat.format(_remainingBalance)})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  )
              else
                // Kondisi B: Sudah lunas
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('FULLY PAID', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Tombol Cancel (Hanya muncul jika belum lunas DAN tidak ada pembayaran pending)
              if (!_isCancelling && _remainingBalance > 0 && !_hasPendingPayment)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _handleCancelOrder,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('CANCEL BOOKING', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
            ],

            if (_isCancelling)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: AppColors.primaryGold),
                ),
              ),

            const SizedBox(height: 24),

            // 6. Download Invoice (Jika Confirmed/Completed)
            if (_order!.status == 'confirmed' ||
                _order!.status == 'completed') ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Generating Invoice...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    try {
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
              const SizedBox(height: 24),
            ],

            // 7. Contact Support
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
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Contact feature coming soon'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    ),
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

  Widget _buildItemCard(
    OrderItem item,
    Set<String> reviewedIds,
    VoidCallback onReviewPressed,
  ) {
    final metadata = _formatMetadata(item);
    final color = _getItemTypeColor(item.itemType);
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
            if (_order!.status == 'completed') ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (isReviewed)
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onReviewPressed,
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
