class SpaServiceModel {
  final String id;
  final String name;
  final String? category;
  final String? description;
  final int? durationMinutes;
  final int price;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;

  SpaServiceModel({
    required this.id,
    required this.name,
    this.category,
    this.description,
    this.durationMinutes,
    this.price = 0,
    this.imageUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory SpaServiceModel.fromMap(Map<String, dynamic> map) {
    return SpaServiceModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      category: map['category'] as String?,
      description: map['description'] as String?,
      durationMinutes: map['duration_minutes'] as int?,
      price: map['price'] as int? ?? 0,
      imageUrl: map['image_url'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}