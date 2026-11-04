import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/order_model.dart';
import '../../core/services/order_service.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  // ✅ Simpan semua data di memori untuk filtering & counting instan
  List<Order> _allOrders = [];

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'IDR ',
    decimalDigits: 0,
  );

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
    _fetchOrders(); // Fetch sekali saat init
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ✅ DIPERBARUI: Ambil semua data, filtering dilakukan secara lokal
  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    
    // Ambil semua order tanpa filter agar kita bisa menghitung total per tab
    final orders = await OrderService.getAllOrders(statusFilter: null);
    
    if (mounted) {
      setState(() {
        _allOrders = orders;
        _isLoading = false;
      });
    }
  }

  // ✅ HELPER: Filter data secara lokal berdasarkan tab yang aktif
  List<Order> _getFilteredOrders(String tab) {
    if (tab == 'All') return _allOrders;
    return _allOrders.where((order) => order.status == tab.toLowerCase()).toList();
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
          'Manage Bookings',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        // ✅ TAB BAR DENGAN BADGE COUNTER (Sama persis dengan MyBookingsScreen)
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

  // ✅ WIDGET: List Order per Tab
  Widget _buildOrdersList(String tab) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      );
    }

    final filteredOrders = _getFilteredOrders(tab);

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppColors.textGrey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              tab == 'All' ? 'No bookings found' : 'No $tab bookings',
              style: const TextStyle(
                fontFamily: 'Lato',
                fontSize: 16,
                color: AppColors.textGrey,
              ),
            ),
          ],
        ),
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

  // ✅ WIDGET: Kartu Order (Mempertahankan desain bagus Anda sebelumnya)
  Widget _buildOrderCard(Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push('/admin/booking-detail/${order.id}').then((_) {
            _fetchOrders(); // Auto-refresh list saat kembali dari detail
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header: Order Number + Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(order.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // 2. User Name
              Text(
                order.userName ?? 'Unknown User',
                style: const TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 13,
                  color: AppColors.textGrey,
                ),
              ),
              
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // ✅ Badge Diskon (Promo atau Voucher)
              if (order.discountAmount > 0 || order.voucherDiscountAmount > 0) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Badge Promo (Hijau)
                    if (order.discountAmount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.withOpacity(0.4), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_offer, size: 12, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              'Promo: -${_currencyFormat.format(order.discountAmount)}',
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
                    
                    // Badge Voucher (Ungu)
                    if (order.voucherDiscountAmount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.purple.withOpacity(0.4), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.card_giftcard, size: 12, color: Colors.purple),
                            const SizedBox(width: 4),
                            Text(
                              'Voucher: -${_currencyFormat.format(order.voucherDiscountAmount)}',
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
                ),
                const SizedBox(height: 12),
              ],

              // 3. Footer: Date + Total Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 6),
                      Text(
                        order.formattedDate,
                        style: const TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _currencyFormat.format(order.totalAmount),
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}