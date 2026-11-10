import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/order_model.dart';
import '../../core/services/order_service.dart';
import '../../core/services/payment_service.dart'; // ✅ BARU: Gunakan PaymentService
import '../../core/services/email_service.dart';

class BookingPaymentScreen extends StatefulWidget {
  final String orderId;
  const BookingPaymentScreen({super.key, required this.orderId});

  @override
  State<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends State<BookingPaymentScreen> {
  Order? _order;
  bool _isLoading = true;
  Uint8List? _imageBytes;
  bool _isUploadingPayment = false;
  String _selectedMethod = 'Bank Transfer';

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
    final order = await OrderService.getOrderById(widget.orderId);
    if (mounted) {
      setState(() {
        _order = order;
        if (order?.paymentMethod != null) {
          _selectedMethod = order!.paymentMethod!;
        }
        _isLoading = false;
      });
    }
  }

  // ✅ BARU: Submit Pembayaran menggunakan PaymentService (Full Payment Only)
  Future<void> _submitFullPayment() async {
    if (_imageBytes == null || _imageBytes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload payment proof first'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isUploadingPayment = true);

    try {
      final fileName = 'pay_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload bukti ke Storage
      await Supabase.instance.client.storage
          .from('payment_proofs')
          .uploadBinary(fileName, _imageBytes!);

      final proofUrl = Supabase.instance.client.storage
          .from('payment_proofs')
          .getPublicUrl(fileName);

      // ✅ PENTING: Gunakan PaymentService dengan paymentType = 'Full Payment'
      final success = await PaymentService.uploadPayment(
        orderId: _order!.id,
        amount: _order!.totalAmount, // ✅ Full payment = total amount
        paymentType: 'Full Payment', // ✅ Otomatis Full Payment
        proofUrl: proofUrl,
      );

      if (mounted) {
        if (success) {
          // Update payment method di orders table
          await Supabase.instance.client
              .from('orders')
              .update({'payment_method': _selectedMethod})
              .eq('id', widget.orderId);

          // Kirim Email
          if (_order!.userEmail != null && _order!.userEmail!.isNotEmpty) {
            EmailService.sendEmail(
              to: _order!.userEmail!,
              subject: 'Payment Proof Received - ${_order!.orderNumber}',
              htmlContent: EmailService.generateStatusUpdateTemplate(
                _order!,
                _order!.userName ?? 'Valued Guest',
                'pending',
              ),
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Full payment proof uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Kembali ke halaman sebelumnya dengan signal success
          if (mounted) {
            Navigator.pop(context, true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save payment data'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print('❌ [ERROR] Gagal upload payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPayment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _order == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        title: const Text(
          'Payment',
          style: TextStyle(fontFamily: 'Playfair Display', fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Order Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ORDER DETAILS',
                    style: TextStyle(fontFamily: 'Lato', fontSize: 11, color: AppColors.textGrey, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_order!.orderNumber, style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount (Full Payment)', style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                      Text(
                        _currencyFormat.format(_order!.totalAmount),
                        style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryGold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This is a full payment for your Spa/Dining booking.',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. Payment Method Selection
            const Text(
              'Select Payment Method',
              style: TextStyle(fontFamily: 'Playfair Display', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal),
            ),
            const SizedBox(height: 12),

            // BANK TRANSFER (ACTIVE)
            GestureDetector(
              onTap: () => setState(() => _selectedMethod = 'Bank Transfer'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _selectedMethod == 'Bank Transfer' ? AppColors.primaryGold.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedMethod == 'Bank Transfer' ? AppColors.primaryGold : Colors.grey.shade300,
                    width: _selectedMethod == 'Bank Transfer' ? 2 : 1,
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
                      child: const Icon(Icons.account_balance, color: AppColors.primaryGold, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bank Transfer', style: TextStyle(fontFamily: 'Lato', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                          SizedBox(height: 4),
                          Text('BCA, Mandiri, BNI, etc.', style: TextStyle(fontFamily: 'Lato', fontSize: 12, color: AppColors.textGrey)),
                        ],
                      ),
                    ),
                    Icon(
                      _selectedMethod == 'Bank Transfer' ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _selectedMethod == 'Bank Transfer' ? AppColors.primaryGold : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // CREDIT CARD (DISABLED)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.credit_card, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Credit / Debit Card', style: TextStyle(fontFamily: 'Lato', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
                        SizedBox(height: 4),
                        Text('Coming Soon', style: TextStyle(fontFamily: 'Lato', fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Chip(label: Text('Soon', style: TextStyle(fontSize: 10)), backgroundColor: Colors.grey),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 3. Bank Details & Upload (Only for Bank Transfer)
            if (_selectedMethod == 'Bank Transfer') ...[
              const Text(
                'Bank Transfer Details',
                style: TextStyle(fontFamily: 'Playfair Display', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
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
                      'Please transfer exactly: ${_currencyFormat.format(_order!.totalAmount)}',
                      style: const TextStyle(fontFamily: 'Lato', fontSize: 12, color: AppColors.textGrey, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Upload Payment Proof
              const Text(
                'Upload Payment Proof',
                style: TextStyle(fontFamily: 'Playfair Display', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal),
              ),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: _isUploadingPayment
                    ? null
                    : () async {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(
                          source: ImageSource.gallery, 
                          imageQuality: 80
                        );
                        
                        if (pickedFile != null) {
                          // ✅ 1. Baca bytes terlebih dahulu (DI LUAR setState)
                          final bytes = await pickedFile.readAsBytes();
                          
                          // ✅ 2. Update state secara sinkron
                          setState(() {
                            _imageBytes = bytes;
                          });
                        }
                      },
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.textGrey.withOpacity(0.3)),
                  ),
                  child: _imageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primaryGold),
                            SizedBox(height: 8),
                            Text('Tap to upload transfer receipt', style: TextStyle(fontFamily: 'Lato', fontSize: 14, color: AppColors.textGrey)),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploadingPayment || _imageBytes == null ? null : _submitFullPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isUploadingPayment
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                      : const Text(
                          'SUBMIT FULL PAYMENT',
                          style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0),
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

  Widget _buildBankRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.textGrey)),
        Text(value, style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
      ],
    );
  }
}