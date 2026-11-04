import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/experience_model.dart';

class ExperienceService {
  static Future<List<ExperienceModel>> getActiveExperiences() async {
    try {
      final response = await Supabase.instance.client
          .from('experiences')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return (response as List)
          .map((item) => ExperienceModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching experiences: $e');
      return [];
    }
  }
}