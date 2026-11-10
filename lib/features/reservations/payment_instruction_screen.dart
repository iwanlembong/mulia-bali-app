import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/reservation_model.dart';
import '../../core/models/payment_model.dart';
import '../../core/services/reservation_service.dart';
import '../../core/services/payment_service.dart';

class PaymentInstructionScreen extends StatefulWidget {
  final String reservationId;

  const PaymentInstructionScreen({super.key, required this.reservationId});

  @override
  State<PaymentInstructionScreen> createState() =>
      _PaymentInstructionScreenState();
}

class _PaymentInstructionScreenState extends State<PaymentInstructionScreen> {
  bool _isLoading = true;
  Reservation? _reservation;

  // ✅ State untuk Sistem Pembayaran Multi-Tahap
  List<OrderPayment> _payments = [];
  bool _isLoadingPayments = true;
  Uint8List? _imageBytes;
  bool _isUploadingPayment = false;
  bool _isSubmitting =
      false; // ✅ BARU: Mencegah double-click / double submission
  String _selectedPaymentMethod = 'Bank Transfer';

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'IDR ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    final data = await ReservationService.getReservationById(
      widget.reservationId,
    );

    if (mounted && data != null) {
      setState(() {
        _reservation = data;
        if (data.paymentMethod != null) {
          _selectedPaymentMethod = data.paymentMethod!;
        }
        _isLoading = false;
      });
      _fetchPayments();
    }
  }

  // ✅ 1. Ambil Riwayat Pembayaran
  Future<void> _fetchPayments() async {
    if (_reservation == null) return;
    setState(() => _isLoadingPayments = true);

    print(
      '🔍 [DEBUG] Mencari pembayaran untuk Reservation ID: ${_reservation!.id}',
    );

    final payments = await PaymentService.getPaymentsByReservationId(
      _reservation!.id,
    );

    print('🔍 [DEBUG] Ditemukan ${payments.length} pembayaran di database.');

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
    return (totalRes - _totalPaid).clamp(0, totalRes);
  }

  // ✅ 4. Cek apakah ada pembayaran yang masih pending
  bool get _hasPendingPayment {
    return _payments.any((p) => p.status.toLowerCase() == 'pending');
  }

  // ✅ 5. Buka Modal Pembayaran
  void _showPaymentModal() {
    final amountController = TextEditingController(
      text: _remainingBalance.toString(),
    );
    String selectedType = _payments.isEmpty ? 'DP' : 'Final Payment';

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
                          _currencyFormat.format(_remainingBalance),
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

                  // Upload Bukti
                  const Text(
                    'Upload Proof',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picker = ImagePicker();
                      final pickedFile = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                      );
                      if (pickedFile != null) {
                        final bytes = await pickedFile.readAsBytes();
                        setState(() => _imageBytes = bytes);
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
                      // ✅ PERBAIKAN: Tambahkan _isSubmitting ke kondisi disabled
                      onPressed:
                          (_isUploadingPayment ||
                              _isSubmitting ||
                              _imageBytes == null)
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

  // ✅ 6. Submit Pembayaran (DENGAN ANTI DOUBLE-CLICK)
  Future<void> _submitPayment(int amount, String paymentType) async {
    // ✅ PENCEGAHAN: Jika sedang submit, abaikan klik tambahan
    if (_isSubmitting) {
      print('⚠️ [DEBUG] Submit sedang diproses, mengabaikan klik tambahan.');
      return;
    }

    if (_imageBytes == null || _imageBytes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload payment proof first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount must be greater than 0'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ✅ KUNCI TOMBOL SEGERA
    setState(() {
      _isUploadingPayment = true;
      _isSubmitting = true;
    });

    try {
      final fileName = 'pay_res_${DateTime.now().millisecondsSinceEpoch}.jpg';

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
        if (success) {
          print('✅ [DEBUG] Pembayaran berhasil disimpan ke order_payments!');
          Navigator.pop(context); // Tutup modal
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            await _fetchPayments();
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
              content: Text('Failed to save payment data.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ [CRITICAL ERROR] Gagal submit payment reservasi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      // ✅ SELALU LEPAS KUNCI, baik sukses maupun gagal, agar tombol tidak terkunci selamanya
      if (mounted) {
        setState(() {
          _isUploadingPayment = false;
          _isSubmitting = false;
          _imageBytes = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _reservation == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGold),
        ),
      );
    }

    final res = _reservation!;
    final discountAmount = res.discountAmount ?? 0;
    final voucherDiscountAmount = res.voucherDiscountAmount ?? 0;
    final originalSubtotal =
        res.totalAmount + discountAmount + voucherDiscountAmount;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        title: const Text(
          'Payment',
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
            // 1. Ringkasan Tagihan
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                    'RESERVATION DETAILS',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 11,
                      color: AppColors.textGrey,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    res.reservationNumber,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  const Divider(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Room Subtotal',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 13,
                          color: AppColors.textGrey,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(originalSubtotal),
                        style: const TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 14,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ],
                  ),

                  if (discountAmount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Promotional Discount (${res.promoCode ?? '-'})',
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 13,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          '- ${_currencyFormat.format(discountAmount)}',
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
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Loyalty Voucher Discount',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 13,
                            color: Colors.purple,
                          ),
                        ),
                        Text(
                          '- ${_currencyFormat.format(voucherDiscountAmount)}',
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL AMOUNT',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(res.totalAmount),
                        style: const TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGold,
                        ),
                      ),
                    ],
                  ),

                  // ✅ Tampilkan Sisa Tagihan jika sudah ada pembayaran
                  if (_totalPaid > 0) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Already Paid (Verified)',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 13,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(_totalPaid),
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'REMAINING BALANCE',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(_remainingBalance),
                          style: const TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ✅ Riwayat Pembayaran
            if (!_isLoadingPayments && _payments.isNotEmpty) ...[
              const Text(
                'Payment History',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 16,
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

            // 2. Pilihan Metode Pembayaran
            const Text(
              'Select Payment Method',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: () =>
                  setState(() => _selectedPaymentMethod = 'Bank Transfer'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedPaymentMethod == 'Bank Transfer'
                        ? AppColors.primaryGold
                        : Colors.grey.shade300,
                    width: _selectedPaymentMethod == 'Bank Transfer' ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance,
                        color: AppColors.primaryGold,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bank Transfer',
                            style: TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'BCA, Mandiri, BNI, etc.',
                            style: TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Radio<String>(
                      value: 'Bank Transfer',
                      groupValue: _selectedPaymentMethod,
                      onChanged: (val) =>
                          setState(() => _selectedPaymentMethod = val!),
                      activeColor: AppColors.primaryGold,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 3. Informasi Rekening Bank
            if (_selectedPaymentMethod == 'Bank Transfer') ...[
              const Text(
                'Bank Transfer Details',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkCharcoal,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryGold.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    _buildBankRow('Bank', 'BCA (Bank Central Asia)'),
                    const SizedBox(height: 8),
                    _buildBankRow('Account Number', '123-456-7890'),
                    const SizedBox(height: 8),
                    _buildBankRow('Account Name', 'PT The Mulia Hospitality'),
                    const SizedBox(height: 12),
                    Text(
                      'Please transfer the exact amount: ${_currencyFormat.format(_remainingBalance)}',
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 12,
                        color: AppColors.textGrey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 4. Upload Bukti Transfer
              const Text(
                'Upload Payment Proof',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkCharcoal,
                ),
              ),
              const SizedBox(height: 12),

              // ✅ LOGIKA PENGUNCIAN
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
                      Icon(
                        Icons.hourglass_empty,
                        color: Colors.orange,
                        size: 24,
                      ),
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
                              'Your previous payment proof is being reviewed. Please wait for admin confirmation before uploading again.',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontFamily: 'Lato',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (_remainingBalance <= 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'FULLY PAID',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 16,
                          fontFamily: 'Playfair Display',
                        ),
                      ),
                    ],
                  ),
                )
              else
                // ✅ TOMBOL BUKA MODAL PEMBAYARAN
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showPaymentModal,
                    icon: const Icon(Icons.payment, size: 18),
                    label: Text(
                      'PAY NOW (${_currencyFormat.format(_remainingBalance)})',
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
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
            ],

            const SizedBox(height: 40),

            // 5. Tombol Kembali
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkCharcoal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _hasPendingPayment || _remainingBalance <= 0
                      ? 'VIEW MY RESERVATIONS'
                      : 'REMIND ME LATER',
                  style: const TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Lato',
            fontSize: 13,
            color: AppColors.textGrey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Lato',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.darkCharcoal,
          ),
        ),
      ],
    );
  }
}
