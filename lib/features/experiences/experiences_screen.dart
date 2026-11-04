import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/experience_service.dart';
import '../../core/models/experience_model.dart';

class ExperiencesScreen extends StatefulWidget {
  const ExperiencesScreen({super.key});

  @override
  State<ExperiencesScreen> createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends State<ExperiencesScreen> {
  bool _isLoading = true;
  List<ExperienceModel> _experiences = [];

  @override
  void initState() {
    super.initState();
    _fetchExperiences();
  }

  Future<void> _fetchExperiences() async {
    setState(() => _isLoading = true);
    final data = await ExperienceService.getActiveExperiences();
    if (mounted) {
      setState(() {
        _experiences = data;
        _isLoading = false;
      });
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'spa': return Icons.spa;
      case 'restaurant': case 'dining': return Icons.restaurant;
      case 'pool': return Icons.pool;
      case 'fitness': case 'gym': return Icons.fitness_center;
      case 'kids': return Icons.child_care;
      case 'beach': return Icons.beach_access;
      case 'tour': case 'trip': return Icons.explore;
      default: return Icons.star;
    }
  }

  // ✅ DIPERBAIKI TOTAL: Menggunakan Dialog custom dengan constraints pasti
  void _showExperienceDetail(ExperienceModel exp) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // ✅ KUNCI: Berikan ukuran pasti pada dialog
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85, // 85% dari lebar layar
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gambar dengan ukuran pasti
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    exp.imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      width: double.infinity,
                      color: AppColors.offWhite,
                      child: const Icon(Icons.image_not_supported, size: 48, color: AppColors.textGrey),
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Judul dengan Icon
                      Row(
                        children: [
                          Icon(_getIconData(exp.iconName), color: AppColors.primaryGold, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              exp.title,
                              style: const TextStyle(
                                fontFamily: 'Playfair Display',
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkCharcoal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      // Deskripsi
                      const Text(
                        'About this experience',
                        style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        exp.description,
                        style: const TextStyle(fontFamily: 'Lato', fontSize: 14, color: AppColors.textGrey, height: 1.6),
                      ),
                      const SizedBox(height: 24),
                      
                      // Info Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.primaryGold, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This is an informational guide. Please inquire with our concierge team for availability and arrangements.',
                                style: TextStyle(
                                  fontFamily: 'Lato', 
                                  fontSize: 12, 
                                  color: AppColors.darkCharcoal, 
                                  fontStyle: FontStyle.italic
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Tombol Close
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.darkCharcoal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Close', style: TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        title: const Text(
          'Curated Experiences',
          style: TextStyle(fontFamily: 'Playfair Display', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : _experiences.isEmpty
          ? const Center(
              child: Text(
                'No experiences available at the moment.',
                style: TextStyle(fontFamily: 'Lato', color: AppColors.textGrey),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchExperiences,
              color: AppColors.primaryGold,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, 
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: _experiences.length,
                itemBuilder: (context, index) {
                  final exp = _experiences[index];
                  
                  return InkWell(
                    onTap: () => _showExperienceDetail(exp),
                    borderRadius: BorderRadius.circular(16),
                    child: Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 1.2,
                            child: Image.network(
                              exp.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.offWhite,
                                child: const Icon(Icons.image_not_supported, size: 48, color: AppColors.textGrey),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(_getIconData(exp.iconName), color: AppColors.primaryGold, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        exp.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Playfair Display',
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.darkCharcoal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tap for details',
                                  style: TextStyle(
                                    fontFamily: 'Lato',
                                    fontSize: 11,
                                    color: AppColors.primaryGold,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}