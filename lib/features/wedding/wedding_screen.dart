import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // ✅ DI SINI
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/wedding_service.dart';
import '../../core/models/wedding_model.dart';

class WeddingScreen extends StatefulWidget {
  const WeddingScreen({super.key});

  @override
  State<WeddingScreen> createState() => _WeddingScreenState();
}

class _WeddingScreenState extends State<WeddingScreen> {
  bool _isLoading = true;
  List<WeddingModel> _packages = [];
  
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'IDR ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchPackages();
  }

  Future<void> _fetchPackages() async {
    setState(() => _isLoading = true);
    try {
      final data = await WeddingService.getActivePackages();
      if (mounted) {
        setState(() {
          _packages = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching wedding packages: $e');
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
          'Weddings',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPackages,
        color: AppColors.primaryGold,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGold),
              )
            : _packages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.favorite_outline,
                          size: 64,
                          color: AppColors.textGrey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No wedding packages available at the moment.',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 16,
                            color: AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchPackages,
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
                    itemCount: _packages.length,
                    itemBuilder: (context, index) {
                      final package = _packages[index];
                      return _buildPackageCard(package);
                    },
                  ),
      ),
    );
  }

  Widget _buildPackageCard(WeddingModel package) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Gambar
          if (package.imageUrl != null && package.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                package.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: AppColors.offWhite,
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 48, color: AppColors.textGrey),
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
                // Nama Package
                Text(
                  package.packageName,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                
                const SizedBox(height: 8),

                // Deskripsi
                if (package.description != null && package.description!.isNotEmpty)
                  Text(
                    package.description!,
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 14,
                      color: AppColors.textGrey,
                      height: 1.5,
                    ),
                  ),
                
                const SizedBox(height: 16),

                // Includes (apa saja yang termasuk)
                if (package.includes.isNotEmpty) ...[
                  const Text(
                    'Package Includes:',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...package.includes.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.pink,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 13,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 16),
                ],

                const Divider(color: Colors.pink, thickness: 1),
                const SizedBox(height: 12),

                // Harga
                if (package.price != null)
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            _currencyFormat.format(package.price),
                            style: const TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkCharcoal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Tombol Inquiry
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // ✅ PERBAIKAN: Arahkan ke halaman detail
                      context.push('/wedding/${package.id}');
                    },
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text(
                      'VIEW DETAILS & INQUIRE',
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.shade300,
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