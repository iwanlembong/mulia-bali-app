import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/order_model.dart';
import '../../core/services/order_service.dart';
import '../../core/services/review_service.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/shimmer_card.dart';
import '../../core/widgets/review_modal.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Order> _allOrders = [];

 
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'IDR ',
    decimalDigits: 0,
  );

  // Filter tabs
  final List<String> _tabs = [
    'All',
    'Pending',
    'Confirmed',
    'Completed',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _fetchOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);

    final orders = await OrderService.getUserOrders();

    if (mounted) {
      setState(() {
        _allOrders = orders;
        _isLoading = false;
      });
    }
  }

  List<Order> _getFilteredOrders(String tab) {
    if (tab == 'All') return _allOrders;
    return _allOrders
        .where((order) => order.status == tab.toLowerCase())
        .toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        title: const Text(
          'My Bookings',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primaryGold,
          labelColor: AppColors.primaryGold,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontFamily: 'Lato',
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          tabs: _tabs.map((tab) {
            final count = _getFilteredOrders(tab).length;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tab),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) => _buildOrdersList(tab)).toList(),
      ),
    );
  }

  Widget _buildOrdersList(String tab) {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4, // Tampilkan 4 kartu shimmer
        itemBuilder: (context, index) {
          return const ShimmerCard(); // Pastikan import shimmer_card.dart di atas
        },
      );
    }

    final filteredOrders = _getFilteredOrders(tab);

    if (filteredOrders.isEmpty) {
      // return _buildEmptyState(tab);
      return EmptyStateWidget(
        icon: Icons.receipt_long_outlined,

        // ✅ JUDUL DINAMIS: Menyesuaikan dengan Tab yang aktif
        title: tab == 'All' ? 'No Bookings Yet' : 'No $tab Bookings',

        // ✅ SUBTITLE DINAMIS: Memberikan konteks yang lebih jelas
        subtitle: tab == 'All'
            ? 'Discover our spa, dining, and wedding experiences.'
            : 'You don\'t have any bookings with "$tab" status yet.',

        // ✅ TOMBOL: Hanya muncul jika di tab 'All'
        buttonText: tab == 'All' ? 'Explore Experiences' : null,
        onButtonPressed: tab == 'All' ? () => context.go('/') : null,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      color: AppColors.primaryGold,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  // Widget _buildEmptyState(String tab) {
  //   return Center(
  //     child: Padding(
  //       padding: const EdgeInsets.all(32),
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           Icon(
  //             Icons.receipt_long_outlined,
  //             size: 64,
  //             color: AppColors.textGrey.withOpacity(0.5),
  //           ),
  //           const SizedBox(height: 16),
  //           Text(
  //             tab == 'All' ? 'No bookings yet' : 'No $tab bookings',
  //             style: const TextStyle(
  //               fontFamily: 'Playfair Display',
  //               fontSize: 18,
  //               fontWeight: FontWeight.bold,
  //               color: AppColors.darkCharcoal,
  //             ),
  //           ),
  //           const SizedBox(height: 8),
  //           Text(
  //             tab == 'All'
  //                 ? 'Start exploring our experiences and make your first booking.'
  //                 : 'Bookings with "$tab" status will appear here.',
  //             textAlign: TextAlign.center,
  //             style: const TextStyle(
  //               fontFamily: 'Lato',
  //               fontSize: 13,
  //               color: AppColors.textGrey,
  //               height: 1.5,
  //             ),
  //           ),
  //           if (tab == 'All') ...[
  //             const SizedBox(height: 24),
  //             ElevatedButton.icon(
  //               onPressed: () => context.go('/'),
  //               icon: const Icon(Icons.explore, size: 18),
  //               label: const Text('EXPLORE EXPERIENCES'),
  //               style: ElevatedButton.styleFrom(
  //                 backgroundColor: AppColors.primaryGold,
  //                 foregroundColor: Colors.white,
  //                 padding: const EdgeInsets.symmetric(
  //                   horizontal: 24,
  //                   vertical: 12,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildOrderCard(Order order) {
    // ✅ TAMBAHKAN 3 BARIS INI UNTUK MELIHAT ISI DATA SEBENARNYA
    print('🔍 [DEBUG] Order: ${order.orderNumber}');
    print('   - Promo (Hijau): ${order.discountAmount}');
    print('   - Voucher (Ungu): ${order.voucherDiscountAmount}');
    // ✅ OPTIMASI 1: Pre-calculate values di awal untuk menghindari komputasi berulang saat build
    final statusColor = _getStatusColor(order.status);
    final hasPromoDiscount = order.discountAmount > 0;
    final hasVoucherDiscount = order.voucherDiscountAmount > 0;
    final hasAnyDiscount =
        hasPromoDiscount || hasVoucherDiscount; // Cek jika ada salah satu

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      clipBehavior: Clip.antiAlias, // ✅ OPTIMASI 2: Mencegah ripple effect "bocor" & menghemat rendering GPU
      child: InkWell(
        onTap: () {
          context.push('/booking-detail/${order.id}').then((_) {
            _fetchOrders(); // ✅ Auto-refresh
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min, // ✅ OPTIMASI 3: Mencegah kalkulasi layout vertikal yang tidak perlu
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Order Number + Status
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(height: 4),
                        Text(
                          order.orderNumber,
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(
                        0.1,
                      ), // Menggunakan variabel yang sudah di-cache
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.statusLabel,
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor, // Menggunakan variabel yang sudah di-cache
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Date
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: AppColors.textGrey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    order.formattedDate,
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 13,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ✅ OPTIMASI 4: Ganti logika .take(2).map() yang berat dengan placeholder statis yang ringan.
              // Karena getUserOrders() sengaja TIDAK meload items demi performa, menampilkan
              // "Loading items..." itu membingungkan. Placeholder ini 0% beban CPU dan UX-nya lebih jujur.
              const Row(
                children: [
                  Icon(Icons.receipt_long, size: 14, color: AppColors.textGrey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap to view booking details',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 12,
                        color: AppColors.textGrey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Footer: Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                  Text(
                    _currencyFormat.format(order.totalAmount),
                    style: const TextStyle(
                      fontFamily: 'Playfair Display', // Disesuaikan agar konsisten dengan gaya total amount
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                ],
              ),

              // ✅ BARU: Badge Diskon (Menangani Promo ATAU Voucher)
              if (hasAnyDiscount) ...[
                const SizedBox(height: 8),

                // 1. Badge Promo Code (Warna Hijau)
                if (hasPromoDiscount)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.4),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_offer,
                          size: 12,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Promo: Saved ${_currencyFormat.format(order.discountAmount)}',
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),

                // 2. Badge Voucher (Warna Ungu)
                if (hasVoucherDiscount)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.purple.withOpacity(0.4),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.card_giftcard,
                          size: 12,
                          color: Colors.purple,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Voucher: Saved ${_currencyFormat.format(order.voucherDiscountAmount)}',
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
