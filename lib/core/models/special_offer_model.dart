class SpecialOfferModel {
  final String id;
  final String title;
  final String? description;
  final int? discountPercentage;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String imageUrl;
  final int sortOrder;
  final bool isActive;

  // ✅ BARU: Field untuk menghubungkan ke entitas
  final String? propertyId;
  final String? roomId;
  final String? serviceType; // 'spa', 'dining', 'wedding', 'accommodation', 'general'
  final String? promoCode;

  SpecialOfferModel({
    required this.id,
    required this.title,
    this.description,
    this.discountPercentage,
    this.validFrom,
    this.validUntil,
    required this.imageUrl,
    this.sortOrder = 0,
    this.isActive = true,
    this.propertyId,
    this.roomId,
    this.serviceType,
    this.promoCode,
  });

  factory SpecialOfferModel.fromMap(Map<String, dynamic> map) {
    return SpecialOfferModel(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      discountPercentage: map['discount_percentage'] as int?,
      validFrom: map['valid_from'] != null
          ? DateTime.parse(map['valid_from'])
          : null,
      validUntil: map['valid_until'] != null
          ? DateTime.parse(map['valid_until'])
          : null,
      imageUrl: map['image_url'] as String? ?? '',
      sortOrder: map['sort_order'] as int? ?? 0,
      isActive: map['is_active'] as bool? ?? true,
      // ✅ BARU: Parse field baru
      propertyId: map['property_id'] as String?,
      roomId: map['room_id'] as String?,
      serviceType: map['service_type'] as String?,
      promoCode: map['promo_code'] as String?,
    );
  }

  /// Cek apakah offer masih berlaku hari ini
  bool get isValidNow {
    if (validFrom == null || validUntil == null) return true;
    final now = DateTime.now();
    return now.isAfter(validFrom!.subtract(const Duration(days: 1))) &&
        now.isBefore(validUntil!.add(const Duration(days: 1)));
  }
}
