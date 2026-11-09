import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/order_model.dart';
import '../../core/services/order_service.dart';
import '../../core/services/email_service.dart';

class AdminBookingDetailScreen extends StatefulWidget {
  final String orderId;
  const AdminBookingDetailScreen({super.key, required this.orderId});

  @override
  State<AdminBookingDetailScreen> createState() =>
      _AdminBookingDetailScreenState();
}

class _AdminBookingDetailScreenState extends State<AdminBookingDetailScreen> {
  bool _isLoading = true;
  Order? _order;
  bool _isUpdating = false;

  String? _selectedWeddingStatus;
  final List<String> _weddingStatusOptions = [
    'Pending Inquiry',
    'Survey Scheduled',
    'Negotiation',
    'Contract Sent',
    'DP Received',
    'Fully Paid',
    'Cancelled',
  ];

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

    if (mounted) {
      setState(() {
        _order = order;

        // ✅ PERBAIKAN: Gunakan tanda titik (.) dan tanda tanya (?) untuk null-safety
        // Pastikan nama property di model Order Anda adalah 'weddingStatus' atau 'wedding_status'
        _selectedWeddingStatus = order?.weddingStatus ?? 'Pending Inquiry';

        _isLoading = false;
      });
    }
  }

  // ✅ METHOD BARU: Verifikasi Pembayaran (Pending -> Confirmed)
  Future<void> _verifyPayment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Payment'),
        content: const Text(
          'Are you sure the payment proof is valid? This will confirm the booking and notify the guest.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
            ),
            child: const Text(
              'Yes, Verify',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isUpdating = true);
      final success = await OrderService.updateOrderStatus(
        widget.orderId,
        'confirmed',
      );
      setState(() => _isUpdating = false);

      if (mounted) {
        if (success) {
          // Kirim Email Konfirmasi
          if (_order!.userEmail != null &&
              _order!.userEmail!.isNotEmpty &&
              _order!.userEmail != 'No Email') {
            EmailService.sendEmail(
              to: _order!.userEmail!,
              subject: 'Booking Confirmed - ${_order!.orderNumber}',
              htmlContent: EmailService.generateStatusUpdateTemplate(
                _order!,
                _order!.userName ?? 'Valued Guest',
                'confirmed',
              ),
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment verified! Booking confirmed.'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchOrder();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to verify payment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ✅ METHOD BARU: Mark as Completed (Confirmed -> Completed + Poin + Counter)
  Future<void> _completeOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Completed'),
        content: const Text(
          'Mark this booking as completed? Loyalty points will be awarded to the guest.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
            child: const Text(
              'Yes, Complete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isUpdating = true);
      final success = await OrderService.completeOrder(widget.orderId);
      setState(() => _isUpdating = false);

      if (mounted) {
        if (success) {
          if (_order!.userEmail != null &&
              _order!.userEmail!.isNotEmpty &&
              _order!.userEmail != 'No Email') {
            EmailService.sendEmail(
              to: _order!.userEmail!,
              subject: 'Thank You for Visiting - ${_order!.orderNumber}',
              htmlContent: EmailService.generateStatusUpdateTemplate(
                _order!,
                _order!.userName ?? 'Valued Guest',
                'completed',
              ),
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking completed! Points awarded.'),
              backgroundColor: Colors.green,
            ),
          );

          // ✅ KIRIM SINYAL KE LAYAR SEBELUMNYA (LIST)
          Navigator.pop(context, true);

          _fetchOrder();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to complete booking'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ✅ METHOD: Cancel Order
  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
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

    if (confirm == true) {
      setState(() => _isUpdating = true);
      final success = await OrderService.updateOrderStatus(
        widget.orderId,
        'cancelled',
      );
      setState(() => _isUpdating = false);

      if (mounted && success) {
        if (_order!.userEmail != null && _order!.userEmail!.isNotEmpty) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
        _fetchOrder();
      }
    }
  }

  // ✅ METHOD BARU: Update Status Khusus Wedding
  Future<void> _updateWeddingStatus(String newStatus) async {
    try {
      // Update langsung ke tabel orders
      await Supabase.instance.client
          .from('orders')
          .update({'wedding_status': newStatus})
          .eq('id', _order!.id);

      if (mounted) {
        setState(() {
          _selectedWeddingStatus = newStatus; // Update UI secara lokal
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wedding status updated to: $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _applyDiscount() async {
    // Dialog untuk input diskon
    final discountController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply Discount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter discount amount (IDR):'),
            const SizedBox(height: 12),
            TextField(
              controller: discountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'e.g. 5000000',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && discountController.text.isNotEmpty) {
      final discountAmount = int.tryParse(discountController.text) ?? 0;
      final newTotalAmount = (_order!.totalAmount) - discountAmount;

      try {
        // Update database: simpan diskon dan total baru
        await Supabase.instance.client
            .from('orders')
            .update({
              'discount_amount': discountAmount,
              'total_amount': newTotalAmount,
            })
            .eq('id', _order!.id);

        if (mounted) {
          // Refresh data agar UI terupdate
          await _fetchOrder();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Discount applied successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to apply discount: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatMetadata(OrderItem item) {
    final meta = item.metadata;
    final parts = <String>[];
    if (item.itemType == 'spa') {
      if (meta['date'] != null) parts.add('📅 ${meta['date']}');
      if (meta['time'] != null) parts.add('🕐 ${meta['time']}');
    } else if (item.itemType == 'dining') {
      if (meta['date'] != null) parts.add(' ${meta['date']}');
      if (meta['time'] != null) parts.add('🕐 ${meta['time']}');
      if (meta['guests'] != null) parts.add('👥 ${meta['guests']} pax');
    } else if (item.itemType == 'wedding') {
      if (meta['event_date'] != null) parts.add('📅 ${meta['event_date']}');
      if (meta['guests'] != null) parts.add('👥 ${meta['guests']} pax');
      if (meta['venue_preference'] != null)
        parts.add('📍 ${meta['venue_preference']}');
    }
    return parts.isEmpty ? '' : parts.join('  •  ');
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
          'Booking Details',
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
            // 1. User & Order Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _order!.orderNumber,
                        style: const TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Chip(
                        label: Text(_order!.statusLabel),
                        backgroundColor: _getStatusColor(_order!.status)
                            .withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: _getStatusColor(_order!.status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow('Guest Name', _order!.userName ?? 'Unknown'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Email', _order!.userEmail ?? 'No Email'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Booking Date', _order!.formattedDate),
                  if (_order!.notes != null && _order!.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow('Notes', _order!.notes!),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Booked Items',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // 2. Items List
            ..._order!.items
                .map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.itemName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Text(
                                '× ${item.quantity}',
                                style: const TextStyle(
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                          if (_formatMetadata(item).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _formatMetadata(item),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _currencyFormat.format(item.unitPrice),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              Text(
                                _currencyFormat.format(item.totalPrice),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),

            // ✅ BARU: Detail & Status Khusus Wedding (Muncul HANYA jika ada item wedding)
            if (_order!.items.any((item) => item.itemType == 'wedding')) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.pink.shade50, // Warna soft pink khas wedding
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.pink.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Colors.pink.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Wedding Inquiry Details',
                          style: TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 📅 Tanggal Acara (Ambil dari Order atau fallback ke Metadata)
                    _buildInfoRow(
                      'Event Date',
                      _order!.eventDate != null
                          ? DateFormat('dd MMMM yyyy')
                                .format(DateTime.parse(_order!.eventDate!))
                          : (_order!.items
                                    .firstWhere((i) => i.itemType == 'wedding')
                                    .metadata['event_date'] ??
                                'Not specified'),
                    ),

                    const SizedBox(height: 12),

                    // 👥 Jumlah Tamu
                    _buildInfoRow(
                      'Estimated Guests',
                      _order!.guestCount != null
                          ? '${_order!.guestCount} Guests'
                          : (_order!.items
                                        .firstWhere(
                                          (i) => i.itemType == 'wedding',
                                        )
                                        .metadata['guests'] !=
                                    null
                                ? '${_order!.items.firstWhere((i) => i.itemType == 'wedding').metadata['guests']} Guests'
                                : 'Not specified'),
                    ),

                    const SizedBox(height: 24),

                    // 🔄 Dropdown Ubah Status Wedding
                    const Text(
                      'Update Wedding Status',
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedWeddingStatus,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _weddingStatusOptions.map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(
                            status,
                            style: const TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 13,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null &&
                            newValue != _selectedWeddingStatus) {
                          _updateWeddingStatus(newValue);
                        }
                      },
                    ),

                    const SizedBox(height: 16),
                    // ✅ TOMBOL KHUSUS ADMIN: APPLY DISCOUNT
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _applyDiscount,
                        icon: const Icon(
                          Icons.local_offer,
                          color: Colors.purple,
                        ),
                        label: const Text(
                          'Apply Custom Discount',
                          style: TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.purple),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 3. Total Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkCharcoal,
                borderRadius: BorderRadius.circular(12),
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
                          color: Colors.white70,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(
                          _order!.totalAmount +
                              _order!.discountAmount +
                              _order!.voucherDiscountAmount,
                        ),
                        style: TextStyle(
                          color: Colors.white,
                          decoration: _order!.discountAmount > 0
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                  // 1. Diskon Promo Code (Jika ada)
                  if (_order!.discountAmount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Discount (${_order!.promoCode ?? 'Promo'})',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '- ${_currencyFormat.format(_order!.discountAmount)}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Colors.white24),
                  ],

                  // ✅ BARU: Diskon Voucher (Jika ada)
                  if (_order!.voucherDiscountAmount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Voucher Discount',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 13,
                            color: Colors.purple, // Warna ungu agar konsisten
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL AMOUNT',
                        style: TextStyle(
                          color: Colors.white70,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(_order!.totalAmount),
                        style: const TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ✅ BARU: Tampilan Bukti Pembayaran (Jika ada)
            if (_order!.paymentProofUrl != null &&
                _order!.paymentProofUrl!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Payment Proof',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _order!.paymentProofUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGold,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // 4. Action Buttons
            if (_isUpdating)
              const Center(child: CircularProgressIndicator())
            else
              _buildActionButtons(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ✅ LOGIKA TOMBOL DINAMIS BARU
  Widget _buildActionButtons() {
    final status = _order!.status;
    final hasProof =
        _order!.paymentProofUrl != null && _order!.paymentProofUrl!.isNotEmpty;

    if (status == 'pending') {
      if (!hasProof) {
        // Belum upload bukti
        return _buildStatusMessage(
          Icons.hourglass_empty,
          Colors.orange,
          'Waiting for customer to upload payment proof.',
        );
      } else {
        // Sudah upload bukti, siap diverifikasi
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _verifyPayment,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('VERIFY PAYMENT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cancelOrder,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('CANCEL ORDER'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        );
      }
    } else if (status == 'confirmed') {
      // Sudah diverifikasi, siap diselesaikan
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _completeOrder,
          icon: const Icon(Icons.done_all),
          label: const Text('MARK AS COMPLETED'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      );
    } else {
      // Completed / Cancelled
      return _buildStatusMessage(
        Icons.info_outline,
        AppColors.textGrey,
        'This booking is already $status.',
      );
    }
  }

  Widget _buildStatusMessage(IconData icon, Color color, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
