import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/reward_model.dart';
import '../../core/services/reward_service.dart';
import '../../core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyRewardsScreen extends StatefulWidget {
  const MyRewardsScreen({super.key});

  @override
  State<MyRewardsScreen> createState() => _MyRewardsScreenState();
}

class _MyRewardsScreenState extends State<MyRewardsScreen> {
  bool _isLoading = true;
  List<Reward> _rewards = [];
  List<Redemption> _myVouchers = [];
  int _currentPoints = 0;
  String _currentTier = 'SILVER';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final userId = AuthService.currentUserId;

    // ✅ TAMBAHKAN BLOK INI: Cegah error jika user belum login
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return; // Hentikan eksekusi di sini
    }

    try {
      // Fetch Data Paralel
      final rewards = await RewardService.getActiveRewards();
      final vouchers = await RewardService.getUserRedemptions();
      
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('points, membership_tier')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _rewards = rewards;
          _myVouchers = vouchers;
          _currentPoints = (profile['points'] as num).toInt();
          _currentTier = profile['membership_tier'] ?? 'SILVER';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading rewards: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRedeem(Reward reward) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tukar Poin?', style: TextStyle(fontFamily: 'Playfair Display')),
        content: Text('Tukar ${reward.pointsRequired} poin untuk mendapatkan "${reward.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold),
            child: const Text('Ya, Tukarkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

      // ✅ PASTIKAN reward yang dikirim adalah reward yang diklik
      print('🔍 [DEBUG UI] Meredeem reward: ${reward.title} dengan ID: ${reward.id}');
      
      final success = await RewardService.redeemReward(reward);
      Navigator.pop(context);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Berhasil menukar poin! Cek voucher Anda.'), backgroundColor: Colors.green),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menukar poin.'), backgroundColor: Colors.red),
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
        title: const Text('My Rewards', style: TextStyle(fontFamily: 'Playfair Display', fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header Poin & Tier
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.darkCharcoal,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Your Points', style: TextStyle(color: Colors.white70, fontFamily: 'Lato', fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              NumberFormat('#,###').format(_currentPoints),
                              style: const TextStyle(color: AppColors.primaryGold, fontFamily: 'Playfair Display', fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primaryGold),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _currentTier,
                            style: const TextStyle(color: AppColors.primaryGold, fontFamily: 'Lato', fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text('Available Rewards', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                  const SizedBox(height: 16),

                  // List Rewards
                  if (_rewards.isEmpty)
                    const Center(child: Text('No rewards are available yet.', style: TextStyle(fontFamily: 'Lato', color: AppColors.textGrey)))
                  else
                    ..._rewards.map((reward) => _buildRewardCard(reward)),

                  if (_myVouchers.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Text('My Vouchers', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                    const SizedBox(height: 16),
                    ..._myVouchers.map((voucher) => _buildVoucherCard(voucher)),
                  ],
                ],
              ),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primaryGold.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.card_giftcard, color: AppColors.primaryGold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(reward.title, style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(reward.description, style: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.textGrey)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${reward.pointsRequired} Poin',
                style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: canAfford ? AppColors.primaryGold : Colors.grey),
              ),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: canAfford ? () => _handleRedeem(reward) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAfford ? AppColors.primaryGold : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(canAfford ? 'REDEEM' : 'INSUFFICIENT POINTS', style: const TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherCard(Redemption voucher) {
    // ✅ Cek status secara dinamis
    final bool isUsed = voucher.status == 'used';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ✅ Background agak abu-abu jika sudah terpakai
        color: isUsed ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          // ✅ Border abu-abu jika terpakai, emas jika aktif
          color: isUsed ? Colors.grey.shade300 : AppColors.primaryGold.withOpacity(0.3), 
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Voucher Code', 
                style: TextStyle(fontFamily: 'Lato', fontSize: 10, color: AppColors.textGrey, letterSpacing: 1)
              ),
              const SizedBox(height: 4),
              Text(
                voucher.voucherCode, 
                style: TextStyle(
                  fontFamily: 'Lato', 
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  // ✅ Teks dicoret dan warnanya abu-abu jika sudah terpakai
                  color: isUsed ? Colors.grey : AppColors.darkCharcoal, 
                  letterSpacing: 2,
                  decoration: isUsed ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
              // ✅ Tambahkan teks kecil "Sudah digunakan" jika statusnya used
              if (isUsed) ...[
                const SizedBox(height: 4),
                const Text(
                  'Already in use',
                  style: TextStyle(fontFamily: 'Lato', fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          
          // ✅ Badge Status Dinamis
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isUsed ? Colors.grey.withOpacity(0.2) : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isUsed ? Colors.grey.withOpacity(0.4) : Colors.green.withOpacity(0.4), 
                width: 0.5
              ),
            ),
            child: Text(
              isUsed ? 'USED' : 'ACTIVE',
              style: TextStyle(
                color: isUsed ? Colors.grey.shade600 : Colors.green, 
                fontSize: 10, 
                fontWeight: FontWeight.bold
              ),
            ),
          ),
        ],
      ),
    );
  }
}