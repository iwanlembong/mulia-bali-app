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
  bool _isLoadingStats = true;

  // ✅ Variabel state untuk statistik dashboard
  Map<String, int> _dashboardStats = {
    'pending': 0,
    'checkins': 0,
    'vouchers': 0,
    'completed': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchStats();
    _fetchPendingVerifications();
    _fetchDashboardStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    print(
      '🔄 [ADMIN DASHBOARD] Kembali ke dashboard, me-refresh semua stats...',
    );
    _fetchDashboardStats();
    _fetchStats();
    _fetchPendingVerifications();
  }

  Future<void> _fetchDashboardStats() async {
    setState(() => _isLoadingStats = true);

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final pendingRes = await Supabase.instance.client
          .from('reservations')
          .select('id')
          .eq('status', 'pending');
      final pendingOrders = await Supabase.instance.client
          .from('orders')
          .select('id')
          .eq('status', 'pending');
      final checkins = await Supabase.instance.client
          .from('reservations')
          .select('id')
          .eq('status', 'confirmed')
          .eq('check_in', today);
      final vouchers = await Supabase.instance.client
          .from('redemptions')
          .select('id')
          .eq('status', 'used');
      final completedRes = await Supabase.instance.client
          .from('reservations')
          .select('id')
          .eq('status', 'completed');
      final completedOrders = await Supabase.instance.client
          .from('orders')
          .select('id')
          .eq('status', 'completed');

      setState(() {
        _dashboardStats = {
          'pending':
              (pendingRes as List).length + (pendingOrders as List).length,
          'checkins': (checkins as List).length,
          'vouchers': (vouchers as List).length,
          'completed':
              (completedRes as List).length + (completedOrders as List).length,
        };
        _isLoadingStats = false;
      });
    } catch (e) {
      print('❌ Error fetching dashboard stats: $e');
      setState(() => _isLoadingStats = false);
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

  Future<void> _fetchPendingVerifications() async {
    try {
      final resResponse = await Supabase.instance.client
          .from('reservations')
          .select('id')
          .eq('status', 'pending')
          .isFilter('rejection_reason', null)
          .not('payment_proof_url', 'is', null);

      final orderResponse = await Supabase.instance.client
          .from('orders')
          .select('id')
          .eq('status', 'pending')
          .isFilter('rejection_reason', null)
          .not('payment_proof_url', 'is', null);

      if (mounted) {
        setState(() {
          final resCount = (resResponse as List).length;
          final orderCount = (orderResponse as List).length;
          _pendingVerificationCount = resCount + orderCount;
        });
      }
    } catch (e) {
      print('❌ Error fetching pending verifications: $e');
    }
  }

  // ✅ DIPERBARUI: Fetch jumlah data termasuk Restaurants, Menus, dan Weddings
  Future<void> _fetchStats() async {
    setState(() => _isLoadingStats = true);

    try {
      final propertiesResponse = await Supabase.instance.client
          .from('properties')
          .select('id');
      final roomsResponse = await Supabase.instance.client
          .from('rooms')
          .select('id');
      final spaResponse = await Supabase.instance.client
          .from('spa_services')
          .select('id');

      // ✅ BARU: Fetch data tambahan
      final restaurantsResponse = await Supabase.instance.client
          .from('restaurants')
          .select('id');
      final menusResponse = await Supabase.instance.client
          .from('menu_items')
          .select('id'); // ⚠️ Ganti 'menu_items' menjadi 'menus' jika nama tabel Anda berbeda
      final weddingsResponse = await Supabase.instance.client
          .from('weddings')
          .select('id');

      if (mounted) {
        setState(() {
          _propertiesCount = (propertiesResponse as List).length;
          _roomsCount = (roomsResponse as List).length;
          _spaCount = (spaResponse as List).length;

          // ✅ BARU: Update state
          _restaurantsCount = (restaurantsResponse as List).length;
          _menusCount = (menusResponse as List).length;
          _weddingsCount = (weddingsResponse as List).length;

          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('Error fetching stats: $e');
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.darkCharcoal, Color(0xFF4A4A4A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
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
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userName,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Manage your hotel content, reservations, and more from this dashboard.',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Dashboard Overview',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 16),

            _isLoadingStats
                ? GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: const [
                      ShimmerStatCard(),
                      ShimmerStatCard(),
                      ShimmerStatCard(),
                      ShimmerStatCard(),
                    ],
                  )
                : GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      _buildStatCard(
                        title: 'Pending Verification',
                        value: _dashboardStats['pending']!,
                        icon: Icons.hourglass_empty,
                        color: Colors.orange.shade700,
                      ),
                      _buildStatCard(
                        title: 'Check-ins Today',
                        value: _dashboardStats['checkins']!,
                        icon: Icons.login,
                        color: Colors.blue.shade700,
                      ),
                      _buildStatCard(
                        title: 'Vouchers Redeemed',
                        value: _dashboardStats['vouchers']!,
                        icon: Icons.card_giftcard,
                        color: Colors.purple.shade700,
                      ),
                      _buildStatCard(
                        title: 'Total Completed',
                        value: _dashboardStats['completed']!,
                        icon: Icons.check_circle_outline,
                        color: Colors.green.shade700,
                      ),
                    ],
                  ),
            const SizedBox(height: 32),

            const Text(
              'Content Management',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 16),

            // Baris 1
            Row(
              children: [
                Expanded(
                  child: _buildModuleCard(
                    context,
                    icon: Icons.business,
                    title: 'Properties',
                    subtitle: 'Manage hotels & rooms',
                    color: AppColors.primaryGold,
                    onTap: () => context.go('/admin/properties'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModuleCard(
                    context,
                    icon: Icons.spa,
                    title: 'Spa Services',
                    subtitle: 'Treatments & pricing',
                    color: const Color(0xFF8B7355),
                    onTap: () => context.go('/admin/spa'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Baris 2
            Row(
              children: [
                Expanded(
                  child: _buildModuleCard(
                    context,
                    icon: Icons.restaurant,
                    title: 'Restaurants',
                    subtitle: 'Menus & dining',
                    color: const Color(0xFF6B8E23),
                    onTap: () => context.go('/admin/restaurants'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModuleCard(
                    context,
                    icon: Icons.confirmation_num_outlined,
                    title: 'Promo Codes',
                    subtitle: 'Manage discount rules',
                    color: Colors.green.shade700,
                    onTap: () => context.push('/admin/promotions'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Baris 3
            Row(
              children: [
                Expanded(
                  child: _buildModuleCard(
                    context,
                    icon: Icons.card_giftcard,
                    title: 'Rewards',
                    subtitle: 'Manage points & gifts',
                    color: Colors.purple.shade700,
                    onTap: () => context.push('/admin/rewards'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModuleCard(
                    context,
                    icon: Icons.people_outline,
                    title: 'Members',
                    subtitle: 'View user profiles',
                    color: Colors.blue.shade700,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Members page coming soon!'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Baris 4
            Row(
              children: [
                Expanded(
                  child: _buildModuleCard(
                    context,
                    icon: Icons.local_offer,
                    title: 'Special Offers',
                    subtitle: 'Promotions & deals',
                    color: const Color(0xFFCD5C5C),
                    onTap: () => context.go('/admin/special-offers'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModuleCard(
                    context,
                    icon: Icons.image,
                    title: 'Hero Slides',
                    subtitle: 'Home banner',
                    color: const Color(0xFF4682B4),
                    onTap: () => context.go('/admin/hero-slides'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Baris 5
            Row(
              children: [
                Expanded(
                  child: _buildModuleCard(
                    context,
                    icon: Icons.auto_awesome,
                    title: 'Experiences',
                    subtitle: 'Activities & events',
                    color: const Color(0xFF008080),
                    onTap: () => context.go('/admin/experiences'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModuleCard(
                    context,
                    icon: Icons.favorite,
                    title: 'Weddings',
                    subtitle: 'Wedding packages',
                    color: Colors.pink.shade300,
                    onTap: () => context.go('/admin/weddings'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Baris 6
            Row(
              children: [
                Expanded(
                  child: _buildModuleCard(
                    context,
                    title: 'Bookings',
                    subtitle: 'Manage service orders',
                    icon: Icons.receipt_long,
                    color: Colors.blue.shade700,
                    onTap: () => context.push('/admin/bookings'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModuleCard(
                    context,
                    icon: Icons.bed_outlined,
                    title: 'Reservations',
                    subtitle: 'Manage room bookings',
                    color: const Color(0xFF9370DB),
                    onTap: () => context.push('/admin/reservations'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // BARIS 7: Payment Verification (DINAMIS)
            Row(
              children: [
                Expanded(
                  child: _buildModuleCard(
                    context,
                    icon: Icons.receipt_long,
                    title: 'Voucher History',
                    subtitle: 'See all point redemptions',
                    color: Colors.purple.shade700,
                    onTap: () => context.push('/admin/redemptions'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Stack(
                    children: [
                      _buildModuleCard(
                        context,
                        icon: Icons.verified_user_outlined,
                        title: 'Payment Verification',
                        subtitle: _pendingVerificationCount > 0
                            ? '$_pendingVerificationCount pending approval'
                            : 'Approve user transfers',
                        color: _pendingVerificationCount > 0
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AdminPaymentVerificationScreen(),
                            ),
                          );
                          _fetchPendingVerifications();
                        },
                      ),
                      if (_pendingVerificationCount > 0)
                        Positioned(
                          right: 12,
                          top: 12,
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
                              _pendingVerificationCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ✅ STATS SECTION (DIPERBARUI MENJADI GRID 3 KOLOM)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quick Status',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 18,
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
                  onPressed: () async {
                    await _fetchDashboardStats();
                    await _fetchStats();
                  },
                  tooltip: 'Refresh All Data',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 16),

            _isLoadingStats
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGold,
                      ),
                    ),
                  )
                : GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount:
                        3, // ✅ 3 kolom agar muat 6 item dengan rapi (2 baris)
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.0, // ✅ Menyesuaikan proporsi kartu
                    children: [
                      _buildStatCard(
                        title: 'Properties',
                        value: _propertiesCount,
                        icon: Icons.business,
                        color: Colors.blue.shade700,
                      ),
                      _buildStatCard(
                        title: 'Rooms',
                        value: _roomsCount,
                        icon: Icons.bed,
                        color: Colors.green.shade700,
                      ),
                      _buildStatCard(
                        title: 'Spa',
                        value: _spaCount,
                        icon: Icons.spa,
                        color: Colors.purple.shade700,
                      ),
                      _buildStatCard(
                        title: 'Restaurants',
                        value: _restaurantsCount,
                        icon: Icons.restaurant,
                        color: const Color(0xFF6B8E23),
                      ),
                      _buildStatCard(
                        title: 'Menus',
                        value: _menusCount,
                        icon: Icons.menu_book,
                        color: Colors.orange.shade700,
                      ),
                      _buildStatCard(
                        title: 'Weddings',
                        value: _weddingsCount,
                        icon: Icons.favorite,
                        color: Colors.pink.shade300,
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Lato',
                fontSize: 12,
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(
        12,
      ), // ✅ Sedikit diperkecil agar muat di 3 kolom
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkCharcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Lato',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textGrey,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
