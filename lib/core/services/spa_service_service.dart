import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/spa_service_model.dart';

class SpaServiceService {
  /// Ambil semua spa services yang aktif
  static Future<List<SpaServiceModel>> getActiveServices() async {
    try {
      final response = await Supabase.instance.client
          .from('spa_services')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return (response as List)
          .map((item) => SpaServiceModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching spa services: $e');
      return [];
    }
  }
}