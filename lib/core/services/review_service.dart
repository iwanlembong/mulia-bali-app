import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class ReviewService {
  // ✅ 1. Kirim Review Baru
  static Future<bool> submitReview({
    required String itemType,
    required String itemId,
    required int rating,
    String? comment,
  }) async {
    final userId = AuthService.currentUserId;
    if (userId == null) return false;

    try {
      await Supabase.instance.client.from('reviews').insert({
        'user_id': userId,
        'item_type': itemType,
        'item_id': itemId,
        'rating': rating,
        'comment': comment,
        'is_approved': false, // ✅ PERUBAHAN 1: Set default ke Pending (false)
      });
      return true;
    } catch (e) {
      print('❌ [REVIEW] Error submitting review: $e');
      return false;
    }
  }

  // ✅ 2. Mengambil review DAN nama user dengan aman (HANYA yang Approved)
  static Future<List<Map<String, dynamic>>> getReviews(String itemType, String itemId) async {
    try {
      // ✅ PERUBAHAN 2: Tambahkan filter is_approved = true agar user hanya lihat review yang sudah disetujui Admin
      final response = await Supabase.instance.client
          .from('reviews')
          .select('*')
          .eq('item_type', itemType)
          .eq('item_id', itemId)
          .eq('is_approved', true) // <--- FILTER PUBLIK
          .order('created_at', ascending: false);

      final reviews = (response as List).cast<Map<String, dynamic>>();
      if (reviews.isEmpty) return [];

      // Ambil semua user_id yang unik dari review ini
      final userIds = reviews.map((r) => r['user_id'] as String).toSet().toList();

      // Fetch nama user dari tabel profiles berdasarkan ID tersebut
      final profilesResponse = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', userIds);

      final profiles = (profilesResponse as List).cast<Map<String, dynamic>>();

      // Gabungkan nama user ke dalam data review
      for (var review in reviews) {
        final userProfile = profiles.firstWhere(
          (p) => p['id'] == review['user_id'],
          orElse: () => {'full_name': 'Valued Guest'}, 
        );
        
        review['user_name'] = userProfile['full_name'] ?? 'Valued Guest';
      }

      print('✅ [REVIEW] Berhasil mengambil ${reviews.length} approved reviews.');
      return reviews;

    } catch (e) {
      print('❌ [REVIEW] Error fetching reviews: $e');
      return [];
    }
  }
  

  // ✅ 3. Hitung Rata-rata Rating (HANYA dari review yang Approved)
  static Future<double> getAverageRating(String itemType, String itemId) async {
    try {
      // ✅ PERUBAHAN 3: Tambahkan filter is_approved = true agar rating rata-rata akurat
      final response = await Supabase.instance.client
          .from('reviews')
          .select('rating')
          .eq('item_type', itemType)
          .eq('item_id', itemId)
          .eq('is_approved', true); // <--- FILTER RATING

      final ratings = (response as List).map((r) => r['rating'] as int).toList();
      if (ratings.isEmpty) return 0.0;
      
      final sum = ratings.reduce((a, b) => a + b);
      return sum / ratings.length;
    } catch (e) {
      return 0.0;
    }
  }

    // ✅ RESTORE: Mengambil review berdasarkan LIST item_id (Dengan Fetch Terpisah + Nama Menu)
  static Future<List<Map<String, dynamic>>> getReviewsByItemIds(List<String> itemIds) async {
    if (itemIds.isEmpty) return [];

    try {
      // 1. Ambil reviews dulu (TANPA join profiles)
      final response = await Supabase.instance.client
          .from('reviews')
          .select('*')
          .eq('item_type', 'dining')
          .inFilter('item_id', itemIds)
          .eq('is_approved', true)
          .order('created_at', ascending: false);

      final reviews = (response as List).cast<Map<String, dynamic>>();
      if (reviews.isEmpty) return [];

      // 2. Kumpulkan semua user_id unik untuk fetch profiles
      final userIds = reviews
          .map((r) => r['user_id'] as String)
          .toSet()
          .toList();

      // 3. Fetch profiles secara terpisah
      Map<String, String> userNames = {};
      if (userIds.isNotEmpty) {
        final profilesResponse = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', userIds);

        for (var profile in profilesResponse) {
          userNames[profile['id']] = profile['full_name'] ?? 'Valued Guest';
        }
      }

      // 4. ✅ BARU: Kumpulkan semua item_id unik untuk fetch nama menu
      final reviewItemIds = reviews
          .map((r) => r['item_id'] as String)
          .toSet()
          .toList();

      Map<String, String> menuNames = {};
      if (reviewItemIds.isNotEmpty) {
        final menuResponse = await Supabase.instance.client
            .from('menu_items')
            .select('id, name')
            .inFilter('id', reviewItemIds);

        for (var menu in menuResponse) {
          menuNames[menu['id']] = menu['name'] ?? 'Unknown Menu';
        }
      }

      // 5. Gabungkan nama user DAN nama menu ke setiap review
      for (var review in reviews) {
        final userId = review['user_id'] as String;
        final itemId = review['item_id'] as String;
        
        review['user_name'] = userNames[userId] ?? 'Valued Guest';
        review['menu_name'] = menuNames[itemId] ?? 'Unknown Menu'; // ✅ BARU
      }

      print('✅ [REVIEW SERVICE] Berhasil mengambil ${reviews.length} approved reviews dengan nama menu.');
      return reviews;
    } catch (e) {
      print('❌ [REVIEW SERVICE] Error fetching reviews by item IDs: $e');
      return [];
    }
  }

  // ✅ RESTORE: Hitung rata-rata rating berdasarkan LIST item_id
  static Future<double> getAverageRatingByItemIds(List<String> itemIds) async {
    if (itemIds.isEmpty) return 0.0;

    try {
      final response = await Supabase.instance.client
          .from('reviews')
          .select('rating')
          .eq('item_type', 'dining')
          .inFilter('item_id', itemIds)
          .eq('is_approved', true);

      final ratings = (response as List).map((r) => r['rating'] as int).toList();
      if (ratings.isEmpty) return 0.0;
      
      final sum = ratings.reduce((a, b) => a + b);
      return sum / ratings.length;
    } catch (e) {
      print('❌ [REVIEW SERVICE] Error calculating average rating by item IDs: $e');
      return 0.0;
    }
  }

  // ✅ 4. Ambil semua ID item yang sudah direview oleh user saat ini
  // (TIDAK difilter is_approved, karena jika user sudah submit (meski pending), 
  // mereka tidak boleh submit review kedua untuk item yang sama)
  static Future<Set<String>> getUserReviewedItemIds() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return {};

    try {
      final response = await Supabase.instance.client
          .from('reviews')
          .select('item_id')
          .eq('user_id', userId);

      return (response as List).map((e) => e['item_id'] as String).toSet();
    } catch (e) {
      print('❌ [REVIEW] Error fetching reviewed IDs: $e');
      return {};
    }
  }
}