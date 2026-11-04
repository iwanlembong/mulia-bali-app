   import 'package:flutter/material.dart';
   import 'package:google_fonts/google_fonts.dart';
   import '../constants/app_colors.dart';

   class AppTheme {
     static ThemeData get lightTheme {
       return ThemeData(
         useMaterial3: true,
         scaffoldBackgroundColor: AppColors.offWhite,
         primaryColor: AppColors.primaryGold,
         textTheme: TextTheme(
           // Font untuk Judul (Elegan)
           displayLarge: GoogleFonts.playfairDisplay(
             color: AppColors.darkCharcoal,
             fontWeight: FontWeight.bold,
           ),
           titleLarge: GoogleFonts.playfairDisplay(
             color: AppColors.darkCharcoal,
             fontWeight: FontWeight.w600,
           ),
           // Font untuk Teks Biasa (Mudah dibaca)
           bodyLarge: GoogleFonts.lato(
             color: AppColors.textGrey,
             fontSize: 16,
           ),
         ),
         appBarTheme: const AppBarTheme(
           backgroundColor: Colors.transparent,
           elevation: 0,
           iconTheme: IconThemeData(color: AppColors.darkCharcoal),
         ),
       );
     }
   }