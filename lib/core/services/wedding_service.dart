import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/wedding_model.dart';

class WeddingService {
  /// Ambil semua wedding packages yang aktif
  static Future<List<WeddingModel>> getActivePackages() async {
    try {
      final response = await Supabase.instance.client
          .from('weddings')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return (response as List)
          .map((item) => WeddingModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching wedding packages: $e');
      return [];
    }
  }
}