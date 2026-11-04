import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/reservation_model.dart';
import '../../core/services/reservation_service.dart';

class AdminReservationsScreen extends StatefulWidget {
  const AdminReservationsScreen({super.key});

  @override
  State<AdminReservationsScreen> createState() => _AdminReservationsScreenState();
}

class _AdminReservationsScreenState extends State<AdminReservationsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  bool _isLoading = true;
  
  // ✅ Simpan semua data di memori untuk filtering & counting instan
  List<Reservation> _allReservations = [];

  // ✅ Daftar Tab (Checked Out dihapus sesuai permintaan sebelumnya)
  final List<String> _tabs = [
    'All',
    'Pending',
    'Confirmed',
    'Checked In',
    'Completed',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _fetchReservations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchReservations();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Fetch hanya sekali saat pertama kali dimuat
    if (_allReservations.isEmpty && !_isLoading) {
      _fetchReservations();
    }
  }

  // ✅ DIPERBARUI: Ambil semua data, filtering dilakukan secara lokal
  Future<void> _fetchReservations() async {
    setState(() => _isLoading = true);
    
    // Ambil semua reservasi tanpa filter agar kita bisa menghitung total per tab
    final reservations = await ReservationService.getAllReservations(statusFilter: null);
    
    if (mounted) {
      setState(() {
        _allReservations = reservations;
        _isLoading = false;
      });
    }
  }

  // ✅ HELPER: Filter data secara lokal berdasarkan tab yang aktif
  List<Reservation> _getFilteredReservations(String tab) {
    if (tab == 'All') return _allReservations;
    final statusFilter = tab.toLowerCase().replaceAll(' ', '_'); // 'Checked In' -> 'checked_in'
    return _allReservations.where((res) => res.status == statusFilter).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange.shade700;
      case 'confirmed': return Colors.green.shade700;
      case 'checked_in': return Colors.blue.shade700;
      case 'cancelled': return Colors.red.shade700;
      case 'completed': return Colors.teal.shade700;
      default: return Colors.grey;
    }
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        title: const Text(
          'Manage Reservations',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        // ✅ TAB BAR DENGAN BADGE COUNTER (Sama persis dengan Admin Bookings)
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
            final count = _getFilteredReservations(tab).length;
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
        children: _tabs.map((tab) => _buildReservationsList(tab)).toList(),
      ),
    );
  }

  // ✅ WIDGET: List Reservasi per Tab
  Widget _buildReservationsList(String tab) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      );
    }

    final filteredReservations = _getFilteredReservations(tab);

    if (filteredReservations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bed_outlined,
              size: 64,
              color: AppColors.textGrey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              tab == 'All' ? 'No reservations found' : 'No $tab reservations',
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
      onRefresh: _fetchReservations,
      color: AppColors.primaryGold,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: filteredReservations.length,
        itemBuilder: (context, index) {
          final res = filteredReservations[index];
          return _buildReservationCard(res);
        },
      ),
    );
  }

  // ✅ WIDGET: Kartu Reservasi (Mempertahankan logika diskon yang sudah bagus)
  Widget _buildReservationCard(Reservation res) {
    final statusColor = _getStatusColor(res.status);
    final int discountAmount = res.discountAmount ?? 0;
    final int voucherDiscountAmount = res.voucherDiscountAmount ?? 0;
    // final int originalPrice = res.totalAmount + discountAmount + voucherDiscountAmount;
    final bool hasDiscount = discountAmount > 0 || voucherDiscountAmount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/admin/reservation-detail/${res.id}').then((_) {
          _fetchReservations(); // Auto-refresh saat kembali dari detail
        }),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header: Reservation Number + Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RESERVATION NUMBER',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 10,
                            color: AppColors.textGrey,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          res.reservationNumber,
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
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      res.status.toUpperCase().replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 2. Room Name
              Text(
                res.roomName ?? 'Room',
                style: const TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkCharcoal,
                ),
              ),
              const SizedBox(height: 4),

              // 3. Dates
              Text(
                '${DateFormat('dd MMM').format(res.checkIn)} - ${DateFormat('dd MMM yyyy').format(res.checkOut)}',
                style: const TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 12,
                  color: AppColors.textGrey,
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // 4. Badge Diskon (Promo atau Voucher)
              if (hasDiscount) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Badge Promo (Hijau)
                    if (discountAmount > 0)
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
                              'Promo (${res.promoCode ?? 'N/A'}): -IDR ${_formatPrice(discountAmount)}',
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
                    if (voucherDiscountAmount > 0)
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
                              'Voucher: -IDR ${_formatPrice(voucherDiscountAmount)}',
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

              // 5. Footer: Total Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total to Pay',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 10,
                      color: AppColors.textGrey,
                    ),
                  ),
                  Text(
                    'IDR ${_formatPrice(res.totalAmount)}',
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 18,
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
    );
  }
}