class Reward {
  final String id;
  final String title;
  final String description;
  final int pointsRequired;
  final String rewardType;
  final String rewardValue;
  final String applicableTo; // ✅ BARU: Menentukan target (services/accommodation/all)
  final bool isActive;       // ✅ BARU: Status aktif/non-aktif untuk Admin


  Reward({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsRequired,
    required this.rewardType,
    required this.rewardValue,
    required this.applicableTo,
    required this.isActive,
  });

  factory Reward.fromMap(Map<String, dynamic> map) {
    return Reward(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      pointsRequired: (map['points_required'] as num).toInt(),
      rewardType: map['reward_type'] as String,
      rewardValue: map['reward_value'] as String,
      applicableTo: map['applicable_to'] as String? ?? 'all', // ✅ Fallback ke 'all'
      isActive: map['is_active'] as bool? ?? true,           // ✅ Fallback ke true
    );
  }

  // ✅ BARU: Method ini WAJIB ada agar Admin bisa menyimpan (insert) data ke database
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'points_required': pointsRequired,
      'reward_type': rewardType,
      'reward_value': rewardValue,
      'applicable_to': applicableTo,
      'is_active': isActive,
    };
  }
}

class Redemption {
  final String id;
  final String rewardId;
  final String rewardTitle; // Kita ambil dari join atau simpan sederhana
  final String rewardType; // 'discount_percentage', 'discount_fixed'
  final String rewardValue; // '10', '50000'
  final String applicableTo; // 'services', 'accommodation', 'all'
  final int pointsDeducted;
  final String voucherCode;
  final String status;
  final DateTime createdAt;

  Redemption({
    required this.id,
    required this.rewardId,
    required this.rewardTitle,
    required this.rewardType,
    required this.rewardValue,
    required this.applicableTo,
    required this.pointsDeducted,
    required this.voucherCode,
    required this.status,
    required this.createdAt,
  });

  factory Redemption.fromMap(Map<String, dynamic> map) {
    final rewards = map['rewards'] as Map<String, dynamic>? ?? {};
    return Redemption(
      id: map['id'] as String,
      rewardId: map['reward_id'] as String,
      rewardTitle: rewards['title'] ?? 'Reward',
      rewardType: rewards['reward_type'] ?? 'discount_fixed',
      rewardValue: rewards['reward_value'] ?? '0',
      applicableTo: rewards['applicable_to'] ?? 'all',
      pointsDeducted: (map['points_deducted'] as num).toInt(),
      voucherCode: map['voucher_code'] as String? ?? '-',
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}