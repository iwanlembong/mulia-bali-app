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

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with RouteAware {
  String _userName = 'Admin';

  // ✅ VARIABEL STATS DINAMIS
  int _propertiesCount = 0;
  int _roomsCount = 0;
  int _spaCount = 0;

  // ✅ BARU: Variabel untuk menghitung antrean verifikasi
  int _pendingVerificationCount = 0;
  bool _isLoadingStats = true;

  // ✅ 1. Tambahkan variabel state ini di dalam class State
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
    _fetchPendingVerifications(); // ✅ Panggil fungsi fetch antrean verifikasi
    _fetchDashboardStats(); // ✅ Panggil saat dashboard dibuka
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Subscribe ke observer agar tahu saat layar ini muncul kembali
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    // ✅ Unsubscribe untuk mencegah memory leak
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // ✅ METHOD AJAIB: Dipanggil otomatis setiap kali Anda kembali ke Dashboard dari layar lain
  @override
  void didPopNext() {
    print('🔄 [ADMIN DASHBOARD] Kembali ke dashboard, me-refresh semua stats...');
    _fetchDashboardStats();
    _fetchStats();
    _fetchPendingVerifications();
  }

  // ✅ 2. Tambahkan method ini untuk mengambil statistik secara efisien
  Future<void> _fetchDashboardStats() async {
    setState(() => _isLoadingStats = true);

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      // ==========================================
      // 1. PENDING VERIFIKASI (Reservasi + Orders)
      // ==========================================
      final pendingRes = await Supabase.instance.client
          .from('reservations')
          .select('id')
          .eq('status', 'pending');

      final pendingOrders = await Supabase.instance.client
          .from('orders')
          .select('id')
          .eq('status', 'pending');

      // ==========================================
      // 2. CHECK-IN HARI INI (Khusus Reservasi Kamar)
      // ==========================================
      final checkins = await Supabase.instance.client
          .from('reservations')
          .select('id')
          .eq('status', 'confirmed')
          .eq('check_in', today);

      // ==========================================
      // 3. VOUCHER USED (Dari tabel redemptions)
      // ==========================================
      final vouchers = await Supabase.instance.client
          .from('redemptions')
          .select('id')
          .eq('status', 'used');

      // ==========================================
      // 4. TOTAL COMPLETED (Reservasi + Orders)
      // ==========================================
      final completedRes = await Supabase.instance.client
          .from('reservations')
          .select('id')
          .eq('status', 'completed');

      final completedOrders = await Supabase.instance.client
          .from('orders')
          .select('id')
          .eq('status', 'completed');

      // ==========================================
      // UPDATE STATE (Menjumlahkan hasil dari kedua tabel)
      // ==========================================
      setState(() {
        _dashboardStats = {
          // Total Pending = Pending Kamar + Pending Services
          'pending':
              (pendingRes as List).length + (pendingOrders as List).length,

          // Check-in hanya berlaku untuk Kamar
          'checkins': (checkins as List).length,

          // Voucher digunakan (sudah benar dari tabel redemptions)
          'vouchers': (vouchers as List).length,

          // Total Completed = Completed Kamar + Completed Services
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

  // ✅ FUNGSI BARU: Fetch jumlah antrean verifikasi (Accommodation + Services)
  Future<void> _fetchPendingVerifications() async {
    try {
      // 1. Hitung Reservations (Accommodation) yang pending & punya bukti
      final resResponse = await Supabase.instance.client
          .from('reservations')
          .select('id')
          .eq('status', 'pending')
          .isFilter('rejection_reason', null) // ✅ TAMBAHKAN INI
          .not('payment_proof_url', 'is', null);

      // 2. Hitung Orders (Services) yang pending & punya bukti
      final orderResponse = await Supabase.instance.client
          .from('orders')
          .select('id')
          .eq('status', 'pending')
          .isFilter('rejection_reason', null) // ✅ TAMBAHKAN INI
          .not('payment_proof_url', 'is', null);

      if (mounted) {
        setState(() {
          // Mengambil panjang list adalah cara paling aman untuk menghindari error RLS count
          final resCount = (resResponse as List).length;
          final orderCount = (orderResponse as List).length;
          _pendingVerificationCount = resCount + orderCount;
        });
      }
    } catch (e) {
      print('❌ Error fetching pending verifications: $e');
    }
  }

  // ✅ FUNGSI: Fetch jumlah data dari database
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

      if (mounted) {
        setState(() {
          _propertiesCount = (propertiesResponse as List).length;
          _roomsCount = (roomsResponse as List).length;
          _spaCount = (spaResponse as List).length;
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
            // ✅ 4. SISIPKAN MINI ANALYTICS DI SINI
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
                    shrinkWrap:
                        true, // ✅ Penting agar bisa di-scroll bersama halaman
                    physics: const NeverScrollableScrollPhysics(), // ✅ Scroll ditangani oleh SingleChildScrollView induk
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.1, // ✅ Membuat kartu sedikit lebih tinggi agar proporsional
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

            // ✅ Baris 3
            Row(
              children: [
                Expanded(
                  child: _buildModuleCard(
                    context,
                    icon: Icons.card_giftcard, // Ikon Hadiah
                    title: 'Rewards',
                    subtitle: 'Manage points & gifts',
                    color: Colors
                        .purple
                        .shade700, // Warna Ungu (konsisten dengan Voucher)
                    onTap: () => context.push('/admin/rewards'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModuleCard(
                    context,
                    icon: Icons.people_outline, // Ikon Anggota/User
                    title: 'Members',
                    subtitle: 'View user profiles',
                    color: Colors.blue.shade700, // Warna Biru (pembeda)
                    // Nanti bisa diarahkan ke halaman daftar member jika sudah dibuat
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Members page coming soon!'),
                        ),
                      );
                    },
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

            // ✅ BARIS 7: Payment Verification (DINAMIS)
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
                        // ✅ Subtitle berubah tergantung ada antrean atau tidak
                        subtitle: _pendingVerificationCount > 0
                            ? '$_pendingVerificationCount pending approval'
                            : 'Approve user transfers',
                        // ✅ Warna berubah jadi Orange jika ada antrean, Hijau jika aman
                        color: _pendingVerificationCount > 0
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                        onTap: () async {
                          // ✅ PERBAIKAN: Gunakan Navigator.push agar bisa mendeteksi saat kembali
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AdminPaymentVerificationScreen(),
                            ),
                          );
                          // ✅ Saat kembali dari halaman verifikasi, refresh counter secara otomatis
                          _fetchPendingVerifications();
                        },
                      ),
                      // ✅ BADGE MERAH POJOK KANAN ATAS (Jika ada antrean)
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

            // STATS SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment
                  .spaceBetween, // ✅ Mendorong teks ke kiri, tombol ke kanan
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

                // ✅ Tombol Refresh
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: AppColors.primaryGold,
                    size: 24,
                  ),
                  onPressed: () async {
                    // 1. Refresh data statistik baru (Pending, Check-in, Voucher, Completed)
                    await _fetchDashboardStats();

                    // 2. Refresh data statistik lama (Properties, Rooms, Spa)
                    // (Pastikan method _fetchStats() masih ada di class Anda)
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
                : Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Properties', // ✅ Gunakan named parameter
                          value: _propertiesCount, // ✅ Kirim sebagai int, bukan .toString()
                          icon: Icons.business,
                          color: Colors
                              .blue
                              .shade700, // ✅ Tambahkan warna yang wajib
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Rooms',
                          value: _roomsCount,
                          icon: Icons.bed,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Spa',
                          value: _spaCount,
                          icon: Icons.spa,
                          color: Colors.purple.shade700,
                        ),
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

  // ✅ 3. Widget Helper untuk Kartu Statistik
  Widget _buildStatCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Text(
                value.toString(),
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkCharcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Lato',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textGrey,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
