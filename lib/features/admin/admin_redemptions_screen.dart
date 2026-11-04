import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/reward_service.dart';

class AdminRedemptionsScreen extends StatefulWidget {
  const AdminRedemptionsScreen({super.key});

  @override
  State<AdminRedemptionsScreen> createState() => _AdminRedemptionsScreenState();
}

class _AdminRedemptionsScreenState extends State<AdminRedemptionsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _redemptions = [];
  String _currentFilter = 'all'; // 'all', 'active', 'used'

  @override
  void initState() {
    super.initState();
    _loadRedemptions();
  }

  Future<void> _loadRedemptions() async {
    setState(() => _isLoading = true);

    final filter = _currentFilter == 'all' ? null : _currentFilter;
    final data = await RewardService.getAllRedemptions(statusFilter: filter);

    if (mounted) {
      setState(() {
        _redemptions = data;
        _isLoading = false;
      });
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
          'Voucher Redemption History',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // ✅ Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Active', 'active'),
                const SizedBox(width: 8),
                _buildFilterChip('Used', 'used'),
              ],
            ),
          ),
          const Divider(height: 1),

          // ✅ List Riwayat
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGold,
                    ),
                  )
                : _redemptions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: AppColors.textGrey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No voucher redemption history yet',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 14,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadRedemptions,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _redemptions.length,
                      itemBuilder: (context, index) {
                        final item = _redemptions[index];
                        return _buildRedemptionCard(item);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ✅ Widget Filter Chip
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _currentFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: const TextStyle(fontFamily: 'Lato', fontSize: 12),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _currentFilter = value);
          _loadRedemptions();
        }
      },
      selectedColor: AppColors.primaryGold.withOpacity(0.2),
      checkmarkColor: AppColors.primaryGold,
      backgroundColor: Colors.grey.shade100,
    );
  }

  // ✅ Widget Card Riwayat
  Widget _buildRedemptionCard(Map<String, dynamic> item) {
    final profiles = item['profiles'] as Map<String, dynamic>? ?? {};
    final rewards = item['rewards'] as Map<String, dynamic>? ?? {};

    final userName = profiles['full_name'] ?? 'Unknown User';
    final userEmail = profiles['email'] ?? '-';
    final rewardTitle = rewards['title'] ?? 'Unknown Reward';
    final rewardType = rewards['reward_type'] ?? '-';
    final rewardValue = rewards['reward_value'] ?? '-';
    // final applicableTo = rewards['applicable_to'] ?? '-';

    final voucherCode = item['voucher_code'] ?? '-';
    final pointsDeducted = (item['points_deducted'] as num?)?.toInt() ?? 0;
    final status = item['status'] ?? 'unknown';
    final createdAt = DateTime.parse(item['created_at'] as String);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
          // Header: User Info + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userEmail,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'active'
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status == 'active' ? 'ACTIVE' : 'USED',
                  style: TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: status == 'active' ? Colors.green : Colors.grey,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Detail Reward
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  color: AppColors.primaryGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rewardTitle,
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Value: $rewardValue | Type: $rewardType',
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 11,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Voucher Code & Points
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Voucher Code',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 10,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    voucherCode,
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Points Deducted',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 10,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$pointsDeducted Poin',
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Tanggal
          Row(
            children: [
              const Icon(Icons.access_time, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Exchanged on ${DateFormat('dd MMM yyyy, HH:mm').format(createdAt)}', // ✅ Hapus ', 'id_ID'
                style: const TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
