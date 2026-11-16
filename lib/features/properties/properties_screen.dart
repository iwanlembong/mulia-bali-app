import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/property_model.dart'; // Untuk DbProperty dan fallback baliProperties
import '../../core/services/property_service.dart';
import '../../shared_widgets/room_card.dart';

class PropertiesScreen extends StatefulWidget {
  const PropertiesScreen({super.key});

  @override
  State<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> {
  bool _isLoading = true;
  List<DbProperty> _properties = [];

  @override
  void initState() {
    super.initState();
    _fetchProperties();
  }

  Future<void> _fetchProperties() async {
    try {
      // 1. Coba ambil dari Database
      final dbProperties = await PropertyService.getActiveProperties();

      if (mounted) {
        setState(() {
          // Jika database ada isinya, pakai itu. Jika kosong, pakai fallback.
          _properties = dbProperties.isNotEmpty
              ? dbProperties
              : _getFallbackProperties();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching properties: $e');
      if (mounted) {
        setState(() {
          // 2. FALLBACK: Jika error, tetap tampilkan data hardcoded agar tidak blank
          _properties = _getFallbackProperties();
          _isLoading = false;
        });
      }
    }
  }

  // ✅ Helper: Mengonversi baliProperties (hardcoded) menjadi List<DbProperty>
  List<DbProperty> _getFallbackProperties() {
    return baliProperties
        .map(
          (p) => DbProperty(
            id: p.id,
            name: p.name,
            tagline: p.tagline,
            coverImage: p.heroImageUrl,
            isActive: true,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 1. Variabel 'listContent' = ListView Anda yang SAMA PERSIS, tidak diubah
    final listContent = ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _properties.length,
      itemBuilder: (context, index) {
        final property = _properties[index];

        // ✅ Tetap menggunakan RoomCard Anda yang sudah ada
        return RoomCard(
          imageUrl: property.coverImage ?? 'https://images.unsplash.com/photo-1571003123894-1f0594d2b5d9?auto=format&fit=crop&w=600&q=80',
          title: property.name,
          price: property.tagline ?? 'Luxury Resort',
          onTap: () {
            context.push('/property/${property.id}');
          },
        );
      },
    );

    // ✅ Widget reusable untuk state kosong & loading (agar tidak duplikat kode)
    final loadingWidget = const Center(
      child: CircularProgressIndicator(color: AppColors.primaryGold),
    );

    final emptyWidget = const Center(
      child: Text(
        'No properties available at the moment.',
        style: TextStyle(fontFamily: 'Lato', color: AppColors.textGrey),
      ),
    );

    // ✅ 2. Wrapper Responsif (Mobile tidak berubah, Desktop/Tablet upgrade)
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text(
          'Properties in Bali',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
            color: AppColors.darkCharcoal,
          ),
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 600;

          // --- MOBILE: Tampilan lama TIDAK DIUBAH (PWA 100% Aman) ---
          if (!isDesktop) {
            if (_isLoading) return loadingWidget;
            if (_properties.isEmpty) return emptyWidget;
            return listContent; // Kembalikan ListView asli apa adanya
          }

          // --- TABLET & DESKTOP: Centered Constrained List + Gradient ---
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF7F5F0),
                  Color(0xFFEDE7DA),
                  Color(0xFFF7F5F0),
                ],
              ),
            ),
            child: _isLoading
                ? loadingWidget
                : _properties.isEmpty
                ? emptyWidget
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: ConstrainedBox(
                        // ✅ 800px (bukan 900) karena RoomCard bergambar besar
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: listContent, // Gunakan ListView yang sama!
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
