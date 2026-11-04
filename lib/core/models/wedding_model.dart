class WeddingModel {
  final String id;
  final String packageName;
  final String? description;
  final int? price;
  final List<String> includes;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;

  WeddingModel({
    required this.id,
    required this.packageName,
    this.description,
    this.price,
    this.includes = const [],
    this.imageUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory WeddingModel.fromMap(Map<String, dynamic> map) {
    // Parse includes dari JSONB array
    final includesRaw = map['includes'];
    List<String> includesList = [];
    
    if (includesRaw is List) {
      includesList = includesRaw.map((e) => e.toString()).toList();
    }

    return WeddingModel(
      id: map['id'] as String,
      packageName: map['package_name'] as String? ?? '',
      description: map['description'] as String?,
      price: map['price'] as int?,
      includes: includesList,
      imageUrl: map['image_url'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}