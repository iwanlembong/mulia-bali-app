import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/reward_model.dart';
import '../../core/services/reward_service.dart';

class AdminRewardsScreen extends StatefulWidget {
  const AdminRewardsScreen({super.key});

  @override
  State<AdminRewardsScreen> createState() => _AdminRewardsScreenState();
}

class _AdminRewardsScreenState extends State<AdminRewardsScreen> {
  bool _isLoading = true;
  List<Reward> _rewards = [];

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    setState(() => _isLoading = true);
    final rewards = await RewardService.getAllRewardsForAdmin();
    if (mounted) {
      setState(() {
        _rewards = rewards;
        _isLoading = false;
      });
    }
  }

  // ✅ PERBAIKAN: Update UI secara instan (Optimistic UI)
  Future<void> _toggleStatus(Reward reward) async {
    final newStatus = !reward.isActive;
    
    // 1. Update tampilan LANGSUNG (sebelum database merespons)
    setState(() {
      final index = _rewards.indexWhere((r) => r.id == reward.id);
      if (index != -1) {
        _rewards[index] = Reward(
          id: reward.id, title: reward.title, description: reward.description,
          pointsRequired: reward.pointsRequired, rewardType: reward.rewardType,
          rewardValue: reward.rewardValue, applicableTo: reward.applicableTo,
          isActive: newStatus,
        );
      }
    });

    // 2. Sync ke database di background
    final success = await RewardService.toggleRewardStatus(reward.id, newStatus);
    
    if (mounted) {
      if (!success) {
        // Jika gagal, kembalikan ke status semula
        _loadRewards(); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to change status'), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newStatus ? 'Reward activated' : 'Rewards disabled'), backgroundColor: Colors.green),
        );
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
        title: const Text('Manage Rewards', style: TextStyle(fontFamily: 'Playfair Display', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add New Reward',
            onPressed: () {
              context.push('/admin/add-reward').then((_) => _loadRewards());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : _rewards.isEmpty
              ? const Center(child: Text('Belum ada reward.', style: TextStyle(fontFamily: 'Lato', color: AppColors.textGrey)))
              : RefreshIndicator(
                  onRefresh: _loadRewards,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rewards.length,
                    itemBuilder: (context, index) {
                      final reward = _rewards[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      reward.title,
                                      style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal),
                                    ),
                                  ),
                                  // ✅ BARU: Tombol Edit
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    color: Colors.blue.shade700,
                                    tooltip: 'Edit Reward',
                                    onPressed: () {
                                      // Kirim data reward ke halaman edit
                                      context.push('/admin/add-reward', extra: reward).then((_) => _loadRewards());
                                    },
                                  ),
                                  Switch(
                                    value: reward.isActive,
                                    onChanged: (val) => _toggleStatus(reward),
                                    activeColor: AppColors.primaryGold,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(reward.description, style: const TextStyle(fontFamily: 'Lato', fontSize: 12, color: AppColors.textGrey)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildChip('${reward.pointsRequired} Poin', Colors.blue),
                                  const SizedBox(width: 8),
                                  _buildChip(reward.applicableTo.toUpperCase(), Colors.purple),
                                  const Spacer(),
                                  Text(
                                    reward.isActive ? 'Aktif' : 'Non-Aktif',
                                    style: TextStyle(
                                      fontFamily: 'Lato',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: reward.isActive ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontFamily: 'Lato', fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}