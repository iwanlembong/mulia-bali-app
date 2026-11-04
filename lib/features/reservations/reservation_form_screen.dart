import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/reward_model.dart';
import '../../core/services/promo_service.dart';
import '../../core/services/reservation_service.dart';
import '../../core/services/reward_service.dart';

class ReservationFormScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const ReservationFormScreen({super.key, required this.bookingData});

  @override
  State<ReservationFormScreen> createState() => _ReservationFormScreenState();
}

class _ReservationFormScreenState extends State<ReservationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _promoController = TextEditingController();

  PromoCode? _appliedPromo;
  bool _isCheckingPromo = false;
  String? _promoError;

  Redemption? _selectedVoucher;
  int _voucherDiscountAmount = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  int get _baseTotalAmount => (widget.bookingData['totalAmount'] as num).toInt();

  int get _discountAmount {
    if (_appliedPromo == null) return 0;
    return _appliedPromo!.calculateDiscount(_baseTotalAmount);
  }

  bool get _hasActiveDiscount => _appliedPromo != null || _selectedVoucher != null;

  int get _finalTotalAmount {
    int total = _baseTotalAmount;
    if (_appliedPromo != null) total -= _discountAmount;
    total -= _voucherDiscountAmount;
    return total < 0 ? 0 : total;
  }

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _promoError = 'Please enter a code');
      return;
    }

    setState(() {
      _isCheckingPromo = true;
      _promoError = null;
    });

    try {
      final promo = await PromoService.validatePromoCode(code, _baseTotalAmount);

      if (promo == null) {
        setState(() {
          _appliedPromo = null;
          _promoError = 'Invalid or inactive promo code';
        });
      } else {
        setState(() {
          _appliedPromo = promo;
          _promoError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Promo ${promo.code} applied successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _appliedPromo = null;
        _promoError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _isCheckingPromo = false);
    }
  }

  Future<void> _showVoucherSelector() async {
    final allVouchers = await RewardService.getUserRedemptions();
    if (!mounted) return;

    print(' [DEBUG VOUCHER] Total voucher user: ${allVouchers.length}');
    for (var v in allVouchers) {
      print('   - ${v.rewardTitle} | ApplicableTo: ${v.applicableTo} | Status: ${v.status}');
    }

    final applicableVouchers = allVouchers.where((voucher) {
      return voucher.status == 'active' &&
          (voucher.applicableTo == 'all' || voucher.applicableTo == 'accommodation');
    }).toList();

    print('✅ [DEBUG VOUCHER] Voucher yang lolos filter: ${applicableVouchers.length}');

    if (applicableVouchers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have any vouchers that are valid for room bookings.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Room Voucher',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: applicableVouchers.length,
                itemBuilder: (context, index) {
                  final voucher = applicableVouchers[index];

                  int estimatedDiscount = 0;
                  String displayValue = '';
                  if (voucher.rewardType == 'discount_percentage') {
                    estimatedDiscount = (_baseTotalAmount * (int.tryParse(voucher.rewardValue) ?? 0)) ~/ 100;
                    displayValue = '${voucher.rewardValue}%';
                  } else if (voucher.rewardType == 'discount_fixed') {
                    estimatedDiscount = int.tryParse(voucher.rewardValue) ?? 0;
                    displayValue = 'IDR ${_formatPrice(estimatedDiscount)}';
                  } else {
                    displayValue = voucher.rewardValue;
                  }

                  return ListTile(
                    title: Text(voucher.rewardTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Code: ${voucher.voucherCode} | Value: $displayValue'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      setState(() {
                        _selectedVoucher = voucher;
                        _voucherDiscountAmount = estimatedDiscount;
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Voucher applied successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ✅ 2. DIPERBARUI: Validasi data booking sebelum submit
  Future<void> _submitReservation() async {
    // 1. Validasi Form UI (Special Requests)
    if (!_formKey.currentState!.validate()) return;

    // 2. ✅ VALIDASI DATA BOOKING (Dari halaman sebelumnya)
    final adults = widget.bookingData['adults'] as int?;
    final children = widget.bookingData['children'] as int?;
    final roomCount = widget.bookingData['roomCount'] as int?;
    final checkIn = widget.bookingData['checkIn'] as DateTime?;
    final checkOut = widget.bookingData['checkOut'] as DateTime?;

    // Validasi Adults & Children
    if (adults == null || adults < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Number of adults must be at least 1'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validasi Room Count
    if (roomCount == null || roomCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Number of rooms must be at least 1'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validasi Tanggal
    if (checkIn == null || checkOut == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check-in and Check-out dates are required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!checkOut.isAfter(checkIn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check-out date must be after Check-in date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 3. Jika semua valid, lanjutkan submit
    setState(() => _isSubmitting = true);

    try {
      final reservation = await ReservationService.createReservation(
        roomId: widget.bookingData['roomId'],
        propertyId: widget.bookingData['propertyId'],
        checkIn: checkIn,
        checkOut: checkOut,
        pricePerNight: widget.bookingData['pricePerNight'],
        roomCount: roomCount,
        adults: adults,
        children: children ?? 0,
        specialRequests: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        promoCode: _appliedPromo?.code,
        discountAmount: _discountAmount,
        voucherId: _selectedVoucher?.id,
        voucherDiscount: _voucherDiscountAmount,
      );

      if (reservation != null && _selectedVoucher != null) {
        await Supabase.instance.client
            .from('redemptions')
            .update({'status': 'used'})
            .eq('id', _selectedVoucher!.id);
      }

      if (mounted) {
        setState(() => _isSubmitting = false);

        if (reservation != null) {
          context.pushReplacement('/payment-instruction/${reservation.id}');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create reservation. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nights = widget.bookingData['checkOut'].difference(widget.bookingData['checkIn']).inDays;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        title: const Text(
          'Confirm Booking',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A. Ringkasan Booking
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
                    Text(
                      widget.bookingData['roomName'],
                      style: const TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow('Check-in', DateFormat('dd MMM yyyy').format(widget.bookingData['checkIn'])),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Check-out', DateFormat('dd MMM yyyy').format(widget.bookingData['checkOut'])),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Duration', '$nights Night${nights > 1 ? 's' : ''}'),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Guests', '${widget.bookingData['adults']} Adults, ${widget.bookingData['children']} Children'),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Rooms', '${widget.bookingData['roomCount']} Room${widget.bookingData['roomCount'] > 1 ? 's' : ''}'),
                    const Divider(height: 24),
                    if (_hasActiveDiscount) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal', style: TextStyle(fontFamily: 'Lato', fontSize: 14, color: AppColors.textGrey)),
                          Text(
                            'IDR ${_formatPrice(_baseTotalAmount)}',
                            style: const TextStyle(fontFamily: 'Lato', fontSize: 14, color: AppColors.textGrey, decoration: TextDecoration.lineThrough),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount', style: TextStyle(fontFamily: 'Lato', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                        Text(
                          'IDR ${_formatPrice(_finalTotalAmount)}',
                          style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // B. Kartu Diskon & Voucher
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
                    const Text(
                      'Discounts & Vouchers', // ✅ 3. UBAH DARI 'Diskon & Voucher'
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 1. Input Promo Code
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _promoController,
                            enabled: _selectedVoucher == null,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: _selectedVoucher != null
                                  ? 'Voucher is currently active'
                                  : 'Enter code (e.g., MULIA10)',
                              hintStyle: TextStyle(
                                color: _selectedVoucher != null ? Colors.grey : AppColors.textGrey,
                              ),
                              filled: true,
                              fillColor: _selectedVoucher != null ? Colors.grey.shade100 : AppColors.offWhite,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              errorText: _promoError,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: (_selectedVoucher != null || _isCheckingPromo) ? null : _applyPromoCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedVoucher != null ? Colors.grey : AppColors.darkCharcoal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isCheckingPromo
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Apply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),

                    // 2. Pilih Voucher
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _appliedPromo != null ? null : _showVoucherSelector,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: _appliedPromo != null ? Colors.grey.shade100 : AppColors.offWhite,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _appliedPromo != null ? Colors.grey.shade300 : AppColors.primaryGold.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedVoucher != null ? 'Voucher: ${_selectedVoucher!.voucherCode}' : 'Select Loyalty Voucher',
                              style: TextStyle(
                                fontFamily: 'Lato',
                                fontSize: 13,
                                color: _appliedPromo != null ? Colors.grey : AppColors.darkCharcoal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(Icons.chevron_right, color: _appliedPromo != null ? Colors.grey : AppColors.primaryGold),
                          ],
                        ),
                      ),
                    ),

                    // 3. Rincian Diskon Aktif
                    if (_appliedPromo != null || _selectedVoucher != null) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      if (_appliedPromo != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Discount (${_appliedPromo!.code})', style: const TextStyle(fontFamily: 'Lato', fontSize: 12, color: Colors.green)),
                            Row(
                              children: [
                                Text('- IDR ${_formatPrice(_discountAmount)}', style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16, color: Colors.green),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      _appliedPromo = null;
                                      _promoController.clear();
                                      _promoError = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                      if (_selectedVoucher != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Voucher Benefit', style: TextStyle(fontFamily: 'Lato', fontSize: 12, color: Colors.purple)),
                            Row(
                              children: [
                                Text(
                                  _selectedVoucher!.rewardType == 'discount_percentage' || _selectedVoucher!.rewardType == 'discount_fixed'
                                      ? '- IDR ${_formatPrice(_voucherDiscountAmount)}'
                                      : 'Special Benefit',
                                  style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16, color: Colors.purple),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      _selectedVoucher = null;
                                      _voucherDiscountAmount = 0;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_selectedVoucher!.rewardType != 'discount_percentage' && _selectedVoucher!.rewardType != 'discount_fixed') ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This voucher provides additional benefits (upgrade or service). Total payment remains unchanged; benefits will be provided upon check-in.',
                                    style: TextStyle(fontFamily: 'Lato', fontSize: 10, color: Colors.blue.shade800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // C. Special Requests dengan Validasi
              const Text(
                'Special Requests (Optional)',
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkCharcoal,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                maxLength: 200, // ✅ 4. BATASI KARAKTER
                decoration: InputDecoration(
                  hintText: 'e.g., Late check-in, extra pillows, honeymoon arrangement...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  counterText: '', // Sembunyikan counter default
                ),
                // ✅ 5. VALIDASI SPECIAL REQUESTS
                validator: (value) {
                  if (value != null && value.length > 200) {
                    return 'Special requests cannot exceed 200 characters';
                  }
                  return null; // Null = valid (karena ini opsional)
                },
              ),

              const SizedBox(height: 32),

              // D. Tombol Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReservation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkCharcoal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'CONFIRM & BOOK',
                          style: TextStyle(
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
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.textGrey)),
        Text(value, style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkCharcoal)),
      ],
    );
  }
}