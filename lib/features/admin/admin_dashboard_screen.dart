import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shimmer_card.dart';
import 'admin_payment_verification_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with RouteAware {
  String _userName = 'Admin';

  // ✅ VARIABEL STATS DINAMIS
  int _propertiesCount = 0;
  int _roomsCount = 0;
  int _spaCount = 0;

  // ✅ BARU: Variabel untuk Restaurants, Menus, dan Weddings
  int _restaurantsCount = 0;
  int _menusCount = 0;
  int _weddingsCount = 0;

  // ✅ Variabel untuk menghitung antrean verifikasi
  int _pendingVerificationCount = 0;

  // ✅ Variabel state untuk statistik dashboard
  Map<String, int> _dashboardStats = {
    'pending': 0,
    'checkins': 0,
    'vouchers': 0,
    'completed': 0,
  };

  bool _isRouteSubscribed = false; // ✅ Mencegah subscribe berulang kali

  bool _isFirstLoad =
      true; // ✅ Penentu apakah ini loading pertama kali atau bukan

  // ✅ RESPONSIVE HELPER: Breakpoint yang lebih tegas untuk desktop
  int _getOverviewColumns(double width) {
    if (width >= 1200) return 4; // Desktop: 4 kolom
    if (width >= 768) return 4; // Tablet besar: 4 kolom
    if (width >= 600) return 2; // Tablet kecil: 2 kolom
    return 2; // HP: 2 kolom
  }

  int _getModuleColumns(double width) {
    if (width >= 1200) return 4; // Desktop: 4 kolom
    if (width >= 900) return 3; // Tablet besar: 3 kolom
    if (width >= 600) return 2; // Tablet kecil: 2 kolom
    return 2; // HP: 2 kolom
  }

  int _getQuickStatusColumns(double width) {
    if (width >= 1400) return 6; // Desktop besar: 6 kolom (1 baris penuh)
    if (width >= 1200) return 3; // Desktop: 3 kolom (2 baris)
    if (width >= 768) return 3; // Tablet: 3 kolom
    return 3; // HP: 3 kolom
  }

  double _getCardWidth(double totalWidth, int columns) {
    // Hitung lebar kartu: (lebar total - padding kiri/kanan - spacing antar kolom) / jumlah kolom
    final totalSpacing = (columns - 1) * 16.0;
    final padding = totalWidth > 900
        ? 64.0
        : 32.0; // Padding lebih besar di desktop
    return (totalWidth - padding - totalSpacing) / columns;
  }

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadAllDashboardData(
      showLoading: true,
    ); // ✅ Hanya tampilkan loading saat PERTAMA KALI buka
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ✅ PERBAIKAN: Hanya subscribe SEKALI untuk mencegah memory leak
    if (!_isRouteSubscribed) {
      final route = ModalRoute.of(context);
      if (route != null) {
        routeObserver.subscribe(this, route);
        _isRouteSubscribed = true;
      }
    }
  }

  @override
  void dispose() {
    if (_isRouteSubscribed) {
      routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  @override
  void didPopNext() {
    print(
      '🔄 [ADMIN DASHBOARD] Kembali ke dashboard, silent refresh (TANPA SHIMMER)...',
    );
    // ✅ Refresh di background TANPA menampilkan loading shimmer
    _loadAllDashboardData(showLoading: false);
  }

  Future<void> _loadAllDashboardData({required bool showLoading}) async {
    if (showLoading && mounted) {
      setState(() => _isFirstLoad = true);
    }

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      // ✅ PERBAIKAN: Dataran (flatten) semua query ke dalam SATU Future.wait.
      // Ini memperbaiki error type inference DAN tetap berjalan paralel (sangat cepat).
      // Kami menambahkan <dynamic> agar Dart tidak bingung menebak tipe data.
      final results = await Future.wait<dynamic>([
        // 1. Dashboard Stats (6 queries)
        Supabase.instance.client
            .from('reservations')
            .select('id')
            .eq('status', 'pending')
            .limit(1000), // Index 0
        Supabase.instance.client
            .from('orders')
            .select('id')
            .eq('status', 'pending')
            .limit(1000), // Index 1
        Supabase.instance.client
            .from('reservations')
            .select('id')
            .eq('status', 'confirmed')
            .eq('check_in', today)
            .limit(1000), // Index 2
        Supabase.instance.client
            .from('redemptions')
            .select('id')
            .eq('status', 'used')
            .limit(1000), // Index 3
        Supabase.instance.client
            .from('reservations')
            .select('id')
            .eq('status', 'completed')
            .limit(1000), // Index 4
        Supabase.instance.client
            .from('orders')
            .select('id')
            .eq('status', 'completed')
            .limit(1000), // Index 5
        // 2. Pending Verifications (1 query)
        Supabase.instance.client
            .from('order_payments')
            .select('id')
            .eq('status', 'pending')
            .limit(1000), // Index 6
        // 3. Content Stats (6 queries)
        Supabase.instance.client
            .from('properties')
            .select('id')
            .limit(1000), // Index 7
        Supabase.instance.client
            .from('rooms')
            .select('id')
            .limit(1000), // Index 8
        Supabase.instance.client
            .from('spa_services')
            .select('id')
            .limit(1000), // Index 9
        Supabase.instance.client
            .from('restaurants')
            .select('id')
            .limit(1000), // Index 10
        Supabase.instance.client
            .from('menu_items')
            .select('id')
            .limit(1000), // Index 11
        Supabase.instance.client
            .from('weddings')
            .select('id')
            .limit(1000), // Index 12
      ]);

      if (mounted) {
        setState(() {
          // ✅ Parse Dashboard Stats (sesuai index di atas)
          _dashboardStats = {
            'pending':
                (results[0] as List).length + (results[1] as List).length,
            'checkins': (results[2] as List).length,
            'vouchers': (results[3] as List).length,
            'completed':
                (results[4] as List).length + (results[5] as List).length,
          };

          // ✅ Parse Pending Verifications
          _pendingVerificationCount = (results[6] as List).length;

          // ✅ Parse Content Stats
          _propertiesCount = (results[7] as List).length;
          _roomsCount = (results[8] as List).length;
          _spaCount = (results[9] as List).length;
          _restaurantsCount = (results[10] as List).length;
          _menusCount = (results[11] as List).length;
          _weddingsCount = (results[12] as List).length;

          // ✅ MATIKAN loading selamanya setelah data pertama kali sukses dimuat
          _isFirstLoad = false;
        });
      }
    } catch (e) {
      print('❌ Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _isFirstLoad = false);
      }
    }
  }

  Future<void> _loadUserInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted && response != null && response['full_name'] != null) {
          setState(() => _userName = response['full_name']);
        }
      } catch (e) {
        print('Error loading user info: $e');
      }
    }
  }

  Future<void> _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    // ✅ WRAPPER DESKTOP: Membuat tampilan rapi di tengah layar desktop
    return Container(
      color: const Color(
        0xFFF5F5F5,
      ), // Warna abu-abu muda untuk area kosong di desktop
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1000,
          ), // Batas lebar maksimal 1000px
          child: Scaffold(
            backgroundColor: AppColors.offWhite,
            appBar: AppBar(
              backgroundColor: AppColors.darkCharcoal,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text(
                'Mulia CMS Dashboard',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: _handleLogout,
                  tooltip: 'Logout',
                ),
              ],
            ),

            // ✅ HANYA SATU SingleChildScrollView di tingkat teratas
            body: LayoutBuilder(
              builder: (context, constraints) {
                // ✅ Ambil lebar layar untuk perhitungan responsif
                final screenWidth = constraints.maxWidth;
                final isDesktop = screenWidth > 900;

                // Hitung lebar kartu untuk setiap section
                final overviewCardWidth = _getCardWidth(
                  screenWidth,
                  _getOverviewColumns(screenWidth),
                );
                final quickStatusCardWidth = _getCardWidth(
                  screenWidth,
                  _getQuickStatusColumns(screenWidth),
                );

                return SingleChildScrollView(
                  padding: EdgeInsets.all(
                    isDesktop ? 32.0 : 16.0,
                  ), // Padding lebih besar di desktop
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Welcome Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isDesktop ? 32 : 20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.darkCharcoal, Color(0xFF4A4A4A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome back,',
                              style: TextStyle(
                                fontFamily: 'Lato',
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userName,
                              style: TextStyle(
                                fontFamily: 'Playfair Display',
                                fontSize: isDesktop ? 32 : 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Manage your hotel content and reservations.',
                              style: TextStyle(
                                fontFamily: 'Lato',
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      Text(
                        'Dashboard Overview',
                        style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: isDesktop ? 22 : 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ✅ 2. DASHBOARD OVERVIEW - RESPONSIF
                      _isFirstLoad
                          ? Wrap(
                              runSpacing: 16,
                              spacing: 16,
                              children: List.generate(
                                4,
                                (i) => SizedBox(
                                  width: overviewCardWidth,
                                  child: const ShimmerStatCard(),
                                ),
                              ),
                            )
                          : Wrap(
                              runSpacing: 16,
                              spacing: 16,
                              children: [
                                SizedBox(
                                  width: overviewCardWidth,
                                  child: _buildStatCard(
                                    title: 'Pending',
                                    value: _dashboardStats['pending']!,
                                    icon: Icons.hourglass_empty,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                                SizedBox(
                                  width: overviewCardWidth,
                                  child: _buildStatCard(
                                    title: 'Check-ins',
                                    value: _dashboardStats['checkins']!,
                                    icon: Icons.login,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                SizedBox(
                                  width: overviewCardWidth,
                                  child: _buildStatCard(
                                    title: 'Vouchers',
                                    value: _dashboardStats['vouchers']!,
                                    icon: Icons.card_giftcard,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                                SizedBox(
                                  width: overviewCardWidth,
                                  child: _buildStatCard(
                                    title: 'Completed',
                                    value: _dashboardStats['completed']!,
                                    icon: Icons.check_circle_outline,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),

                      const SizedBox(height: 32),
                      Text(
                        'Content Management',
                        style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: isDesktop ? 22 : 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ✅ 3. CONTENT MANAGEMENT - RESPONSIF
                      _buildResponsiveModuleGrid(screenWidth),

                      const SizedBox(height: 16),

                      // ✅ 4. QUICK STATUS HEADER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Quick Status',
                            style: TextStyle(
                              fontFamily: 'Playfair Display',
                              fontSize: isDesktop ? 22 : 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              color: AppColors.primaryGold,
                              size: 24,
                            ),
                            onPressed: () =>
                                _loadAllDashboardData(showLoading: true),
                            tooltip: 'Refresh',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ✅ 5. QUICK STATUS CARDS - RESPONSIF
                      _isFirstLoad
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryGold,
                                ),
                              ),
                            )
                          : Wrap(
                              runSpacing: 12,
                              spacing: 12,
                              children: [
                                SizedBox(
                                  width: quickStatusCardWidth,
                                  child: _buildStatCard(
                                    title: 'Properties',
                                    value: _propertiesCount,
                                    icon: Icons.business,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                SizedBox(
                                  width: quickStatusCardWidth,
                                  child: _buildStatCard(
                                    title: 'Rooms',
                                    value: _roomsCount,
                                    icon: Icons.bed,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                SizedBox(
                                  width: quickStatusCardWidth,
                                  child: _buildStatCard(
                                    title: 'Spa',
                                    value: _spaCount,
                                    icon: Icons.spa,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                                SizedBox(
                                  width: quickStatusCardWidth,
                                  child: _buildStatCard(
                                    title: 'Restaurants',
                                    value: _restaurantsCount,
                                    icon: Icons.restaurant,
                                    color: const Color(0xFF6B8E23),
                                  ),
                                ),
                                SizedBox(
                                  width: quickStatusCardWidth,
                                  child: _buildStatCard(
                                    title: 'Menus',
                                    value: _menusCount,
                                    icon: Icons.menu_book,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                                SizedBox(
                                  width: quickStatusCardWidth,
                                  child: _buildStatCard(
                                    title: 'Weddings',
                                    value: _weddingsCount,
                                    icon: Icons.favorite,
                                    color: Colors.pink.shade300,
                                  ),
                                ),
                              ],
                            ),
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            ),
          ), // Tutup Scaffold
        ), // Tutup ConstrainedBox
      ), // Tutup Center
    ); // Tutup Container
  }

  // ✅ Helper untuk Badge pada Module Card
  Widget _buildModuleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool showBadge = false,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 11,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (showBadge)
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ✅ FUNGSI BARU: Grid modul yang responsif (2/3/4 kolom)
  Widget _buildResponsiveModuleGrid(double screenWidth) {
    final columns = _getModuleColumns(screenWidth);
    final cardWidth = _getCardWidth(screenWidth, columns);

    // Daftar semua modul termasuk Payment Verification
    final modules = [
      {
        'icon': Icons.business,
        'title': 'Properties',
        'subtitle': 'Manage hotels',
        'color': AppColors.primaryGold,
        'route': '/admin/properties',
        'usePush': false,
        'isPayment': false,
      },
      {
        'icon': Icons.spa,
        'title': 'Spa Services',
        'subtitle': 'Treatments',
        'color': const Color(0xFF8B7355),
        'route': '/admin/spa',
        'usePush': false,
        'isPayment': false,
      },
      {
        'icon': Icons.restaurant,
        'title': 'Restaurants',
        'subtitle': 'Menus & dining',
        'color': const Color(0xFF6B8E23),
        'route': '/admin/restaurants',
        'usePush': false,
        'isPayment': false,
      },
      {
        'icon': Icons.confirmation_num_outlined,
        'title': 'Promo Codes',
        'subtitle': 'Discount rules',
        'color': Colors.green.shade700,
        'route': '/admin/promotions',
        'usePush': true,
        'isPayment': false,
      },
      {
        'icon': Icons.card_giftcard,
        'title': 'Rewards',
        'subtitle': 'Points & gifts',
        'color': Colors.purple.shade700,
        'route': '/admin/rewards',
        'usePush': true,
        'isPayment': false,
      },
      {
        'icon': Icons.rate_review,
        'title': 'Reviews',
        'subtitle': 'Moderate reviews',
        'color': Colors.orange.shade700,
        'route': '/admin/reviews',
        'usePush': true,
        'isPayment': false,
      },
      {
        'icon': Icons.auto_awesome,
        'title': 'Experiences',
        'subtitle': 'Activities',
        'color': const Color(0xFF008080),
        'route': '/admin/experiences',
        'usePush': false,
        'isPayment': false,
      },
      {
        'icon': Icons.favorite,
        'title': 'Weddings',
        'subtitle': 'Packages',
        'color': Colors.pink.shade300,
        'route': '/admin/weddings',
        'usePush': false,
        'isPayment': false,
      },
      {
        'icon': Icons.receipt_long,
        'title': 'Bookings',
        'subtitle': 'Service orders',
        'color': Colors.blue.shade700,
        'route': '/admin/bookings',
        'usePush': true,
        'isPayment': false,
      },
      {
        'icon': Icons.bed_outlined,
        'title': 'Reservations',
        'subtitle': 'Room bookings',
        'color': const Color(0xFF9370DB),
        'route': '/admin/reservations',
        'usePush': true,
        'isPayment': false,
      },
      // ✅ PAYMENT VERIFICATION SEKARANG DI DALAM GRID
      {
        'icon': Icons.verified_user_outlined,
        'title': 'Payment Verification',
        'subtitle': _pendingVerificationCount > 0
            ? '$_pendingVerificationCount pending'
            : 'Approve transfers',
        'color': _pendingVerificationCount > 0
            ? Colors.orange.shade700
            : Colors.green.shade700,
        'route': '',
        'usePush': false,
        'isPayment': true,
      },
    ];

    return Wrap(
      runSpacing: 16,
      spacing: 16,
      children: modules.map((m) {
        final isPayment = m['isPayment'] as bool;

        return SizedBox(
          width: cardWidth,
          child: _buildModuleCard(
            context,
            icon: m['icon'] as IconData,
            title: m['title'] as String,
            subtitle: m['subtitle'] as String,
            color: m['color'] as Color,
            // ✅ Badge hanya untuk Payment Verification
            showBadge: isPayment && _pendingVerificationCount > 0,
            badgeCount: _pendingVerificationCount,
            onTap: () async {
              if (isPayment) {
                // Payment Verification pakai Navigator.push (bukan go_router)
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const AdminPaymentVerificationScreen(),
                  ),
                );
                _loadAllDashboardData(showLoading: false);
              } else {
                // Modul biasa pakai go_router
                final usePush = m['usePush'] as bool;
                final route = m['route'] as String;
                if (usePush) {
                  context.push(route);
                } else {
                  context.go(route);
                }
              }
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkCharcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Lato',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textGrey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
