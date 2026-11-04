// ============================================
// BAGIAN 1: DATA HARDCODED LAMA (Untuk Fallback)
// ============================================

class RoomType {
  final String name;
  final String size;
  final String description;
  final String imageUrl;

  RoomType({
    required this.name,
    required this.size,
    required this.description,
    required this.imageUrl,
  });
}

class PropertyModel {
  final String id;
  final String name;
  final String tagline;
  final String description;
  final String heroImageUrl;
  final List<String> highlights;
  final List<RoomType> roomTypes;

  PropertyModel({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.heroImageUrl,
    required this.highlights,
    required this.roomTypes,
  });
}

// Data Real berdasarkan website The Mulia Bali
final List<PropertyModel> baliProperties = [
  PropertyModel(
    id: 'the-mulia',
    name: 'The Mulia',
    tagline: 'All-Suite Beachfront Resort',
    description: 'Escape to The Mulia, a luxurious all-suite haven on the serene shores of Geger Beach. Revel in panoramic ocean views, an iconic infinity pool, exquisite Balinese carvings, attentive butler service, and priority dining.',
    heroImageUrl: 'https://images.unsplash.com/photo-1571003123894-1f0594d2b5d9?auto=format&fit=crop&w=1200&q=80',
    highlights: ['Panoramic Ocean Views', 'Iconic Infinity Pool', '24/7 Bespoke Butler Service', 'Priority Dining Reservations'],
    roomTypes: [
      RoomType(name: 'The Marquess Ruby', size: '337 sqm', description: 'Two-bedroom suite on an upper floor with separate dining area and panoramic 180° ocean views.', imageUrl: 'https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=400&q=80'),
      RoomType(name: 'The Marquess Lagoon', size: '337 sqm', description: 'Beachfront view with direct lagoon pool access and separate dining area.', imageUrl: 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=400&q=80'),
      RoomType(name: 'The Earl', size: '130 sqm', description: 'Separate living room and dining area with ocean or garden views.', imageUrl: 'https://images.unsplash.com/photo-1566665797739-1674de7a421a?auto=format&fit=crop&w=400&q=80'),
    ],
  ),
  PropertyModel(
    id: 'mulia-resort',
    name: 'Mulia Resort',
    tagline: 'A Vibrant Playground',
    description: 'Nestled on Nusa Dua\'s white sands, Mulia Resort is Bali’s vibrant playground. Enjoy luxurious accommodations, exquisite dining, rejuvenating spa treatments, and engaging activities.',
    heroImageUrl: 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=800&q=80',
    highlights: ['1 km Secluded Beach', 'Asia Pacific’s First Ice Room', '9 World-Class Restaurants', 'Dedicated Kids’ Facilities'],
    roomTypes: [
      RoomType(name: 'Premier Amber', size: '199 sqm', description: 'Ocean view suite with separate living room and exclusive access to The Mulia & Villas.', imageUrl: 'https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=400&q=80'),
      RoomType(name: 'Mulia Signature', size: '59 sqm', description: 'Garden or courtyard view, with option for direct lagoon pool access.', imageUrl: 'https://images.unsplash.com/photo-1566665797739-1674de7a421a?auto=format&fit=crop&w=400&q=80'),
      RoomType(name: 'Premier Emerald', size: '199 sqm', description: 'Two-bedroom ocean view suite with exclusive butler service access.', imageUrl: 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=400&q=80'),
    ],
  ),
  PropertyModel(
    id: 'mulia-villas',
    name: 'Mulia Villas',
    tagline: 'Exclusive All-Pool Villas',
    description: 'Cradled in the serene embrace of lush tropical gardens, Mulia Villas promises unparalleled privacy. Each villa features a private pool, secluded garden sanctuary, and bespoke butler service.',
    heroImageUrl: 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=800&q=80',
    highlights: ['Private Pool in Every Villa', 'Secluded Garden Sanctuary', 'The Lounge Exclusive Access', 'Ultimate Privacy & Slow Living'],
    roomTypes: [
      RoomType(name: 'One-Bedroom Villa', size: '505 sqm', description: 'Ocean or garden view with Balinese-style outdoor living and dining area.', imageUrl: 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=400&q=80'),
      RoomType(name: 'Family Villa', size: '513 sqm', description: 'Spacious villa with King & Queen bed, perfect for families with children.', imageUrl: 'https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=400&q=80'),
      RoomType(name: 'Presidential Villa', size: 'Ultra-Luxury', description: '3-suite ultra-luxury villa with panoramic sunrise views, private pool, and 24/7 dedicated butler & security.', imageUrl: 'https://images.unsplash.com/photo-1566665797739-1674de7a421a?auto=format&fit=crop&w=400&q=80'),
    ],
  ),
];

// ============================================
// BAGIAN 2: MODEL DATABASE BARU (Untuk Integrasi Supabase)
// ============================================

/// Model Property dari Database
class DbProperty {
  final String id;
  final String name;
  final String? tagline;
  final String? description;
  final String? coverImage;
  final String? location;
  final int starRating;
  final List<String> highlights; // ✅ TAMBAHKAN
  final bool isActive;

  DbProperty({
    required this.id,
    required this.name,
    this.tagline,
    this.description,
    this.coverImage,
    this.location,
    this.starRating = 5,
    this.highlights = const [], // ✅ TAMBAHKAN
    this.isActive = true,
  });

  factory DbProperty.fromMap(Map<String, dynamic> map) {
    // ✅ Parse highlights dari JSONB array
    final highlightsRaw = map['highlights'];
    List<String> highlightsList = [];
    
    if (highlightsRaw is List) {
      highlightsList = highlightsRaw.map((e) => e.toString()).toList();
    }

    return DbProperty(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      tagline: map['tagline'] as String?,
      description: map['description'] as String?,
      coverImage: map['cover_image'] as String?,
      location: map['location'] as String?,
      starRating: map['star_rating'] as int? ?? 5,
      highlights: highlightsList, // ✅ TAMBAHKAN
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

/// Model Room dari Database
class DbRoom {
  final String id;
  final String propertyId;
  final String name;
  final int pricePerNight;
  final String? bedType;
  final double? sizeSqm;
  final String? imageUrl;
  final bool isAvailable;

  DbRoom({
    required this.id,
    required this.propertyId,
    required this.name,
    this.pricePerNight = 0,
    this.bedType,
    this.sizeSqm,
    this.imageUrl,
    this.isAvailable = true,
  });

  factory DbRoom.fromMap(Map<String, dynamic> map) {
    return DbRoom(
      id: map['id'] as String,
      propertyId: map['property_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      pricePerNight: map['price_per_night'] as int? ?? 0,
      bedType: map['bed_type'] as String?,
      sizeSqm: (map['size_sqm'] as num?)?.toDouble(),
      imageUrl: map['image_url'] as String?,
      isAvailable: map['is_available'] as bool? ?? true,
    );
  }
}