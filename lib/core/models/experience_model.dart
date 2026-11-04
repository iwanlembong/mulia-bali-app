class ExperienceModel {
  final String id;
  final String title;
  final String description;
  final String iconName; // Nama icon dalam string, misal: 'spa', 'restaurant'
  final String imageUrl;
  final int sortOrder;
  final bool isActive;

  ExperienceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.imageUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory ExperienceModel.fromMap(Map<String, dynamic> map) {
    return ExperienceModel(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      iconName: map['icon_name'] as String? ?? 'star',
      imageUrl: map['image_url'] as String? ?? '',
      sortOrder: map['sort_order'] as int? ?? 0,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}