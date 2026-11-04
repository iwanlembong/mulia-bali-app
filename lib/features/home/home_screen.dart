import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../shared_widgets/app_footer.dart';
import '../main_shell.dart';
import '../../core/services/hero_slide_service.dart';
import '../../core/models/hero_slide_model.dart';
import '../../core/services/property_service.dart';
import '../../core/services/special_offer_service.dart';
import '../../core/models/special_offer_model.dart';
import '../../core/services/restaurant_service.dart';
import '../../core/services/cart_service.dart';
import '../../core/widgets/offer_detail_dialog.dart'; // ✅ Tambahkan ini

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late PageController _heroPageController;
  late PageController _accommodationPageController;
  StreamSubscription<AuthState>? _authSubscription;
  int _currentHeroPage = 0;
  Timer? _heroTimer;

  String? _avatarUrl;

  int _cartItemCount = 0;

  // --- DATA & STATE ---
  final List<Map<String, String>> heroSlides = [
    {
      'image': 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=800&q=80',
      'title': 'The Mulia',
      'subtitle': 'All-Suite Beachfront Resort, Nusa Dua',
    },
    {
      'image': 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=800&q=80',
      'title': 'Mulia Villas',
      'subtitle': 'Exclusive All-Pool Villas & Ultimate Privacy',
    },
    {
      'image': 'https://images.unsplash.com/photo-1571003123894-1f0594d2b5d9?auto=format&fit=crop&w=800&q=80',
      'title': 'Mulia Resort',
      'subtitle': 'A Vibrant Playground for the Whole Family',
    },
  ];

  List<HeroSlide> _heroSlides = [];
  bool _isLoadingHeroSlides = true;

  List<Map<String, dynamic>> _dynamicAccommodations = [];
  bool _isLoadingAccommodations = true;

  List<SpecialOfferModel> _specialOffers = [];
  bool _isLoadingOffers = true;

  List<Map<String, dynamic>> _restaurants = [];
  bool _isLoadingRestaurants = true;

  final List<Map<String, String>> _fallbackOffers = [
    {
      'title': 'Romantic Getaway',
      'image': 'https://images.unsplash.com/photo-1515934751635-c81c6bc9a2d8?auto=format&fit=crop&w=600&q=80',
      'validity': 'Valid until 31 Dec 2026',
    },
    {
      'title': 'Family Fun Package',
      'image': 'https://images.unsplash.com/photo-1596464716127-f2a82984de30?auto=format&fit=crop&w=600&q=80',
      'validity': 'Valid until 31 Dec 2026',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _heroPageController = PageController(initialPage: 0);
    _accommodationPageController = PageController(viewportFraction: 0.85);

    _fetchHeroSlides();
    _fetchAccommodations();
    _fetchSpecialOffers();
    _fetchRestaurants(); // ✅ TAMBAHKAN
    _fetchCartCount(); // Ini akan menginisialisasi nilai awa
    _startHeroAutoSlide();

    // ✅ DENGARKAN PERUBAHAN DARI CART SERVICE SECARA REAL-TIME
    CartService.itemCountNotifier.addListener(_onCartCountChanged);

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _fetchUserProfile();
      } else if (event == AuthChangeEvent.signedOut) {
        if (mounted) setState(() => _avatarUrl = null);
      }
    });

    if (AuthService.isLoggedIn) {
      _fetchUserProfile();
    }
  }

  // ✅ FUNGSI CALLBACK SAAT COUNT BERUBAH
  void _onCartCountChanged() {
    if (mounted) {
      setState(() {
        _cartItemCount = CartService.itemCountNotifier.value;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && AuthService.isLoggedIn) {
      _fetchUserProfile();
    }
  }

  void refreshAvatar() {
    if (AuthService.isLoggedIn) _fetchUserProfile();
  }

  void _startHeroAutoSlide() {
    _heroTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_currentHeroPage <
          (_heroSlides.isNotEmpty ? _heroSlides.length : heroSlides.length) -
              1) {
        _currentHeroPage++;
      } else {
        _currentHeroPage = 0;
      }
      _heroPageController.animateToPage(
        _currentHeroPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  // ✅ TAMBAHKAN: Method public agar bisa dipanggil dari SpaDetailScreen
  void refreshCartCount() {
    _fetchCartCount();
  }

  Future<void> _fetchHeroSlides() async {
    final slides = await HeroSlideService.getActiveSlides();
    if (mounted)
      setState(() {
        _heroSlides = slides;
        _isLoadingHeroSlides = false;
      });
  }

  Future<void> _fetchAccommodations() async {
    final data = await PropertyService.getAllRoomsForCarousel();
    if (mounted)
      setState(() {
        _dynamicAccommodations = data;
        _isLoadingAccommodations = false;
      });
  }

  Future<void> _fetchSpecialOffers() async {
    final offers = await SpecialOfferService.getActiveOffers();
    if (mounted)
      setState(() {
        _specialOffers = offers;
        _isLoadingOffers = false;
      });
  }

  Future<void> _fetchRestaurants() async {
    final data = await RestaurantService.getActiveRestaurants();
    if (mounted) {
      setState(() {
        _restaurants = data;
        _isLoadingRestaurants = false;
      });
    }
  }

  Future<void> _fetchCartCount() async {
    if (AuthService.isLoggedIn) {
      final count = await CartService.getCartItemCount();
      CartService.itemCountNotifier.value = count; // Sinkronkan
      if (mounted) {
        setState(() => _cartItemCount = count);
      }
    } else {
      CartService.itemCountNotifier.value = 0;
      if (mounted) {
        setState(() => _cartItemCount = 0);
      }
    }
  }

  Future<void> _fetchUserProfile() async {
    if (AuthService.isLoggedIn) {
      final userId = AuthService.currentUserId;
      if (userId != null) {
        try {
          final response = await Supabase.instance.client
              .from('profiles')
              .select('avatar_url')
              .eq('id', userId)
              .maybeSingle();

          if (mounted && response != null) {
            final newAvatarUrl = response['avatar_url'] as String?;
            if (newAvatarUrl != _avatarUrl) {
              setState(() => _avatarUrl = newAvatarUrl);
            }
          }
        } catch (e) {
          print('Error fetching avatar: $e');
        }
      }
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final priceInt = price is int ? price : int.tryParse(price.toString()) ?? 0;
    return priceInt.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  void dispose() {
    // ✅ HAPUS LISTENER AGAR TIDAK MEMORY LEAK
    CartService.itemCountNotifier.removeListener(_onCartCountChanged);

    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _heroTimer?.cancel();
    _heroPageController.dispose();
    _accommodationPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. SLIDESHOW HEADER
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            actions: [
              // ✅ BARU: Icon Cart dengan Badge
              if (AuthService.isLoggedIn)
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: () {
                        context.push('/cart').then((_) => _fetchCartCount());
                      },
                    ),
                    if (_cartItemCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '$_cartItemCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              _avatarUrl != null && _avatarUrl!.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        final shellState = context
                            .findAncestorStateOfType<MainShellState>();
                        if (shellState != null) shellState.onItemTapped(3);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(_avatarUrl!),
                          backgroundColor: AppColors.primaryGold,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        if (AuthService.isLoggedIn) {
                          final shellState = context
                              .findAncestorStateOfType<MainShellState>();
                          if (shellState != null) shellState.onItemTapped(3);
                        } else {
                          context.push('/login');
                        }
                      },
                    ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isLoadingHeroSlides)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGold,
                      ),
                    )
                  else if (_heroSlides.isNotEmpty)
                    PageView.builder(
                      controller: _heroPageController,
                      onPageChanged: (index) =>
                          setState(() => _currentHeroPage = index),
                      itemCount: _heroSlides.length,
                      itemBuilder: (context, index) {
                        final slide = _heroSlides[index];
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              slide.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: AppColors.darkCharcoal),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.8),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 60,
                              left: 24,
                              right: 24,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    slide.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Playfair Display',
                                    ),
                                  ),
                                  if (slide.subtitle != null &&
                                      slide.subtitle!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      slide.subtitle!,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        fontFamily: 'Lato',
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  else
                    PageView.builder(
                      controller: _heroPageController,
                      onPageChanged: (index) =>
                          setState(() => _currentHeroPage = index),
                      itemCount: heroSlides.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              heroSlides[index]['image']!,
                              fit: BoxFit.cover,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.8),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 60,
                              left: 24,
                              right: 24,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    heroSlides[index]['title']!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Playfair Display',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    heroSlides[index]['subtitle']!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      fontFamily: 'Lato',
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Builder(
                      builder: (context) {
                        final slideCount = _heroSlides.isNotEmpty
                            ? _heroSlides.length
                            : heroSlides.length;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            slideCount,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 8,
                              width: _currentHeroPage == index ? 24 : 8,
                              decoration: BoxDecoration(
                                color: _currentHeroPage == index
                                    ? AppColors.primaryGold
                                    : Colors.white54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. KONTEN UTAMA
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
                  child: Text(
                    'Exclusive Accommodations',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Playfair Display',
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                ),

                // --- CAROUSEL AKOMODASI ---
                SizedBox(
                  height: 280,
                  child: _isLoadingAccommodations
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGold,
                          ),
                        )
                      : _dynamicAccommodations.isNotEmpty
                      ? PageView.builder(
                          controller: _accommodationPageController,
                          itemCount: _dynamicAccommodations.length,
                          itemBuilder: (context, index) {
                            final item = _dynamicAccommodations[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: _buildAccommodationCard(
                                context,
                                property: item['property']!,
                                room: item['room']!,
                                price: 'IDR ${_formatPrice(item['price'])}',
                                image: item['image']!,
                                bedType: item['bed_type'] as String?,
                                sizeSqm: (item['size_sqm'] as num?)?.toDouble(),

                                // ✅ LOGIKA SANGAT SEDERHANA & LANGSUNG
                                onTap: () {
                                  // Ambil ID yang baru saja Anda tambahkan di property_services.dart
                                  final propertyId = item['id']?.toString();

                                  if (propertyId != null &&
                                      propertyId.isNotEmpty) {
                                    print(
                                      '🚀 [DEBUG] Berhasil! Navigating to property ID: $propertyId',
                                    );
                                    context.push('/property/$propertyId');
                                  } else {
                                    print(
                                      '❌ [DEBUG] Gagal menemukan Property ID! Data: $item',
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Data properti tidak lengkap',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: Text(
                            'There are no rooms available at the moment.',
                            style: TextStyle(
                              fontFamily: 'Lato',
                              color: AppColors.textGrey,
                              fontSize: 14,
                            ),
                          ),
                        ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/properties'),
                      child: const Text(
                        'View All Properties →',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 13,
                          color: AppColors.primaryGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                // --- DINING & CULINARY (BARU) ---
                const Padding(
                  padding: EdgeInsets.fromLTRB(16.0, 32.0, 16.0, 16.0),
                  child: Text(
                    'Dining & Culinary',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Playfair Display',
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                ),

                SizedBox(
                  height: 280,
                  child: _isLoadingRestaurants
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGold,
                          ),
                        )
                      : _restaurants.isNotEmpty
                      ? ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _restaurants.length,
                          itemBuilder: (context, index) {
                            final restaurant = _restaurants[index];
                            return _buildRestaurantCard(restaurant);
                          },
                        )
                      : const Center(
                          child: Text(
                            'No restaurants available at the moment.',
                            style: TextStyle(
                              fontFamily: 'Lato',
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                ),

                // --- THE MULIA EXPERIENCE (sudah ada) ---
                const Padding(
                  padding: EdgeInsets.fromLTRB(16.0, 32.0, 16.0, 16.0),
                  child: Text(
                    'The Mulia Experience',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Playfair Display',
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                ),

                // --- SPECIAL OFFERS (DINAMIS) ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Special Offers',
                        style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/offers'),
                        child: const Text(
                          'See All',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            color: AppColors.primaryGold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 220,
                  child: _isLoadingOffers
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGold,
                          ),
                        )
                      : _specialOffers.isNotEmpty
                      ? ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          // ✅ BATASI HANYA 4 ITEM DI HOME SCREEN
                          itemCount: _specialOffers.length > 4
                              ? 4
                              : _specialOffers.length,
                          itemBuilder: (context, index) {
                            return _buildOfferCard(_specialOffers[index]);
                          },
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _fallbackOffers.length,
                          itemBuilder: (context, index) =>
                              _buildOfferCardFromMap(_fallbackOffers[index]),
                        ),
                ),

                // ✅ PERBAIKAN: MENGGUNAKAN _buildExperienceCard AGAR TIDAK "UNUSED"
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildExperienceCard(
                          context,
                          'Spa',
                          Icons.spa,
                          const Color(0xFF8B7355),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildExperienceCard(
                          context,
                          'Weddings',
                          Icons.diamond,
                          Colors.pink.shade300,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                const AppFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildOfferCard(SpecialOfferModel offer) {
    return GestureDetector(
      // ✅ Bungkus dengan GestureDetector agar bisa diklik
      onTap: () =>
          OfferDetailDialog.show(context, offer), // ✅ Panggil dialog kita
      child: Container(
        width: 280, // Lebar tetap untuk horizontal scroll
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar Offer
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.network(
                offer.imageUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 140,
                  color: AppColors.offWhite,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: AppColors.textGrey,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (offer.discountPercentage != null &&
                      offer.discountPercentage! > 0)
                    Text(
                      'Up to ${offer.discountPercentage}% OFF',
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferCardFromMap(Map<String, dynamic> map) {
    // ✅ 1. Konversi Map menjadi SpecialOfferModel terlebih dahulu
    final offer = SpecialOfferModel.fromMap(map);

    // ✅ 2. Gunakan GestureDetector dan kirim object 'offer' ke dialog
    return GestureDetector(
      onTap: () => OfferDetailDialog.show(context, offer),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.network(
                offer.imageUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 140,
                  color: AppColors.offWhite,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: AppColors.textGrey,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (offer.discountPercentage != null &&
                      offer.discountPercentage! > 0)
                    Text(
                      'Up to ${offer.discountPercentage}% OFF',
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccommodationCard(
    BuildContext context, {
    required dynamic property,
    required dynamic room,
    required String price,
    required String image,
    String? bedType,
    double? sizeSqm,
    VoidCallback? onTap, // ✅ Parameter dari luar
  }) {
    // ✅ 1. GANTI GestureDetector DENGAN InkWell AGAR ADA EFEK RIPPLE SAAT DIKLIK
    return InkWell(
      onTap:
          onTap, // ✅ 2. INI KUNCINYA: Hubungkan fungsi klik dari luar ke sini
      borderRadius: BorderRadius.circular(
        16,
      ), // Agar efek ripple mengikuti bentuk kartu
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.network(
                  image,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.offWhite,
                    child: const Icon(
                      Icons.image_not_supported,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ✅ 3. SAFE CHECK: Pastikan tidak crash jika property adalah Map/Object
                    Text(
                      (property is String
                              ? property
                              : (property['name'] ?? 'Property'))
                          .toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primaryGold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room.toString(), // Safe check untuk room
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (bedType != null || sizeSqm != null)
                      Row(
                        children: [
                          if (bedType != null &&
                              bedType.toString().isNotEmpty) ...[
                            const Icon(
                              Icons.king_bed_outlined,
                              size: 13,
                              color: AppColors.textGrey,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                bedType.toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 11,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ),
                          ],
                          if (bedType != null &&
                              bedType.toString().isNotEmpty &&
                              sizeSqm != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 2,
                              height: 2,
                              decoration: const BoxDecoration(
                                color: AppColors.textGrey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (sizeSqm != null) ...[
                            const Icon(
                              Icons.square_foot_outlined,
                              size: 13,
                              color: AppColors.textGrey,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${sizeSqm.toStringAsFixed(0)} sqm',
                              style: const TextStyle(
                                fontFamily: 'Lato',
                                fontSize: 11,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'From $price / night',
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 12,
                        color: AppColors.darkCharcoal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(Map<String, dynamic> restaurant) {
    return GestureDetector(
      onTap: () {
        // ✅ PERBAIKAN: Arahkan ke halaman detail restoran
        context.push('/restaurant/${restaurant['id']}');
      },
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar restoran
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.network(
                    restaurant['cover_image'] ?? 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=600&q=80',
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 150,
                      color: AppColors.offWhite,
                      child: const Icon(
                        Icons.restaurant,
                        color: AppColors.textGrey,
                        size: 48,
                      ),
                    ),
                  ),
                ),
                // Badge cuisine type
                if (restaurant['cuisine_type'] != null &&
                    restaurant['cuisine_type'].toString().isNotEmpty)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B8E23),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        restaurant['cuisine_type'],
                        style: const TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Info restoran
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant['name'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (restaurant['operating_hours'] != null &&
                        restaurant['operating_hours'].toString().isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppColors.textGrey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              restaurant['operating_hours'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Lato',
                                fontSize: 11,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(
                          Icons.restaurant_menu,
                          size: 14,
                          color: const Color(0xFF6B8E23),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'View Menu',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B8E23),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ FUNGSI INI SEKARANG DIGUNAKAN DI BAGIAN "The Mulia Experience"
  Widget _buildExperienceCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return GestureDetector(
      onTap: () {
        if (title == 'Spa') {
          context.push('/spa'); // Menggunakan go_router agar konsisten
        } else if (title == 'Weddings') {
          context.push('/wedding');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Lato',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.darkCharcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
