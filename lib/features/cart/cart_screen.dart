import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/cart_model.dart';
import '../../core/models/reward_model.dart';
import '../../core/services/cart_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/order_service.dart';
import '../../core/services/email_service.dart';
import '../../core/services/promo_service.dart'; // ✅ BARU: Import PromoService
import '../../core/services/reward_service.dart';
import '../booking/booking_payment_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isLoading = true;
  Cart? _cart;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'IDR ',
    decimalDigits: 0,
  );

  // ✅ BARU: State Variables untuk Promo Code
  final TextEditingController _promoController = TextEditingController();
  PromoCode? _appliedPromo;
  bool _isCheckingPromo = false;
  String? _promoError;

  // ✅ BARU: State untuk Voucher
  List<Redemption> _myVouchers = [];
  Redemption? _selectedVoucher;
  int _voucherDiscount = 0;

  @override
  void initState() {
    super.initState();
    _fetchCart();
    _fetchMyVouchers(); // ✅ TAMBAHKAN INI
  }

  @override
  void dispose() {
    _promoController.dispose(); // ✅ Bersihkan controller
    super.dispose();
  }

  // ✅ Helper untuk menghitung total akhir setelah diskon (Promo ATAU Voucher)
  int get _finalTotalAmount {
    if (_cart == null) return 0;
    final promoDiscount = _appliedPromo?.calculateDiscount(_cart!.totalAmount) ?? 0;
    return _cart!.totalAmount - promoDiscount - _voucherDiscount;
  }
  
  Future<void> _fetchCart() async {
    setState(() => _isLoading = true);
    final cart = await CartService.getOrCreateActiveCart();
    if (mounted) {
      setState(() {
        _cart = cart;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateQuantity(CartItem item, int newQuantity) async {
    if (newQuantity < 1) {
      await _removeItem(item);
      return;
    }
    final success = await CartService.updateQuantity(item.id, newQuantity);
    if (success && mounted) {
      await _fetchCart();
    }
  }

  Future<void> _removeItem(CartItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item?'),
        content: Text('Remove "${item.itemName}" from cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await CartService.removeFromCart(item.id);
      if (success && mounted) {
        await _fetchCart();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item removed from cart'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // ✅ BARU: Method untuk memvalidasi dan menerapkan promo code
  Future<void> _applyPromoCode() async {
    // ✅ 1. Pastikan cart tidak null
    if (_cart == null) {
      setState(() => _promoError = 'Cart is empty');
      return;
    }

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
      // 2. Panggil service (tipe kembalian adalah PromoCode?)
      final promo = await PromoService.validatePromoCode(
        code,
        _cart!.totalAmount,
      );

      // ✅ 3. PERIKSA NULL SECARA EKSPLISIT (Ini yang menghilangkan error Dart)
      if (promo == null) {
        setState(() {
          _appliedPromo = null;
          _promoError = 'Invalid or inactive promo code';
        });
        return; // Hentikan eksekusi di sini
      }

      // 4. Jika sampai di sini, Dart tahu 100% bahwa 'promo' TIDAK NULL
      setState(() {
        _appliedPromo = promo;
        _promoError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Promo ${promo.code} applied successfully!',
          ), // ✅ Sekarang aman diakses
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Jika ada Exception (misal: min. purchase tidak tercapai)
      setState(() {
        _appliedPromo = null;
        _promoError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _isCheckingPromo = false);
    }
  }

  // ✅ BARU: Fetch Voucher Aktif
  Future<void> _fetchMyVouchers() async {
    final vouchers = await RewardService.getActiveVouchers();
    if (mounted) {
      setState(() {
        _myVouchers = vouchers
            .where(
              (v) => v.applicableTo == 'services' || v.applicableTo == 'all',
            )
            .toList(); // Filter untuk services
      });
    }
  }

  // ✅ BARU: Tampilkan Bottom Sheet Pilih Voucher
  void _showVoucherBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: SizedBox(
                  width: 40,
                  height: 4,
                  child: Divider(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pilih Voucher Anda',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _myVouchers.isEmpty
                    ? const Center(
                        child: Text(
                          'Anda belum memiliki voucher aktif.',
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _myVouchers.length,
                        itemBuilder: (context, index) {
                          final voucher = _myVouchers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text(
                                voucher.rewardTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text('Kode: ${voucher.voucherCode}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.pop(context);
                                _applyVoucher(voucher);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ BARU: Terapkan Voucher (Saling Meniadakan dengan Promo)
  void _applyVoucher(Redemption voucher) {
    // Hitung diskon voucher
    int discount = 0;
    if (voucher.rewardType == 'discount_percentage') {
      discount = (_cart!.totalAmount * int.parse(voucher.rewardValue)) ~/ 100;
    } else if (voucher.rewardType == 'discount_fixed') {
      discount = int.parse(voucher.rewardValue);
    }

    setState(() {
      _selectedVoucher = voucher;
      _voucherDiscount = discount;

      // ✅ LOGIKA SALING MENIADAKAN: Hapus Promo Code jika ada
      _appliedPromo = null;
      _promoController.clear();
      _promoError = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voucher ${voucher.rewardTitle} diterapkan!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _clearVoucher() {
    setState(() {
      _selectedVoucher = null;
      _voucherDiscount = 0;
    });
  }

  Future<void> _handleCheckout() async {
    if (!AuthService.isLoggedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first to proceed with checkout'),
          backgroundColor: Colors.orange,
        ),
      );
      context.push('/login');
      return;
    }

    if (_cart == null || _cart!.items.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Checkout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subtotal: ${_currencyFormat.format(_cart!.totalAmount)}'),
            // ✅ Tampilkan Diskon Promo jika ada
            if (_appliedPromo != null) ...[
              const SizedBox(height: 4),
              Text(
                'Discount (${_appliedPromo!.code}): - ${_currencyFormat.format(_appliedPromo!.calculateDiscount(_cart!.totalAmount))}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],

            // ✅ BARU: Tampilkan Diskon Voucher jika ada
            if (_selectedVoucher != null) ...[
              const SizedBox(height: 4),
              Text(
                'Voucher (${_selectedVoucher!.rewardTitle}): - ${_currencyFormat.format(_voucherDiscount)}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],

            const Divider(height: 24),
            Text(
              // ✅ Gunakan _finalTotalAmount yang sudah kita definisikan di getter atas
              'Total: ${_currencyFormat.format(_finalTotalAmount)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your booking will be processed and you will receive a confirmation.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      ),
    );

    // ✅ BARU: Kirimkan promoCode dan discountAmount ke OrderService
    // final discountAmount =
    // _appliedPromo?.calculateDiscount(_cart!.totalAmount) ?? 0;
    final order = await OrderService.createOrderFromCart(
      promoCode: _appliedPromo?.code,
      discountAmount: _appliedPromo?.calculateDiscount(_cart!.totalAmount) ?? 0,
      voucherId: _selectedVoucher?.id, // ✅ BARU
      voucherDiscount: _voucherDiscount, // ✅ BARU
    );

    if (mounted) Navigator.pop(context);
    if (!mounted) return;

    if (order != null) {
      if (order.userEmail != null && order.userEmail != 'No Email') {
        final guestName = order.userName ?? 'Valued Guest';
        final htmlContent = EmailService.generateConfirmationTemplate(
          order,
          guestName,
        );

        EmailService.sendEmail(
          to: order.userEmail!,
          subject: 'Booking Received - ${order.orderNumber}',
          htmlContent: htmlContent,
        ).then((success) {
          if (success)
            print('✅ [EMAIL] Confirmation email sent to ${order.userEmail}');
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order ${order.orderNumber} created successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        _cart = null;
        _appliedPromo = null; // ✅ Reset promo setelah checkout
        _selectedVoucher = null; // ✅ BARU: Reset voucher
        _voucherDiscount = 0; // ✅ BARU: Reset diskon voucher
        _promoController.clear();
      });

      if (mounted) {
        // 🚀 PERUBAHAN: Arahkan ke halaman pembayaran terlebih dahulu
        // Agar user bisa langsung upload bukti transfer sebelum melihat halaman sukses
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookingPaymentScreen(orderId: order.id),
          ),
        ).then((paymentSuccess) {
          // Jika pembayaran berhasil diupload, baru arahkan ke halaman konfirmasi
          if (paymentSuccess == true && mounted) {
            context.go('/booking-confirmation', extra: order);
          }
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to process checkout. Please try again.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  IconData _getItemIcon(String itemType) {
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

  Color _getItemColor(String itemType) {
    switch (itemType) {
      case 'spa':
        return const Color(0xFF8B7355);
      case 'dining':
        return const Color(0xFF6B8E23);
      case 'wedding':
        return Colors.pink.shade300;
      default:
        return AppColors.primaryGold;
    }
  }

  String _formatMetadata(CartItem item) {
    final meta = item.metadata;
    final parts = <String>[];

    if (meta['date'] != null && meta['date'].toString().isNotEmpty)
      parts.add('📅 ${meta['date']}');
    if (meta['time'] != null && meta['time'].toString().isNotEmpty)
      parts.add('🕐 ${meta['time']}');
    if (meta['guests'] != null) parts.add('👥 ${meta['guests']} guests');

    return parts.isEmpty ? '' : parts.join('  •  ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        title: const Text(
          'My Cart',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGold),
            )
          : _cart == null || _cart!.items.isEmpty
          ? _buildEmptyState()
          : _buildCartList(),
      bottomNavigationBar: _cart != null && _cart!.items.isNotEmpty
          ? _buildCheckoutBar()
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: AppColors.primaryGold,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.darkCharcoal,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add spa treatments, dining, or wedding packages\nto get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Lato',
              fontSize: 14,
              color: AppColors.textGrey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home),
            label: const Text('Explore Experiences'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartList() {
    return RefreshIndicator(
      onRefresh: _fetchCart,
      color: AppColors.primaryGold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _cart!.items.length,
        itemBuilder: (context, index) =>
            _buildCartItemCard(_cart!.items[index]),
      ),
    );
  }

  Widget _buildCartItemCard(CartItem item) {
    final metadata = _formatMetadata(item);
    final color = _getItemColor(item.itemType);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getItemIcon(item.itemType),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemType.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.itemName,
                        style: const TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: () => _removeItem(item),
                  tooltip: 'Remove',
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
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.textGrey.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: () =>
                            _updateQuantity(item, item.quantity - 1),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () =>
                            _updateQuantity(item, item.quantity + 1),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currencyFormat.format(item.unitPrice),
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 11,
                        color: AppColors.textGrey,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(item.totalPrice),
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ DIPERBARUI: Menambahkan UI Promo Code
  Widget _buildCheckoutBar() {
    // ✅ PERBAIKAN: Hitung diskon dari Promo ATAU Voucher (tidak bisa keduanya)
    final promoDiscount =
        _appliedPromo?.calculateDiscount(_cart!.totalAmount) ?? 0;
    final finalTotal = _cart!.totalAmount - promoDiscount - _voucherDiscount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ BARU: Input Promo Code
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoController,
                    enabled:
                        _selectedVoucher == null, // ✅ MATI jika voucher aktif
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Promo Code (e.g., MULIA10)',
                      hintStyle: const TextStyle(fontSize: 12),
                      filled: true,
                      fillColor: AppColors.offWhite,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      errorText: _promoError,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (_selectedVoucher == null && !_isCheckingPromo)
                      ? _applyPromoCode
                      : null, // ✅ MATI jika voucher aktif
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkCharcoal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isCheckingPromo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Apply',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ✅ BARU: Tombol Pilih Voucher (Disabled jika Promo aktif)
            GestureDetector(
              onTap: _appliedPromo == null
                  ? _showVoucherBottomSheet
                  : null, // ✅ MATI jika promo aktif
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: _appliedPromo == null
                      ? AppColors.offWhite
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _appliedPromo == null
                        ? AppColors.primaryGold
                        : Colors.grey.shade400,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedVoucher != null
                          ? 'Voucher: ${_selectedVoucher!.rewardTitle}'
                          : 'Pilih Voucher Saya',
                      style: TextStyle(
                        color: _appliedPromo == null
                            ? AppColors.darkCharcoal
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (_selectedVoucher != null)
                      GestureDetector(
                        onTap: () {
                          _clearVoucher();
                        }, // Hapus voucher
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.red,
                        ),
                      )
                    else
                      const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),

            // ✅ PERBAIKAN: Tampilkan Diskon jika ada (dari Promo ATAU Voucher)
            if (promoDiscount > 0 || _voucherDiscount > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    // Tampilkan nama Promo Code ATAU nama Voucher
                    'Discount (${_appliedPromo != null ? _appliedPromo!.code : _selectedVoucher!.rewardTitle})',
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    // Karena saling meniadakan, kita bisa menjumlahkan keduanya (salah satu pasti 0)
                    '- ${_currencyFormat.format(promoDiscount + _voucherDiscount)}',
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],

            // Total Akhir
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 14,
                    color: AppColors.textGrey,
                  ),
                ),
                Text(
                  _currencyFormat.format(finalTotal),
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkCharcoal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Checkout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleCheckout,
                icon: const Icon(Icons.check_circle, size: 20),
                label: Text(
                  'PROCEED TO CHECKOUT (${_cart!.items.length} items)',
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
        ),
      ),
    );
  }
}
