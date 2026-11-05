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