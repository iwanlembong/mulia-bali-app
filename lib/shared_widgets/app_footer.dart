import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      color: AppColors.darkCharcoal,
      child: Column(
        children: [
          // 1. LOGO GAMBAR (Mengganti Teks)
          Image.asset(
            'assets/images/mulia_logo.png',
            height: 50, // Sesuaikan angka ini (40-60) agar proporsional di footer
            fit: BoxFit.contain,
            
            // OPSIONAL: Jika file PNG Anda berwarna hitam polos/putih polos 
            // dan ingin diwarnai menjadi Emas, hapus tanda komentar (//) di baris bawah:
            // color: AppColors.primaryGold,

            // Fallback: Jika gambar gagal dimuat, tetap tampilkan teks agar tidak rusak
            errorBuilder: (context, error, stackTrace) {
              return const Text(
                'THE MULIA',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  color: AppColors.primaryGold,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3.0,
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),

          // 2. Informasi Kontak
          const Text(
            'Jl. Raya Nusa Dua Selatan, Nusa Dua, Bali 80363, Indonesia\n'
            '+62 361 3017777  |  reservation@themulia.com',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Lato',
              color: Colors.white70,
              fontSize: 13,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 24),

          // 3. Garis Pemisah Elegan
          const Divider(
            color: AppColors.primaryGold, 
            thickness: 1, 
            height: 1,
            indent: 40,   // Memberi jarak dari kiri
            endIndent: 40, // Memberi jarak dari kanan
          ),

          const SizedBox(height: 16),

          // 4. Copyright
          const Text(
            '© 2024 The Mulia, Mulia Resort & Villas.\nAll Rights Reserved.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Lato',
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}