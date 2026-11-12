import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import 'dart:typed_data';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/notification_service.dart';
import 'my_rewards_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;

  String _fullName = 'Guest User';
  String _email = 'guest@themulia.com';
  String _membership = 'SILVER';

  int _points = 0;
  int _totalStays = 0;
  int _totalServices = 0;
  int _upcomingStays = 0;

  String? _avatarUrl;
  bool _isUploading = false;

  // ✅ HELPER: Parse Int dengan Aman (Mencegah Crash jika database kirim String)
  int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // ✅ HELPER: Tentukan Warna berdasarkan Tier
  Color get _tierColor {
    switch (_membership.toUpperCase()) {
      case 'DIAMOND':
        return Colors.cyan.shade300;
      case 'GOLD':
        return AppColors.primaryGold;
      case 'SILVER':
        return Colors.blueGrey.shade400;
      default:
        return Colors.grey;
    }
  }

  // ✅ HELPER: Tentukan Ikon berdasarkan Tier
  IconData get _tierIcon {
    switch (_membership.toUpperCase()) {
      case 'DIAMOND':
        return Icons.diamond;
      case 'GOLD':
        return Icons.workspace_premium;
      case 'SILVER':
        return Icons.stars;
      default:
        return Icons.shield;
    }
  }

  // ✅ HELPER: Format Teks agar selalu rapi
  String get _formattedMembership {
    final tier = _membership.toUpperCase().replaceAll(' MEMBER', '').trim();
    return '$tier MEMBER';
  }

  // ✅ HELPER: Dapatkan Nama Tier Berikutnya
  String _getNextTier() {
    switch (_membership.toUpperCase()) {
      case 'SILVER':
        return 'GOLD';
      case 'GOLD':
        return 'DIAMOND';
      case 'DIAMOND':
        return 'DIAMOND';
      default:
        return 'GOLD';
    }
  }

  // ✅ HELPER: Hitung Sisa Poin untuk Tier Berikutnya
  String _getPointsToNextTier() {
    int targetPoints = 0;
    switch (_membership.toUpperCase()) {
      case 'SILVER':
        targetPoints = 5000;
        break;
      case 'GOLD':
        targetPoints = 15000;
        break;
      case 'DIAMOND':
        return '0';
      default:
        targetPoints = 5000;
    }

    int needed = targetPoints - _points;
    if (needed <= 0) return '0';

    return needed.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  Future<void> _uploadAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null) return;

    final String? userId = AuthService.currentUserId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in first.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (mounted) setState(() => _isUploading = true);

    try {
      final Uint8List fileBytes = await image.readAsBytes();
      final String fileName =
          'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = '$userId/$fileName';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final String imageUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);

      await Supabase.instance.client
          .from('profiles')
          .update({'avatar_url': imageUrl})
          .eq('id', userId);

      if (mounted) {
        setState(() {
          _avatarUrl = imageUrl;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    final userId = AuthService.currentUserId;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select(
            'full_name, email, membership_tier, points, total_stays, total_services, upcoming_stays, avatar_url',
          )
          .eq('id', userId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _fullName = response['full_name'] ?? 'Guest User';
          _email = response['email'] ?? 'No Email';
          _membership = response['membership_tier'] ?? 'SILVER';

          // ✅ PERBAIKAN KRITIS: Gunakan _safeParseInt agar tidak crash
          _points = _safeParseInt(response['points']);
          _totalStays = _safeParseInt(response['total_stays']);
          _totalServices = _safeParseInt(response['total_services']);
          _upcomingStays = _safeParseInt(response['upcoming_stays']);

          _avatarUrl = response['avatar_url'];
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGold),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            actions: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      context.push('/notifications').then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                  ),
                  FutureBuilder<int>(
                    future: NotificationService.getUnreadCount(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data! > 0) {
                        return Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              snapshot.data! > 9 ? '9+' : '${snapshot.data}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.darkCharcoal,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? CircleAvatar(
                              radius: 60,
                              backgroundImage: NetworkImage(_avatarUrl!),
                              backgroundColor: AppColors.darkCharcoal,
                            )
                          : const CircleAvatar(
                              radius: 60,
                              backgroundColor: AppColors.darkCharcoal,
                              child: Icon(
                                Icons.person,
                                size: 60,
                                color: AppColors.primaryGold,
                              ),
                            ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploading ? null : _uploadAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryGold,
                              shape: BoxShape.circle,
                            ),
                            child: _isUploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fullName,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email,
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 14,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Statistik
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              // ✅ UBAH MENJADI INK WELL AGAR BISA DIKLIK
                              onTap: () {
                                // Nanti kita arahkan ke halaman History Poin
                                // context.push('/points-history');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Points History coming soon!',
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: _buildStatCard(
                                'Points',
                                _points.toString(),
                                Icons.star_rounded,
                                AppColors.primaryGold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'Total Stays',
                              _totalStays.toString(),
                              Icons.bed_outlined,
                              Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Services',
                              _totalServices.toString(),
                              Icons.spa_outlined,
                              Colors.purple.shade700,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'Upcoming',
                              _upcomingStays.toString(),
                              Icons.calendar_today_outlined,
                              Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ✅ Current Tier Card (DIPERBAIKI: Tambahkan Expanded untuk mencegah Overflow)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.darkCharcoal,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _tierColor.withOpacity(0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(
                        color: _tierColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(_tierIcon, color: _tierColor, size: 40),
                        const SizedBox(width: 16),
                        Expanded(
                          // ✅ INI YANG MENCEGAH RENDERFLEX OVERFLOW
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Current Tier',
                                style: TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 12,
                                  color: Colors.white70,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formattedMembership,
                                style: TextStyle(
                                  fontFamily: 'Playfair Display',
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _tierColor,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_membership.toUpperCase() == 'DIAMOND')
                                const Text(
                                  '🎉 You have reached our highest tier! Enjoy exclusive perks.',
                                  style: TextStyle(
                                    fontFamily: 'Lato',
                                    fontSize: 11,
                                    color: Colors.white70,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              else
                                Text(
                                  'Earn ${_getPointsToNextTier()} more points to reach ${_getNextTier()}!',
                                  style: const TextStyle(
                                    fontFamily: 'Lato',
                                    fontSize: 11,
                                    color: Colors.white70,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    'My Activities',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ✅ PERBAIKI: Gunakan Material widget agar ListTile tidak warning "ink splashes may be invisible"
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 2,
                    shadowColor: Colors.black.withOpacity(0.04),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.bed_outlined,
                              color: AppColors.primaryGold,
                              size: 24,
                            ),
                          ),
                          title: const Text(
                            'My Reservations',
                            style: TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                          subtitle: const Text(
                            'View your room stays and details',
                            style: TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.textGrey,
                          ),
                          onTap: () => context.push('/my-reservations'),
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.receipt_long,
                              color: AppColors.primaryGold,
                              size: 24,
                            ),
                          ),
                          title: const Text(
                            'My Bookings',
                            style: TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                          subtitle: const Text(
                            'View your service bookings (Spa, Dining, etc.)',
                            style: TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.textGrey,
                          ),
                          onTap: () => context.push('/my-bookings'),
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.red,
                              size: 24,
                            ),
                          ),
                          title: const Text(
                            'My Favorites',
                            style: TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                          subtitle: const Text(
                            'Spa & Dining you love',
                            style: TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.textGrey,
                          ),
                          onTap: () => context.push('/my-favorites'),
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.card_giftcard,
                              color: Colors.purple,
                              size: 24,
                            ),
                          ),
                          title: const Text(
                            'My Rewards',
                            style: TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                          subtitle: const Text(
                            'Redeem your points for exclusive rewards',
                            style: TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.textGrey,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MyRewardsScreen(),
                              ),
                            ).then((_) {
                              if (mounted) setState(() {});
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await AuthService.logout();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.red.shade200),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.darkCharcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Lato',
              fontSize: 11,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
