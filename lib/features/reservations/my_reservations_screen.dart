import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/reservation_model.dart';
import '../../core/services/reservation_service.dart';
import '../../core/widgets/shimmer_card.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/services/review_service.dart';
import '../../core/widgets/review_modal.dart';

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  bool _isLoading = true;
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

  Set<String> _reviewedItemIds = {}; // Menyimpan ID kamar yang sudah direview

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

  Future<void> _fetchReservations() async {
    setState(() => _isLoading = true);

    // Ambil semua data, filtering akan dilakukan secara lokal di memori
    final reservations = await ReservationService.getUserReservations(
      statusFilter: 'all',
    );

 // ✅ Ambil ID item yang sudah direview
    final reviewedIds = await ReviewService.getUserReviewedItemIds();

    if (mounted) {
      setState(() {
        _allReservations = reservations;
        _reviewedItemIds = reviewedIds; // ✅ Simpan ke state
        _isLoading = false;
      });
    }
  }

  // ✅ HELPER: Filter data secara lokal berdasarkan tab yang aktif
  List<Reservation> _getFilteredReservations(String tab) {
    if (tab == 'All') return _allReservations;
    final statusFilter = tab.toLowerCase().replaceAll(
      ' ',
      '_',
    ); // 'Checked In' -> 'checked_in'
    return _allReservations.where((res) => res.status == statusFilter).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange.shade700;
      case 'confirmed':
        return Colors.green.shade700;
      case 'checked_in':
        return Colors.blue.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      case 'completed':
        return Colors.teal.shade700;
      default:
        return AppColors.textGrey;
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
          'My Reservations',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        // ✅ TAB BAR DENGAN BADGE COUNTER
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
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4, // Tampilkan 4 kartu shimmer
        itemBuilder: (context, index) => const ShimmerCard(),
      );
    }

    final filteredReservations = _getFilteredReservations(tab);

    if (filteredReservations.isEmpty) {
      // return _buildEmptyState(tab);
      return EmptyStateWidget(
        icon: Icons.bed_outlined,

        // ✅ JUDUL DINAMIS
        title: tab == 'All' ? 'No Reservations Yet' : 'No $tab Reservations',

        // ✅ SUBTITLE DINAMIS
        subtitle: tab == 'All'
            ? 'Start exploring our luxury rooms and make your first booking.'
            : 'You don\'t have any reservations with "$tab" status yet.',

        // ✅ TOMBOL: Hanya muncul jika di tab 'All'
        buttonText: tab == 'All' ? 'Browse Rooms' : null,
        onButtonPressed: tab == 'All' ? () => context.go('/properties') : null,
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

  // ✅ WIDGET: Empty State
  // Widget _buildEmptyState(String tab) {
  //   return Center(
  //     child: Padding(
  //       padding: const EdgeInsets.all(32),
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           Icon(
  //             Icons.bed_outlined,
  //             size: 64,
  //             color: AppColors.textGrey.withOpacity(0.5),
  //           ),
  //           const SizedBox(height: 16),
  //           Text(
  //             tab == 'All' ? 'No reservations yet' : 'No $tab reservations',
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
  //                 ? 'Start exploring our rooms and make your first booking.'
  //                 : 'Reservations with "$tab" status will appear here.',
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
  //               onPressed: () => context.go('/properties'),
  //               icon: const Icon(Icons.explore, size: 18),
  //               label: const Text('BROWSE ROOMS'),
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

  // ✅ WIDGET: Kartu Reservasi (Mempertahankan logika diskon yang sudah bagus)
  Widget _buildReservationCard(Reservation res) {
    final statusColor = _getStatusColor(res.status);
    final int discountAmount = res.discountAmount ?? 0;
    final int voucherDiscountAmount = res.voucherDiscountAmount ?? 0;
    // final int originalPrice = res.totalAmount + discountAmount + voucherDiscountAmount;
    final bool hasDiscount = discountAmount > 0 || voucherDiscountAmount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final result = await context.push<bool>(
            '/reservation-detail/${res.id}',
          );
          if (result == true && mounted) {
            _fetchReservations(); // Auto-refresh jika ada perubahan
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Reservation Number + Status
              Row(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      res.status.toUpperCase().replaceAll('_', ' '),
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Room Name
              Text(
                res.roomName ?? 'Room',
                style: const TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkCharcoal,
                ),
              ),
              const SizedBox(height: 8),

              // Dates
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: AppColors.textGrey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${DateFormat('dd MMM').format(res.checkIn)} - ${DateFormat('dd MMM yyyy').format(res.checkOut)}',
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 13,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Guests
              Row(
                children: [
                  const Icon(Icons.people, size: 14, color: AppColors.textGrey),
                  const SizedBox(width: 6),
                  Text(
                    '${res.adults} Adults, ${res.children} Children • ${res.roomCount} Room(s)',
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 13,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),

              // Rejection Reason Badge (Jika ada)
              if (res.status == 'pending' &&
                  res.rejectionReason != null &&
                  res.rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Payment revision required',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Footer: Total & Discount Badges
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
                    'IDR ${_formatPrice(res.totalAmount)}',
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                ],
              ),

              // Badge Diskon
              if (hasDiscount) ...[
                const SizedBox(height: 8),
                if (discountAmount > 0)
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
                          'Promo (${res.promoCode ?? 'N/A'}): Saved IDR ${_formatPrice(discountAmount)}',
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
                if (voucherDiscountAmount > 0) ...[
                  const SizedBox(height: 6),
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
                          'Voucher: Saved IDR ${_formatPrice(voucherDiscountAmount)}',
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
              // ✅ LOGIKA TOMBOL REVIEW YANG CERDAS (Menggunakan _reviewedItemIds)
              if (res.status == 'completed') ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Cek apakah roomId ini sudah ada di dalam Set _reviewedItemIds
                if (_reviewedItemIds.contains(res.propertyId))
                  // ✅ TAMPILAN 1: Jika SUDAH direview (Badge Hijau)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'REVIEWED',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // ✅ TAMPILAN 2: Jika BELUM direview (Tombol)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (context) => ReviewModal(
                            itemType: 'property', // Tipe untuk kamar hotel
                            itemId: res.propertyId, // ✅ Menggunakan Property ID
                            onReviewSubmitted: _fetchReservations, // Refresh otomatis
                          ),
                        );
                      },
                      icon: const Icon(Icons.rate_review, size: 18),
                      label: const Text(
                        'WRITE A REVIEW',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGold,
                        side: const BorderSide(color: AppColors.primaryGold),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
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
