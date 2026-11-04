import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ Tambahkan import ini

import 'core/constants/app_colors.dart';
import 'core/services/auth_service.dart';
import 'core/models/order_model.dart'; // ✅ DI SINI
import 'core/models/reward_model.dart';
import 'features/main_shell.dart';

// ✅ 1. TAMBAHKAN IMPORT HALAMAN USER YANG HILANG
import 'features/properties/properties_screen.dart';
import 'features/properties/property_detail_screen.dart';
import 'features/offers/offers_screen.dart';
import 'features/spa/spa_screen.dart';
import 'features/spa/spa_detail_screen.dart'; // ✅ TAMBAHKAN BARIS INI
import 'features/wedding/wedding_screen.dart';
import 'features/wedding/wedding_detail_screen.dart'; // ✅ TAMBAHKAN
import 'features/dining/reservation_screen.dart';
import 'features/dining/dining_detail_screen.dart'; // ✅ TAMBAHKAN

import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/reset_password_screen.dart';

import 'features/admin/admin_login_screen.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'features/admin/admin_properties_screen.dart';
import 'features/admin/admin_rooms_screen.dart';
import 'features/admin/admin_spa_screen.dart';
import 'features/admin/admin_restaurants_screen.dart';
import 'features/admin/admin_menu_items_screen.dart';
import 'features/admin/admin_hero_slides_screen.dart';
import 'features/admin/admin_special_offers_screen.dart';
import 'features/admin/admin_experiences_screen.dart';
import 'features/admin/admin_weddings_screen.dart';
import 'features/admin/admin_reservations_screen.dart'; // ✅ Tambahkan
import 'features/admin/admin_reservation_detail_screen.dart'; // ✅ Tambahkan
import 'features/cart/cart_screen.dart';
import 'features/booking/booking_confirmation_screen.dart'; // ✅ TAMBAHKAN
import 'features/profile/my_bookings_screen.dart'; // ✅ TAMBAHKAN
import 'features/profile/order_detail_screen.dart'; // ✅ TAMBAHKAN
import 'features/admin/admin_bookings_screen.dart';
import 'features/admin/admin_booking_detail_screen.dart';
import 'features/reservations/reservation_form_screen.dart'; // ✅ Tambahkan import
import 'features/reservations/my_reservations_screen.dart'; // ✅ Tambahkan ini
import 'features/reservations/reservation_detail_screen.dart'; // ✅ Tambahkan ini
import 'features/reservations/payment_instruction_screen.dart';
import 'features/admin/admin_promotions_screen.dart';
import 'features/admin/admin_payment_verification_screen.dart';
import 'features/admin/admin_rewards_screen.dart';
import 'features/admin/admin_add_reward_screen.dart';
import 'features/profile/notifications_screen.dart'; // <-- Tambahkan di atas
import 'features/admin/admin_redemptions_screen.dart';
import 'features/profile/my_favorites_screen.dart';

const String supabaseUrl = 'https://qitxjhavagqhfnkmmiyw.supabase.co';
const String supabaseAnonKey = 'sb_publishable_Xmw5kGeXzCLMQG871sRQPA_B72M137t';

// ✅ 1. BUAT GLOBAL ROUTE OBSERVER
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Load environment variables
  await dotenv.load(fileName: ".env");

  final uri = Uri.base;
  final isPasswordRecovery =
      uri.queryParameters.containsKey('code') ||
      uri.fragment.contains('type=recovery') ||
      uri.fragment.contains('access_token');

  print('🔍 [MAIN] URL: $uri');
  print('🔍 [MAIN] Is Recovery? $isPasswordRecovery');

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  // ✅ KUNCI PERBAIKAN: Inisialisasi role admin SEBELUM router dibuat
  await AuthService.initialize();

  runApp(MyApp(isPasswordRecovery: isPasswordRecovery));
}

class MyApp extends StatelessWidget {
  final bool isPasswordRecovery;

  const MyApp({super.key, required this.isPasswordRecovery});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'The Mulia Bali',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.offWhite,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryGold),
        useMaterial3: true,
      ),
      routerConfig: _createRouter(isPasswordRecovery),
    );
  }
}

GoRouter _createRouter(bool isPasswordRecovery) {
  return GoRouter(
    observers: [routeObserver], // ✅ 2. TAMBAHKAN BARIS INI
    initialLocation: isPasswordRecovery ? '/reset-password' : '/',

    redirect: (context, state) {
      final path = state.uri.path;
      final isLoggedIn = AuthService.isLoggedIn;
      final isAdmin = AuthService.isAdmin;

      // 1. PRIORITAS MUTLAK: Biarkan /reset-password lewat
      if (path == '/reset-password') return null;

      // 2. Jika BELUM login sama sekali
      if (!isLoggedIn) {
        if (path.startsWith('/admin')) return '/admin-login';

        // Izinkan halaman publik user
        if (path == '/' ||
            path == '/login' ||
            path == '/register' ||
            path == '/forgot-password' ||
            path == '/properties' ||
            path == '/offers' ||
            path == '/spa' ||
            path.startsWith('/spa/') ||
            path == '/wedding' ||
            path.startsWith('/wedding/') ||
            path == '/cart' ||
            path.startsWith('/property/') ||
            path.startsWith('/restaurant/')) {
          return null;
        }
        return '/login'; // Paksa login jika mencoba akses halaman privat user
      }

      // 3. Jika SUDAH login (Sesi dipulihkan atau baru saja login)
      if (isLoggedIn) {
        // ✅ PERBAIKAN UTAMA: Jika Admin mencoba membuka halaman User (/), lempar ke Admin Dashboard
        if (isAdmin && path == '/') {
          return '/admin/dashboard';
        }

        // ✅ Jika User biasa mencoba membuka halaman Admin, lempar ke User Dashboard
        if (!isAdmin && path.startsWith('/admin')) {
          return '/';
        }

        // ✅ Jika sudah login, jangan biarkan membuka halaman login/register lagi
        if (path == '/login' ||
            path == '/register' ||
            path == '/forgot-password' ||
            path == '/admin-login') {
          // Arahkan sesuai role mereka
          return isAdmin ? '/admin/dashboard' : '/';
        }
      }

      // 4. Izinkan akses normal untuk rute lainnya
      return null;
    },

    routes: [
      // --- AUTH ROUTES ---
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          print('🟢 [SUCCESS] ResetPasswordScreen BUILDING!');
          return const ResetPasswordScreen();
        },
      ),
      // Di dalam routes GoRouter:
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // --- USER APP ROUTES ---
      GoRoute(path: '/', builder: (context, state) => const MainShell()),

      // ✅ BARU: Route untuk halaman list Properties (Memperbaiki "Not Found")
      GoRoute(
        path: '/properties',
        builder: (context, state) => const PropertiesScreen(),
      ),

      GoRoute(
        path: '/property/:id',
        builder: (context, state) {
          final propertyId = state.pathParameters['id']!;
          return PropertyDetailScreen(propertyId: propertyId);
        },
      ),

      // ✅ BARU: Route untuk halaman Offers, Spa, Wedding (Bisa diakses tanpa login)
      GoRoute(
        path: '/offers',
        builder: (context, state) => const OffersScreen(),
      ),
      GoRoute(path: '/spa', builder: (context, state) => const SpaScreen()),
      GoRoute(
        path: '/spa/:id',
        builder: (context, state) {
          final serviceId = state.pathParameters['id']!;
          return SpaDetailScreen(serviceId: serviceId);
        },
      ),
      GoRoute(
        path: '/restaurant/:id',
        builder: (context, state) {
          final restaurantId = state.pathParameters['id']!;
          return DiningDetailScreen(restaurantId: restaurantId);
        },
      ),
      GoRoute(
        path: '/wedding',
        builder: (context, state) => const WeddingScreen(),
      ),
      GoRoute(
        path: '/wedding/:id',
        builder: (context, state) {
          final packageId = state.pathParameters['id']!;
          return WeddingDetailScreen(packageId: packageId);
        },
      ),
      GoRoute(
        path: '/reservation',
        builder: (context, state) => const ReservationScreen(),
      ),
      GoRoute(
        path: '/my-reservations',
        builder: (context, state) => const MyReservationsScreen(),
      ),
      GoRoute(
        path: '/reservation-detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReservationDetailScreen(reservationId: id);
        },
      ),
      GoRoute(
        path: '/my-favorites',
        builder: (context, state) => const MyFavoritesScreen(),
      ),
      // --- ADMIN ROUTES ---
      GoRoute(
        path: '/admin-login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) {
          if (!AuthService.isAdmin) return const AdminLoginScreen();
          return const AdminDashboardScreen();
        },
      ),
      GoRoute(
        path: '/admin/properties',
        builder: (context, state) => const AdminPropertiesScreen(),
      ),
      GoRoute(
        path: '/admin/rooms',
        builder: (context, state) {
          final propertyId = state.uri.queryParameters['propertyId'] ?? '';
          final propertyName =
              state.uri.queryParameters['propertyName'] ?? 'Property';
          return AdminRoomsScreen(
            propertyId: propertyId,
            propertyName: propertyName,
          );
        },
      ),
      GoRoute(
        path: '/admin/spa',
        builder: (context, state) => const AdminSpaScreen(),
      ),
      GoRoute(
        path: '/admin/restaurants',
        builder: (context, state) => const AdminRestaurantsScreen(),
      ),
      GoRoute(
        path: '/admin/menu-items',
        builder: (context, state) {
          final restaurantId = state.uri.queryParameters['restaurantId'] ?? '';
          final restaurantName =
              state.uri.queryParameters['restaurantName'] ?? 'Restaurant';
          return AdminMenuItemsScreen(
            restaurantId: restaurantId,
            restaurantName: restaurantName,
          );
        },
      ),
      GoRoute(
        path: '/admin/hero-slides',
        builder: (context, state) => const AdminHeroSlidesScreen(),
      ),
      GoRoute(
        path: '/admin/special-offers',
        builder: (context, state) => const AdminSpecialOffersScreen(),
      ),
      GoRoute(
        path: '/admin/experiences',
        builder: (context, state) => const AdminExperiencesScreen(),
      ),
      GoRoute(
        path: '/admin/weddings',
        builder: (context, state) => const AdminWeddingsScreen(),
      ),
      GoRoute(
        path: '/admin/bookings',
        builder: (context, state) => const AdminBookingsScreen(),
      ),
      GoRoute(
        path: '/admin/booking-detail/:id',
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          return AdminBookingDetailScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/admin/reservations',
        builder: (context, state) => const AdminReservationsScreen(),
      ),
      GoRoute(
        path: '/admin/reservation-detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AdminReservationDetailScreen(reservationId: id);
        },
      ),
      GoRoute(
        path: '/admin/promotions',
        builder: (context, state) => const AdminPromotionsScreen(),
      ),
      GoRoute(
        path: '/admin/payment-verification', // ✅ Pastikan path ini sama persis
        builder: (context, state) => const AdminPaymentVerificationScreen(),
      ),
      // ✅ BARU: Route untuk Daftar Rewards Admin
      GoRoute(
        path: '/admin/rewards',
        builder: (context, state) => const AdminRewardsScreen(),
      ),

      // ✅ BARU: Route untuk Tambah Reward Admin
      GoRoute(
        path: '/admin/add-reward',
        builder: (context, state) => AdminAddRewardScreen(
          rewardToEdit:
              state.extra
                  as Reward?, // ✅ Terima data dari halaman Manage Rewards
        ),
      ),
      GoRoute(
        path: '/admin/redemptions',
        builder: (context, state) => const AdminRedemptionsScreen(),
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/booking-confirmation',
        builder: (context, state) {
          final order = state.extra as Order;
          return BookingConfirmationScreen(order: order);
        },
      ),
      GoRoute(
        path: '/my-bookings',
        builder: (context, state) => const MyBookingsScreen(),
      ),
      GoRoute(
        path: '/booking-detail/:id',
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          return OrderDetailScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/reservation-form',
        builder: (context, state) {
          final bookingData = state.extra as Map<String, dynamic>;
          return ReservationFormScreen(bookingData: bookingData);
        },
      ),
      GoRoute(
        path: '/payment-instruction/:id',
        builder: (context, state) => PaymentInstructionScreen(
          reservationId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
}
