import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/order_model.dart';
import '../../core/services/order_service.dart';
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
  bool _isUploading = false;
  String? _proofUrl;
  String _selectedMethod = 'Bank Transfer'; // Default

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
        _proofUrl = order?.paymentProofUrl;
        if (order?.paymentMethod != null) {
          _selectedMethod = order!.paymentMethod!;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadProof() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => _isUploading = true);
      try {
        final fileName = 'proof_${DateTime.now().millisecondsSinceEpoch}.jpg';

        // ✅ PERBAIKAN 1: Baca file sebagai Bytes (Kompatibel Mobile & PWA)
        final bytes = await image.readAsBytes();

        // ✅ PERBAIKAN 2: Gunakan uploadBinary() alih-alih upload() dengan File
        await Supabase.instance.client.storage
            .from('payment_proofs')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );

        final proofUrl = Supabase.instance.client.storage
            .from('payment_proofs')
            .getPublicUrl(fileName);

        // Update database
        await Supabase.instance.client
            .from('orders')
            .update({
              'payment_method': _selectedMethod,
              'payment_proof_url': proofUrl,
              'rejection_reason': null, // ✅ PENTING: Hapus alasan revisi agar muncul lagi di daftar Admin
            })
            .eq('id', widget.orderId);

        // ✅ BARU: Kirim Email ke User bahwa bukti sudah diterima
        if (_order!.userEmail != null &&
            _order!.userEmail!.isNotEmpty &&
            _order!.userEmail != 'No Email') {
          EmailService.sendEmail(
            to: _order!.userEmail!,
            subject: 'Payment Proof Received - ${_order!.orderNumber}',
            htmlContent: EmailService.generateStatusUpdateTemplate(
              _order!,
              _order!.userName ?? 'Valued Guest',
              'pending', // Status masih pending menunggu verifikasi admin
            ),
          ).then((sent) {
            if (sent)
              print(
                '✅ [USER] Email bukti pembayaran terkirim ke ${_order!.userEmail}',
              );
          });
        }

        if (mounted) {
          setState(() {
            _proofUrl = proofUrl;
          });

          // Tambahkan Print untuk memastikan database terupdate
          print('✅ [UPLOAD] Berhasil upload & update DB. URL: $proofUrl');

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment proof successfully uploaded!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal upload: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _order == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGold),
        ),
      );
    }

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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Order Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order: ${_order!.orderNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Amount:',
                      style: TextStyle(color: AppColors.textGrey),
                    ),
                    Text(
                      'IDR ${_order!.totalAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 2. Payment Method Selection
            const Text(
              'Select Payment Method',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // BANK TRANSFER (ACTIVE)
            _buildPaymentOption(
              icon: Icons.account_balance,
              title: 'Bank Transfer',
              subtitle: 'Transfer to our official bank account',
              isSelected: _selectedMethod == 'Bank Transfer',
              isEnabled: true,
              onTap: () => setState(() => _selectedMethod = 'Bank Transfer'),
            ),
            const SizedBox(height: 12),

            // CREDIT CARD (DISABLED)
            _buildPaymentOption(
              icon: Icons.credit_card,
              title: 'Credit / Debit Card',
              subtitle: 'Coming Soon',
              isSelected: false,
              isEnabled: false,
              onTap: () {},
            ),

            const SizedBox(height: 24),

            // 3. Bank Details & Upload
            if (_selectedMethod == 'Bank Transfer') ...[
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bank Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildBankDetailRow(
                        'Bank Name',
                        'BCA (Bank Central Asia)',
                      ),
                      _buildBankDetailRow('Account Name', 'PT The Mulia Bali'),
                      _buildBankDetailRow('Account Number', '123-456-7890'),
                      const Divider(height: 24),

                      const Text(
                        'Upload Payment Proof',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      if (_proofUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _proofUrl!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isUploading ? null : _uploadProof,
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh),
                            label: Text(
                              _isUploading
                                  ? 'Uploading...'
                                  : 'GANTI BUKTI TRANSFER',
                            ),
                          ),
                        ),
                      ] else ...[
                        GestureDetector(
                          onTap: _isUploading ? null : _uploadProof,
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.primaryGold.withOpacity(0.5),
                                style: BorderStyle.solid,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _isUploading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primaryGold,
                                    ),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cloud_upload_outlined,
                                        size: 32,
                                        color: AppColors.primaryGold,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Tap to upload receipt',
                                        style: TextStyle(
                                          color: AppColors.textGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // ✅ BARU: Tombol untuk kembali ke detail setelah upload berhasil
            if (_proofUrl != null) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, true), // Baru keluar layar di sini
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text(
                    'FINISH & RETURN TO DETAILS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEnabled
              ? (isSelected
                    ? AppColors.primaryGold.withOpacity(0.1)
                    : Colors.white)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled
                ? (isSelected ? AppColors.primaryGold : Colors.grey.shade300)
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isEnabled
                  ? (isSelected
                        ? AppColors.primaryGold
                        : AppColors.darkCharcoal)
                  : Colors.grey,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isEnabled ? AppColors.darkCharcoal : Colors.grey,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isEnabled ? AppColors.textGrey : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (isEnabled)
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.primaryGold : Colors.grey,
              )
            else
              const Chip(
                label: Text('Soon', style: TextStyle(fontSize: 10)),
                backgroundColor: Colors.grey,
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
