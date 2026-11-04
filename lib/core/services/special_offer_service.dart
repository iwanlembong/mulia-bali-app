import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/special_offer_model.dart';

class SpecialOfferService {
  /// Ambil semua special offers yang aktif dan masih berlaku
  static Future<List<SpecialOfferModel>> getActiveOffers() async {
    try {
      final response = await Supabase.instance.client
          .from('special_offers')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final offers = (response as List)
          .map((item) => SpecialOfferModel.fromMap(item as Map<String, dynamic>))
          .toList();

      // Filter hanya yang masih berlaku (valid_until >= hari ini)
      final now = DateTime.now();
      return offers.where((offer) {
        if (offer.validUntil == null) return true;
        return offer.validUntil!.isAfter(now.subtract(const Duration(days: 1)));
      }).toList();
    } catch (e) {
      print('Error fetching special offers: $e');
      return [];
    }
  }
}