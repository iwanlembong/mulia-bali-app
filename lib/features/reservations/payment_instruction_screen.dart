import 'dart:typed_data'; // ✅ WAJIB ADA untuk Uint8List

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/reservation_model.dart';
import '../../core/services/reservation_service.dart';

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
  bool _isUploading = false;
  String? _proofUrl;

  // ✅ BARU: State untuk Metode Pembayaran (Default: Bank Transfer)
  String _selectedPaymentMethod = 'Bank Transfer';

  @override
  void initState() {
    super.initState();
    _fetchReservation();
  }

  Future<void> _fetchReservation() async {
    final data = await ReservationService.getReservationById(
      widget.reservationId,
    );
    if (mounted) {
      setState(() {
        _reservation = data;
        _proofUrl = data?.paymentProofUrl;
        // Jika sudah ada metode pembayaran tersimpan, gunakan itu
        if (data?.paymentMethod != null) {
          _selectedPaymentMethod = data!.paymentMethod!;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadProof() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      // ✅ PERBAIKAN KRITIS: Baca sebagai Bytes, JANGAN gunakan File(image.path)
      // Ini mencegah error "Unsupported operation" di Android
      final Uint8List fileBytes = await image.readAsBytes();

      final fileName =
          'proof_${widget.reservationId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // ✅ PERBAIKAN: Gunakan uploadBinary untuk mengirim bytes
      await Supabase.instance.client.storage
          .from('payment_proofs')
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(
              upsert: true,
            ), // upsert: true agar bisa replace jika user upload ulang
          );

      // Dapatkan Public URL
      final proofUrl = Supabase.instance.client.storage
          .from('payment_proofs')
          .getPublicUrl(fileName);

      // Update database
      await Supabase.instance.client
          .from('reservations')
          .update({
            'payment_method': _selectedPaymentMethod,
            'payment_proof_url': proofUrl,
            // ✅ BARU: Reset rejection_reason agar muncul lagi di list Admin
            'rejection_reason': null,
          })
          .eq('id', widget.reservationId);

      // ✅ BARU: Refresh data dari database agar rejectionReason hilang dari UI
      await _fetchReservation();

      if (mounted) {
        setState(() => _proofUrl = proofUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment proof successfully uploaded!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Upload Error: $e'); // Cek terminal jika masih error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
    if (_isLoading || _reservation == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGold),
        ),
      );
    }

    final res = _reservation!;

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
                  
                  // ✅ BARU: Rincian Perhitungan
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Room Subtotal', style: TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.textGrey)),
                      // Hitung subtotal asli: Total Akhir + Semua Diskon
                      Text(
                        'IDR ${_formatPrice(res.totalAmount + (res.discountAmount ?? 0) + (res.voucherDiscountAmount ?? 0))}', 
                        style: const TextStyle(fontFamily: 'Lato', fontSize: 14, color: AppColors.darkCharcoal),
                      ),
                    ],
                  ),
                  
                  if ((res.discountAmount ?? 0) > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Promotional Discount (${res.promoCode ?? '-'})', style: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: Colors.green)),
                        Text('- IDR ${_formatPrice(res.discountAmount ?? 0)}', style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ],

                  if ((res.voucherDiscountAmount ?? 0) > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Loyalty Voucher Discount', style: TextStyle(fontFamily: 'Lato', fontSize: 13, color: Colors.purple)),
                        Text('- IDR ${_formatPrice(res.voucherDiscountAmount ?? 0)}', style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple)),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Total Akhir (Mengambil langsung dari res.totalAmount)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL TO PAY',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      Text(
                        'IDR ${_formatPrice(res.totalAmount)}', // ✅ INI HARUSNYA SUDAH TERPOTONG
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

            // ✅ 2. PILIHAN METODE PEMBAYARAN (BARU)
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

            // Opsi 1: Bank Transfer (AKTIF)
            GestureDetector(
              onTap: () {
                setState(() => _selectedPaymentMethod = 'Bank Transfer');
              },
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

            const SizedBox(height: 12),

            // Opsi 2: Credit Card / Payment Gateway (NON-AKTIF / DISABLED)
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
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.credit_card,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Credit Card / Payment Gateway',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Visa, Mastercard, QRIS',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badge "Coming Soon"
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Coming Soon',
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ✅ BARU: Tampilkan Alasan Revisi dari Admin (Jika Ada)
            if (_reservation!.rejectionReason != null &&
                _reservation!.rejectionReason!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment Proof Rejected',
                            style: TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Admin Reason:',
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _reservation!.rejectionReason!,
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 14,
                        color: Colors.red,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Please upload a new, correct payment proof below.',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 12,
                          color: AppColors.darkCharcoal,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            const SizedBox(height: 32),

            // 3. Informasi Rekening Bank (Hanya muncul jika Bank Transfer dipilih)
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
                    const Text(
                      'Please transfer the exact total amount to avoid verification delays.',
                      style: TextStyle(
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
            ],

            // 4. Upload Bukti Transfer (Hanya muncul jika Bank Transfer dipilih)
            if (_selectedPaymentMethod == 'Bank Transfer') ...[
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

              if (_proofUrl != null) ...[
                // 1. Gambar bukti yang sudah diupload (bisa diklik untuk melihat)
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        backgroundColor: Colors.black,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppBar(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              title: const Text('Payment Proof'),
                              actions: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 350,
                              width: double.infinity,
                              child: InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 4.0,
                                child: Image.network(
                                  _proofUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryGold,
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.network(
                        _proofUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                // ✅ BARU: Tombol untuk UPLOAD ULANG / GANTI BUKTI
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _uploadProof,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(
                      _isUploading
                          ? 'Uploading...'
                          : 'CHANGE / RE-UPLOAD PROOF',
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGold,
                      side: BorderSide(
                        color: AppColors.primaryGold.withOpacity(0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 2. Status berhasil upload
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Proof uploaded successfully! Admin will verify shortly.',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 13,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                GestureDetector(
                  onTap: _isUploading ? null : _uploadProof,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.textGrey.withOpacity(0.3),
                        style: BorderStyle.solid,
                      ),
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
                                size: 48,
                                color: AppColors.primaryGold,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tap to upload transfer receipt',
                                style: TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 14,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ] else ...[
              // Pesan jika memilih Payment Gateway (yang masih coming soon)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'Payment Gateway is currently under maintenance.',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please select Bank Transfer to complete your booking.',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),

            // 5. Tombol Kembali
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // ✅ Menghapus halaman Payment Instruction dan kembali ke layar sebelumnya (My Reservations)
                  // Sehingga tombol panah kembali (back arrow) tetap muncul di pojok kiri atas.
                  //Navigator.of(context).pop();
                  // ✅ PERBAIKAN: Kirim signal 'true' ke halaman sebelumnya
                  // Ini memberitahu halaman My Reservations bahwa data sudah berubah
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkCharcoal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _proofUrl != null
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
