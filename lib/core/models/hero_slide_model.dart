class HeroSlide {
  final String id;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String? linkUrl;
  final int sortOrder;
  final bool isActive;

  HeroSlide({
    required this.id,
    required this.title,
    this.subtitle,
    required this.imageUrl,
    this.linkUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  /// Factory method: Convert database row to HeroSlide object
  factory HeroSlide.fromMap(Map<String, dynamic> map) {
    return HeroSlide(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String?,
      imageUrl: map['image_url'] as String? ?? '',
      linkUrl: map['link_url'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}