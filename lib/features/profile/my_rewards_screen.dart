import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/reward_model.dart';
import '../../core/services/reward_service.dart';
import '../../core/services/auth_service.dart';

class MyRewardsScreen extends StatefulWidget {
  const MyRewardsScreen({super.key});

  @override
  State<MyRewardsScreen> createState() => _MyRewardsScreenState();
}

class _MyRewardsScreenState extends State<MyRewardsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Reward> _rewards = [];
  List<Redemption> _myVouchers = [];
  int _currentPoints = 0;
  String _currentTier = 'SILVER';

  late TabController _tabController;

  // ✅ HELPER: Parse Int dengan Aman (Mencegah Crash)
  int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // ✅ HELPER: Format Tanggal dengan Aman
  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Unknown Date';

    try {
      if (dateValue is DateTime) {
        return DateFormat('dd MMM yyyy').format(dateValue);
      } else if (dateValue is String) {
        return DateFormat('dd MMM yyyy').format(DateTime.parse(dateValue));
      }
    } catch (e) {
      return 'Invalid Date';
    }
    return 'Unknown Date';
  }

  // ✅ HELPER: Ikon Tier untuk Header Poin
  IconData get _tierIcon {
    switch (_currentTier.toUpperCase()) {
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final userId = AuthService.currentUserId;

    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Fetch Data Paralel
      final rewards = await RewardService.getActiveRewards();
      final vouchers = await RewardService.getUserRedemptions();

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('points, membership_tier')
          .eq('id', userId)
          .maybeSingle(); // ✅ Gunakan maybeSingle agar tidak crash jika profile belum ada

      if (mounted) {
        setState(() {
          _rewards = rewards;
          _myVouchers = vouchers;
          _currentPoints = profile != null
              ? _safeParseInt(profile['points'])
              : 0;
          _currentTier = profile?['membership_tier'] ?? 'SILVER';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading rewards: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRedeem(Reward reward) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Tukar Poin?',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anda akan menukar ${reward.pointsRequired} poin untuk mendapatkan:',
            ),
            const SizedBox(height: 8),
            Text(
              '"${reward.title}"',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sisa poin Anda setelah ini: ${_currentPoints - reward.pointsRequired}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Ya, Tukarkan',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGold),
        ),
      );

      final success = await RewardService.redeemReward(reward);
      if (mounted) Navigator.pop(context); // Tutup loading

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Berhasil menukar poin! Cek voucher Anda.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData(); // Refresh data
          _tabController.animateTo(
            1,
          ); // ✅ Otomatis pindah ke tab History/Voucher
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Gagal menukar poin. Poin tidak mencukupi atau reward habis.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
          'My Rewards',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        // ✅ TabBar DIHAPUS dari AppBar, dipindah ke body
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGold),
            )
          : Column(
              children: [
                // ✅ 1. HEADER POIN & TIER (Di bagian paling atas)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16), // ✅ Padding dikurangi
                  decoration: const BoxDecoration(
                    color: AppColors.darkCharcoal,
                    // ✅ HAPUS borderRadius agar tidak ada lekukan
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Points',
                            style: TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Lato',
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            NumberFormat('#,###').format(_currentPoints),
                            style: const TextStyle(
                              color: AppColors.primaryGold,
                              fontFamily: 'Playfair Display',
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.primaryGold, width: 1.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _tierIcon,
                              color: AppColors.primaryGold,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _currentTier,
                              style: const TextStyle(
                                color: AppColors.primaryGold,
                                fontFamily: 'Lato',
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ 2. TAB BAR (Di bawah header poin)
                Container(
                  color: AppColors.darkCharcoal,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primaryGold,
                    indicatorWeight: 2,
                    labelColor: AppColors.primaryGold,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(
                      fontFamily: 'Lato',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontFamily: 'Lato',
                      fontWeight: FontWeight.normal,
                      fontSize: 12,
                    ),
                    tabs: const [
                      Tab(text: 'Rewards Catalog'),
                      Tab(text: 'My History'),
                    ],
                  ),
                ),

                // ✅ 3. TAB BAR VIEW (Konten di bawah tab)
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: Rewards Catalog
                      RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (_rewards.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text(
                                    'No rewards are available yet.',
                                    style: TextStyle(
                                      fontFamily: 'Lato',
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ..._rewards.map(
                                (reward) => _buildRewardCard(reward),
                              ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),

                      // TAB 2: My History (Vouchers)
                      RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (_myVouchers.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.card_giftcard_outlined,
                                        size: 48,
                                        color: AppColors.textGrey,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'You haven\'t redeemed any rewards yet.',
                                        style: TextStyle(
                                          fontFamily: 'Lato',
                                          color: AppColors.textGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ..._myVouchers.map(
                                (voucher) => _buildVoucherCard(voucher),
                              ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRewardCard(Reward reward) {
    final bool canAfford = _currentPoints >= reward.pointsRequired;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  color: AppColors.primaryGold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  reward.title,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkCharcoal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reward.description,
            style: const TextStyle(
              fontFamily: 'Lato',
              fontSize: 13,
              color: AppColors.textGrey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.star,
                    color: AppColors.primaryGold,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${reward.pointsRequired} Poin',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: canAfford ? AppColors.darkCharcoal : Colors.grey,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: canAfford ? () => _handleRedeem(reward) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAfford
                        ? AppColors.primaryGold
                        : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: Text(
                    canAfford ? 'REDEEM NOW' : 'NOT ENOUGH',
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherCard(Redemption voucher) {
    final bool isUsed = voucher.status == 'used';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isUsed ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUsed
              ? Colors.grey.shade300
              : AppColors.primaryGold.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Bagian Atas: Judul & Status
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voucher.rewardTitle,
                        style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isUsed ? Colors.grey : AppColors.darkCharcoal,
                          decoration: isUsed
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Redeemed on ${_formatDate(voucher.createdAt)}',
                        style: const TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isUsed ? Colors.grey.shade200 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isUsed
                          ? Colors.grey.shade400
                          : Colors.green.shade200,
                    ),
                  ),
                  child: Text(
                    isUsed ? 'USED' : 'ACTIVE',
                    style: TextStyle(
                      color: isUsed
                          ? Colors.grey.shade700
                          : Colors.green.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ✅ Garis Putus-putus (Dashed Line) ala Tiket
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Colors.grey,
          ),

          // Bagian Bawah: Kode Voucher
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VOUCHER CODE',
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 10,
                        color: AppColors.textGrey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      voucher.voucherCode,
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isUsed ? Colors.grey : AppColors.primaryGold,
                        letterSpacing: 2,
                        decoration: isUsed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ],
                ),
                if (!isUsed)
                  ElevatedButton.icon(
                    onPressed: () {
                      // Fitur copy ke clipboard bisa ditambahkan di sini
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Code ${voucher.voucherCode} copied!'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text(
                      'COPY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkCharcoal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
