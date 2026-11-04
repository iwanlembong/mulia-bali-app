import 'package:supabase_flutter/supabase_flutter.dart';

class RestaurantService {
  /// Ambil semua restoran yang aktif
  static Future<List<Map<String, dynamic>>> getActiveRestaurants() async {
    try {
      final response = await Supabase.instance.client
          .from('restaurants')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching restaurants: $e');
      return [];
    }
  }

  /// ✅ BARU: Ambil detail 1 restoran berdasarkan ID
  static Future<Map<String, dynamic>?> getRestaurantById(String id) async {
    try {
      final response = await Supabase.instance.client
          .from('restaurants')
          .select()
          .eq('id', id)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching restaurant by ID: $e');
      return null;
    }
  }

  /// ✅ BARU: Ambil menu items untuk restoran tertentu
  static Future<List<Map<String, dynamic>>> getMenuItemsByRestaurantId(String restaurantId) async {
    try {
      final response = await Supabase.instance.client
          .from('menu_items')
          .select()
          .eq('restaurant_id', restaurantId)
          .eq('is_available', true)
          .order('sort_order', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching menu items: $e');
      return [];
    }
  }
}