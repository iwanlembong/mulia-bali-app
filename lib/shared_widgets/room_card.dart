import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/constants/app_colors.dart';

class RoomCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String price;
  final VoidCallback onTap;

  const RoomCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // GAMBAR KAMAR (SUDAH DIPERBAIKI UNTUK WEB)
              Image.network(
                imageUrl,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  // Jika gambar sudah selesai dimuat, tampilkan gambarnya
                  if (loadingProgress == null) return child;
                  // Jika masih loading, tampilkan spinner emas
                  return const SizedBox(
                    height: 240,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primaryGold),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  // Jika gagal dimuat (misal internet putus), tampilkan ikon error
                  return Container(
                    height: 240,
                    width: double.infinity,
                    color: AppColors.darkCharcoal.withOpacity(0.1),
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 50, color: AppColors.textGrey),
                    ),
                  );
                },
              ),
              
              // Gradient Overlay agar teks terbaca jelas
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Playfair Display',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Starting from $price / night',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fade(duration: 600.ms).slideY(begin: 0.2, end: 0), // Animasi muncul
    );
  }
}