import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hero_slide_model.dart';

/// Service untuk mengelola Hero Slides
class HeroSlideService {
  /// Ambil semua hero slides yang aktif, diurutkan berdasarkan sort_order
  static Future<List<HeroSlide>> getActiveSlides() async {
    try {
      final response = await Supabase.instance.client
          .from('hero_slides')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return (response as List)
          .map((item) => HeroSlide.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching hero slides: $e');
      return [];
    }
  }
}