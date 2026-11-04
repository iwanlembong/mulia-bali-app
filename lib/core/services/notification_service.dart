import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import 'auth_service.dart';

class NotificationService {
  // 1. Ambil jumlah notifikasi yang BELUM DIBACA (untuk badge merah)
  static Future<int> getUnreadCount() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return 0;

    // ✅ PERBAIKAN: Cukup ambil kolom 'id', lalu hitung panjang list-nya
    final response = await Supabase.instance.client
        .from('notifications')
        .select('id') 
        .eq('user_id', userId)
        .eq('is_read', false);

    return (response as List).length;
  }

  // 2. Ambil semua notifikasi user (terbaru di atas)
  static Future<List<NotificationItem>> getUserNotifications() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return [];

    print('🔍 [DEBUG] Mengambil notifikasi untuk user: $userId');

    try {
      final response = await Supabase.instance.client
          .from('notifications')
          .select('*') // ✅ Eksplisit meminta semua kolom
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // ✅ INI KUNCINYA: Lihat data mentah di Terminal VS Code
      print(' [DEBUG] Raw Data dari Supabase: $response');
      print('📏 [DEBUG] Jumlah data ditemukan: ${(response as List).length}');

      final List<NotificationItem> notifications = (response as List).map((e) {
        print('🔄 [DEBUG] Memproses map: $e'); // Lihat proses mapping per item
        return NotificationItem.fromMap(e as Map<String, dynamic>);
      }).toList();

      print('✅ [DEBUG] Berhasil memproses ${notifications.length} notifikasi ke Model');
      return notifications;

    } catch (e) {
      print('❌ [DEBUG] ERROR saat mengambil notifikasi: $e');
      return [];
    }
  }

  // 3. Tandai satu notifikasi sebagai sudah dibaca
  static Future<void> markAsRead(String notificationId) async {
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  // 4. Tandai SEMUA notifikasi sebagai sudah dibaca
  static Future<void> markAllAsRead() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return;

    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  // 5. Helper: Buat notifikasi baru (Akan kita panggil saat Redeem/Checkout)
  static Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'general',
  }) async {
    await Supabase.instance.client.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
    });
  }
}