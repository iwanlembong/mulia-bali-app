import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/property_model.dart'; // Mengimport DbProperty & DbRoom

class PropertyService {
  /// Ambil semua properties yang aktif dari database
  static Future<List<DbProperty>> getActiveProperties() async {
    try {
      final response = await Supabase.instance.client
          .from('properties')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return (response as List)
          .map((item) => DbProperty.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching properties: $e');
      return [];
    }
  }

  /// Ambil detail 1 property berdasarkan ID
  static Future<DbProperty?> getPropertyById(String id) async {
    try {
      final properties = await getActiveProperties();
      return properties.firstWhere(
        (p) => p.id == id,
        orElse: () => throw Exception('Property not found'),
      );
    } catch (e) {
      print('Error fetching property by ID: $e');
      return null;
    }
  }

  /// Ambil rooms untuk property tertentu
  static Future<List<DbRoom>> getRoomsByPropertyId(String propertyId) async {
    try {
      final response = await Supabase.instance.client
          .from('rooms')
          .select()
          .eq('property_id', propertyId)
          .eq('is_available', true)
          .order('sort_order', ascending: true);

      return (response as List)
          .map((item) => DbRoom.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching rooms: $e');
      return [];
    }
  }

  /// Gabungkan Property + Rooms untuk Carousel di Home Screen
  static Future<List<Map<String, dynamic>>> getAllRoomsForCarousel() async {
    try {
      final properties = await getActiveProperties();
      final List<Map<String, dynamic>> allRooms = [];
      
      for (final property in properties) {
        final rooms = await getRoomsByPropertyId(property.id);
        for (final room in rooms) {
          allRooms.add({
            'id': property.id,
            'property': property.name,
            'room': room.name,
            'price': room.pricePerNight,
            'bed_type': room.bedType,       // ✅ SEKARANG AMAN (Sudah ada di DbRoom)
            'size_sqm': room.sizeSqm,       // ✅ SEKARANG AMAN (Sudah ada di DbRoom)
            'image': room.imageUrl ?? property.coverImage ?? 'https://images.unsplash.com/photo-1571003123894-1f0594d2b5d9?auto=format&fit=crop&w=600&q=80',
          });
        }
      }
      return allRooms;
    } catch (e) {
      print('Error fetching carousel data: $e');
      return [];
    }
  }
}