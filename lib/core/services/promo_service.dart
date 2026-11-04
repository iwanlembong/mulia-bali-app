import 'package:supabase_flutter/supabase_flutter.dart';

class PromoCode {
  final String code;
  final String type; // 'percentage' atau 'fixed'
  final double value;
  final double minPurchase;

  PromoCode({
    required this.code,
    required this.type,
    required this.value,
    required this.minPurchase,
  });

  factory PromoCode.fromMap(Map<String, dynamic> map) {
    return PromoCode(
      code: map['code'],
      type: map['discount_type'],
      value: (map['discount_value'] as num).toDouble(),
      minPurchase: (map['min_purchase'] as num).toDouble(),
    );
  }

  // ✅ Hitung nominal diskon berdasarkan total belanja
  int calculateDiscount(int totalAmount) {
    if (totalAmount < minPurchase) return 0;

    if (type == 'percentage') {
      return (totalAmount * (value / 100)).round();
    } else {
      // Fixed discount, tapi tidak boleh lebih besar dari total belanja
      return value.round() > totalAmount ? totalAmount : value.round();
    }
  }
}

class PromoService {
  /// ✅ Cek validitas kode promo
  static Future<PromoCode?> validatePromoCode(String code, int totalAmount) async {
    try {
      print('🔍 [PROMO] === MEMULAI VALIDASI PROMO ===');
      print('🔍 [PROMO] Kode yang dicari: ${code.toUpperCase()}');
      print('🔍 [PROMO] Total belanja: $totalAmount');

      final response = await Supabase.instance.client
          .from('promotions')
          .select('*')
          .eq('code', code.toUpperCase())
          .eq('is_active', true)
          .maybeSingle();

      print('📡 [PROMO] Respons dari database: $response');
      print('📡 [PROMO] Tipe respons: ${response.runtimeType}');

      if (response == null) {
        print('❌ [PROMO] Tidak ada data yang ditemukan!');
        print('💡 [PROMO] Kemungkinan penyebab:');
        print('💡 [PROMO] 1. Kode "$code" tidak ada di database');
        print('💡 [PROMO] 2. is_active bukan true (tipe data mungkin string "true" bukan boolean true)');
        print('💡 [PROMO] 3. Ada masalah koneksi');
        return null;
      }

      // Coba parse data
      try {
        final promo = PromoCode.fromMap(response);
        print('✅ [PROMO] Berhasil parse PromoCode:');
        print('✅ [PROMO] - Code: ${promo.code}');
        print('✅ [PROMO] - Type: ${promo.type}');
        print('✅ [PROMO] - Value: ${promo.value}');
        print('✅ [PROMO] - Min Purchase: ${promo.minPurchase}');

        // Cek minimum pembelian
        if (totalAmount < promo.minPurchase) {
          print('❌ [PROMO] Total belanja ($totalAmount) belum mencapai minimum (${promo.minPurchase})');
          throw Exception('Min. purchase for this promo is IDR ${promo.minPurchase.round()}');
        }

        print('✅ [PROMO] === VALIDASI BERHASIL ===');
        return promo;
        
      } catch (parseError) {
        print('❌ [PROMO] Error saat parsing PromoCode: $parseError');
        print('❌ [PROMO] Data mentah: $response');
        return null;
      }

    } catch (e) {
      print('❌ [PROMO] Error umum: $e');
      return null;
    }
  }
}