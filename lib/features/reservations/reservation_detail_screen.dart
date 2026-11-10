import 'dart:typed_data'; // ✅ BARU: Untuk Image.memory
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // ✅ BARU
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ BARU

import '../../core/constants/app_colors.dart';
import '../../core/models/reservation_model.dart';
import '../../core/models/payment_model.dart'; // ✅ BARU
import '../../core/services/reservation_service.dart';
import '../../core/services/payment_service.dart'; // ✅ BARU
import '../../core/services/pdf_service.dart';
import '../../core/services/review_service.dart';
import '../../core/widgets/review_modal.dart';

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
  Set<String> _reviewedItemIds = {};

  // ✅ BARU: State Variables untuk Sistem Pembayaran Multi-Tahap
  List<OrderPayment> _payments = [];
  bool _isLoadingPayments = true;
  final ImagePicker _picker = ImagePicker();
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
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    final data = await ReservationService.getReservationById(widget.reservationId);
    final reviewedIds = await ReviewService.getUserReviewedItemIds();

    if (mounted) {
      setState(() {
        _reservation = data;
        _reviewedItemIds = reviewedIds;
        _isLoading = false;
      });
      // ✅ Fetch pembayaran setelah data reservasi berhasil dimuat
      _fetchPayments();
    }
  }

  // ✅ 1. Ambil Riwayat Pembayaran
  Future<void> _fetchPayments() async {
    if (_reservation == null) return;
    setState(() => _isLoadingPayments = true);

    List<OrderPayment> payments = [];
    if (_reservation!.id.isNotEmpty) {
      payments = await PaymentService.getPaymentsByReservationId(_reservation!.id);
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
    final totalRes = _reservation?.totalAmount ?? 0;
    final paid = _totalPaid;
    return (totalRes - paid).clamp(0, totalRes);
  }

  // ✅ 4. Cek apakah ada pembayaran yang masih pending
  bool get _hasPendingPayment {
    return _payments.any((p) => p.status.toLowerCase() == 'pending');
  }

  // ✅ 5. Upload Pembayaran (Menggunakan Bytes agar anti-error di Android)
  Future<void> _submitPayment(int amount, String paymentType) async {
    if (_imageBytes == null || _imageBytes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload payment proof first'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than 0'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isUploadingPayment = true);

    try {
      final fileName = 'pay_res_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Upload langsung dari Bytes
      await Supabase.instance.client.storage
          .from('payment_proofs') 
          .uploadBinary(fileName, _imageBytes!);

      final proofUrl = Supabase.instance.client.storage
          .from('payment_proofs')
          .getPublicUrl(fileName);

      final success = await PaymentService.uploadPayment(
        reservationId: _reservation!.id,
        amount: amount,
        paymentType: paymentType,
        proofUrl: proofUrl,
      );

      if (mounted) {
        setState(() {
          _isUploadingPayment = false;
          _imageBytes = null;
        });

        if (success) {
          Navigator.pop(context); // Tutup modal
          await Future.delayed(const Duration(milliseconds: 500)); // Jeda agar DB commit
          if (mounted) {
            await _fetchPayments();
            await _fetchDetail();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment proof submitted successfully!'), backgroundColor: Colors.green),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save payment data. Please try again.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print('❌ [CRITICAL ERROR] Gagal submit payment reservasi: $e');
      if (mounted) {
        setState(() => _isUploadingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload Error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
    }
  }

  // ✅ 6. Modal Pembayaran
  void _showPaymentModal() {
    final amountController = TextEditingController(text: _remainingBalance.toString());
    String selectedType = _remainingBalance == (_reservation?.totalAmount ?? 0) ? 'DP' : 'Final Payment';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: Text('Submit Payment', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 22, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 24),
                  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Remaining Balance', style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('IDR ${_currencyFormat.format(_remainingBalance)}', style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  const Text('Payment Type', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: InputDecoration(border: const OutlineInputBorder(), filled: true, fillColor: Colors.grey.shade50),
                    items: ['DP', 'Installment', 'Final Payment'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                    onChanged: (val) => setModalState(() => selectedType = val!),
                  ),
                  const SizedBox(height: 16),

                  const Text('Amount (IDR)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(border: const OutlineInputBorder(), filled: true, fillColor: Colors.grey.shade50, prefixText: 'IDR '),
                  ),
                  const SizedBox(height: 24),

                  const Text('Upload Proof', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                      if (pickedFile != null) {
                        final bytes = await pickedFile.readAsBytes();
                        setState(() { _imageBytes = bytes; });
                        setModalState(() {});
                      }
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                      child: _imageBytes != null 
                          ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_imageBytes!, fit: BoxFit.cover))
                          : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.cloud_upload, size: 40, color: Colors.grey), SizedBox(height: 8), Text('Tap to upload image')]),
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isUploadingPayment || _imageBytes == null)
                          ? null
                          : () {
                              final rawAmount = amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
                              final amount = int.tryParse(rawAmount) ?? 0;
                              _submitPayment(amount, selectedType);
                            },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: _isUploadingPayment 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white)) 
                          : const Text('SUBMIT PAYMENT PROOF', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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

  Future<void> _handleCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Reservation'),
        content: const Text('Are you sure you want to cancel this room reservation? This action cannot be undone.', style: TextStyle(fontFamily: 'Lato')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Reservation')),
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
        _fetchDetail();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reservation cancelled successfully'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to cancel reservation'), backgroundColor: Colors.red));
      }
    }
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: AppColors.offWhite, body: Center(child: CircularProgressIndicator(color: AppColors.primaryGold)));
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
        title: const Text('Reservation Details', style: TextStyle(fontFamily: 'Playfair Display', fontWeight: FontWeight.bold)),
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pricing Details', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('IDR ${_formatPrice(res.pricePerNight)} x $nights nights x ${res.roomCount} room(s)', style: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.textGrey))),
                      const SizedBox(width: 16),
                      Text('IDR ${_formatPrice(originalSubtotal)}', style: TextStyle(fontFamily: 'Lato', fontSize: 14, color: AppColors.darkCharcoal, decoration: hasDiscount ? TextDecoration.lineThrough : TextDecoration.none)),
                    ],
                  ),
                  if (discountAmount > 0) ...[
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Discount (${res.promoCode ?? '-'})', style: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: Colors.green)),
                      Text('- IDR ${_formatPrice(discountAmount)}', style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                    ]),
                  ],
                  if (voucherDiscountAmount > 0) ...[
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Voucher Loyalty Discount', style: TextStyle(fontFamily: 'Lato', fontSize: 13, color: Colors.purple)),
                      Text('- IDR ${_formatPrice(voucherDiscountAmount)}', style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple)),
                    ]),
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

            const SizedBox(height: 24),

            // ✅ BARU: RIWAYAT PEMBAYARAN
            if (!_isLoadingPayments && _payments.isNotEmpty) ...[
              const Text('Payment History', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
              const SizedBox(height: 12),
              ..._payments.map((payment) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                child: Row(
                  children: [
                    Icon(payment.isVerified ? Icons.check_circle : (payment.isRejected ? Icons.cancel : Icons.hourglass_empty), color: payment.statusColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${payment.paymentType} • ${payment.formattedDate}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(payment.formattedAmount, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        if (payment.isRejected && payment.rejectionReason != null)
                          Text('Note: ${payment.rejectionReason}', style: const TextStyle(color: Colors.red, fontSize: 11, fontStyle: FontStyle.italic)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: payment.statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text(payment.statusLabel, style: TextStyle(color: payment.statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              )).toList(),
              const SizedBox(height: 24),
            ],

            // ✅ BARU: TOMBOL AKSI PEMBAYARAN & BATAL (DIPERBAIKI)
            if (res.status == 'pending') ...[
              if (_remainingBalance > 0)
                if (_hasPendingPayment)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                    child: const Row(
                      children: [
                        Icon(Icons.hourglass_empty, color: Colors.orange, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Payment Pending Verification', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 14, fontFamily: 'Playfair Display')),
                              SizedBox(height: 4),
                              Text('Your payment proof is being reviewed by our admin. Please wait for confirmation.', style: TextStyle(color: Colors.orange, fontSize: 12, fontFamily: 'Lato')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showPaymentModal,
                      icon: const Icon(Icons.payment, size: 18),
                      label: Text('PAY NOW (${_currencyFormat.format(_remainingBalance)})', style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('FULLY PAID', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
                ),

              const SizedBox(height: 12),
              
              if (!_isCancelling && _remainingBalance > 0 && !_hasPendingPayment)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _handleCancel,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('CANCEL RESERVATION', style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
              if (_isCancelling) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.primaryGold))),
            ],

            if (res.status == 'cancelled' && res.rejectionReason != null && res.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Icon(Icons.error_outline, color: Colors.red.shade700, size: 24), const SizedBox(width: 8), const Text('Reservation Cancelled by Admin', style: TextStyle(fontFamily: 'Lato', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red))]),
                    const SizedBox(height: 8),
                    Text('Reason: ${res.rejectionReason}', style: const TextStyle(fontFamily: 'Lato', fontSize: 14, color: Colors.red, height: 1.5)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            if (res.status == 'confirmed' || res.status == 'completed' || res.status == 'checked_in') ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating Invoice...')));
                    try {
                      await PdfService.generateReservationInvoice(res);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice generated successfully!'), backgroundColor: Colors.green));
                    } catch (e) {
                      print('❌ Error generating PDF: $e');
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate invoice.'), backgroundColor: Colors.red));
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('DOWNLOAD INVOICE', style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.darkCharcoal, side: const BorderSide(color: AppColors.darkCharcoal), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ),
            ],

            // ✅ LOGIKA TOMBOL REVIEW
            if (res.status == 'completed') ...[
              const SizedBox(height: 16),
              if (_reviewedItemIds.contains(res.propertyId))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.withOpacity(0.3))),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, color: Colors.green, size: 20), SizedBox(width: 8), Text('REVIEWED', style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 0.5))]),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (context) => ReviewModal(
                          itemType: 'property',
                          itemId: res.propertyId,
                          onReviewSubmitted: () {
                            Navigator.pop(context);
                            _fetchDetail();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you for your review!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.rate_review, size: 18),
                    label: const Text('WRITE A REVIEW', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryGold, side: const BorderSide(color: AppColors.primaryGold), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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