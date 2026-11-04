import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class FavoriteService {
  // ✅ Cek apakah item sudah di-favorite oleh user saat ini
  static Future<bool> isFavorite(String itemType, String itemId) async {
    final userId = AuthService.currentUserId;
    if (userId == null) return false;

    try {
      final response = await Supabase.instance.client
          .from('favorites')
          .select('id')
          .eq('user_id', userId)
          .eq('item_type', itemType)
          .eq('item_id', itemId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('❌ [FAVORITE] Error checking favorite status: $e');
      return false;
    }
  }

  // ✅ DIPERBAIKI: Toggle Favorite dengan Error Handling yang Lebih Baik
  static Future<bool> toggleFavorite(String itemType, String itemId) async {
    final userId = AuthService.currentUserId;
    if (userId == null) {
      print('❌ [FAVORITE] User ID is null');
      return false;
    }

    try {
      final isFav = await isFavorite(itemType, itemId);
      print('🔍 [FAVORITE] Status: $isFav | User: $userId | Type: $itemType | Item: $itemId');

      if (isFav) {
        // HAPUS dari favorite
        print('🗑️ [FAVORITE] Menghapus favorite...');
        
        // ✅ PERBAIKAN: Gunakan .then() untuk memastikan operasi selesai
        await Supabase.instance.client
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('item_type', itemType)
            .eq('item_id', itemId);
        
        print('✅ [FAVORITE] Berhasil menghapus dari database');
        return false; // Return false karena sekarang statusnya TIDAK favorite
        
      } else {
        // TAMBAH ke favorite
        print('➕ [FAVORITE] Menambahkan favorite...');
        
        await Supabase.instance.client.from('favorites').insert({
          'user_id': userId,
          'item_type': itemType,
          'item_id': itemId,
        });
        
        print('✅ [FAVORITE] Berhasil menambahkan ke database');
        return true; // Return true karena sekarang statusnya FAVORITE
      }
      
    } catch (e) {
      print('❌ [FAVORITE] ERROR: $e');
      rethrow; // ✅ LEMPAR ULANG error agar bisa ditangkap di UI
    }
  }

  // ✅ Ambil semua favorite user
  static Future<List<Map<String, dynamic>>> getUserFavorites({String? itemType}) async {
    final userId = AuthService.currentUserId;
    if (userId == null) return [];

    try {
      var query = Supabase.instance.client
          .from('favorites')
          .select('item_type, item_id')
          .eq('user_id', userId);

      if (itemType != null) {
        query = query.eq('item_type', itemType);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ [FAVORITE] Error fetching favorites: $e');
      return [];
    }
  }
}