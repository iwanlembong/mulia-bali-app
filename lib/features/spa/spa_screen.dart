import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // ✅ TAMBAHKAN IMPORT INI
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/spa_service_service.dart';
import '../../core/models/spa_service_model.dart';

class SpaScreen extends StatefulWidget {
  const SpaScreen({super.key});

  @override
  State<SpaScreen> createState() => _SpaScreenState();
}

class _SpaScreenState extends State<SpaScreen> {
  bool _isLoading = true;
  List<SpaServiceModel> _services = [];

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'IDR ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    setState(() => _isLoading = true);
    try {
      final data = await SpaServiceService.getActiveServices();
      if (mounted) {
        setState(() {
          _services = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching spa services: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        title: const Text(
          'Spa & Wellness',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchServices,
        color: AppColors.primaryGold,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGold),
              )
            : _services.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.spa_outlined,
                      size: 64,
                      color: AppColors.textGrey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No spa services available at the moment.',
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 16,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _fetchServices,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _services.length,
                itemBuilder: (context, index) {
                  final service = _services[index];
                  return _buildServiceCard(service);
                },
              ),
      ),
    );
  }

  Widget _buildServiceCard(SpaServiceModel service) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Gambar (jika ada)
          if (service.imageUrl != null && service.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.network(
                service.imageUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: AppColors.offWhite,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 48,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
              ),
            ),

          // 2. Informasi Detail
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kategori (jika ada)
                if (service.category != null && service.category!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B7355).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      service.category!,
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B7355),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                if (service.category != null && service.category!.isNotEmpty)
                  const SizedBox(height: 12),

                // Nama Service
                Text(
                  service.name,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkCharcoal,
                  ),
                ),

                const SizedBox(height: 8),

                // Deskripsi
                if (service.description != null &&
                    service.description!.isNotEmpty)
                  Text(
                    service.description!,
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 14,
                      color: AppColors.textGrey,
                      height: 1.5,
                    ),
                  ),

                const SizedBox(height: 16),
                const Divider(color: Color(0xFF8B7355), thickness: 1),
                const SizedBox(height: 12),

                // Durasi & Harga
                Row(
                  children: [
                    // Durasi
                    if (service.durationMinutes != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B7355).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 18,
                              color: Color(0xFF8B7355),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${service.durationMinutes} mins',
                              style: const TextStyle(
                                fontFamily: 'Lato',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8B7355),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Spacer(),

                    // Harga
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Starting from',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 11,
                            color: AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currencyFormat.format(service.price),
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ✅ PERBAIKAN: Tombol yang mengarah ke Detail Screen
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // ✅ ARAHKAN KE HALAMAN DETAIL
                      context.push('/spa/${service.id}');
                    },
                    icon: const Icon(
                      Icons.arrow_forward,
                      size: 18,
                    ), // Ikon panah lebih cocok untuk navigasi
                    label: const Text(
                      'VIEW DETAILS & BOOK',
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B7355),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
