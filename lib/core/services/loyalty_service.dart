import 'package:supabase_flutter/supabase_flutter.dart';

class LoyaltyService {
  // ✅ 1. Rumus Perhitungan Poin
  static int calculatePoints(int amount) {
    // Setiap 100.000 dapat 1 poin. Dibulatkan ke bawah.
    return (amount / 100000).floor();
  }

  // ✅ 2. Method untuk Memberikan Poin setelah Booking Berhasil
  static Future<void> awardPoints({
    required String userId,
    required int amount,
    required String sourceType, // 'accommodation' atau 'service'
    required String sourceId, // ID reservasi atau booking
    required int quantity, // Jumlah malam (untuk accommodation) atau jumlah item (untuk service)
  }) async {
    final points = calculatePoints(amount);

    // Jika poin 0 (karena nominal kecil), kita skip insert transaksi tapi tetap update counter
    if (points > 0) {
      // A. Catat di History (point_transactions)
      await Supabase.instance.client.from('point_transactions').insert({
        'user_id': userId,
        'transaction_type': 'earn',
        'source_type': sourceType,
        'source_id': sourceId,
        'points': points,
        'description': 'Earned from $sourceType booking',
      });

      // B. Update Total Poin di Profiles
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('points')
          .eq('id', userId)
          .single();



      final currentPoints = (profile['points'] as num?)?.toInt() ?? 0;
      await Supabase.instance.client
          .from('profiles')
          .update({'points': currentPoints + points})
          .eq('id', userId);
    }

    print(
      '✅ [Loyalty] Berhasil memberikan $points poin dan update counter untuk user $userId',
    );
  }
}
