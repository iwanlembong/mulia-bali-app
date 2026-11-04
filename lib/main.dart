import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/constants/app_colors.dart';
import 'core/services/auth_service.dart';
import 'core/models/order_model.dart';
import 'core/models/reward_model.dart';
import 'features/main_shell.dart';

// --- USER APP ROUTES ---
import 'features/properties/properties_screen.dart';
import 'features/properties/property_detail_screen.dart';
import 'features/offers/offers_screen.dart';
import 'features/spa/spa_screen.dart';
import 'features/spa/spa_detail_screen.dart';
import 'features/wedding/wedding_screen.dart';
import 'features/wedding/wedding_detail_screen.dart';
import 'features/dining/reservation_screen.dart';
import 'features/dining/dining_detail_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/booking/booking_confirmation_screen.dart';
import 'features/profile/my_bookings_screen.dart';
import 'features/profile/order_detail_screen.dart';
import 'features/profile/notifications_screen.dart';
import 'features/profile/my_favorites_screen.dart';

// --- AUTH ROUTES ---
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/reset_password_screen.dart';

// --- ADMIN ROUTES ---
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
import 'features/admin/admin_reservations_screen.dart';
import 'features/admin/admin_reservation_detail_screen.dart';
import 'features/admin/admin_bookings_screen.dart';
import 'features/admin/admin_booking_detail_screen.dart';
import 'features/admin/admin_promotions_screen.dart';
import 'features/admin/admin_payment_verification_screen.dart';
import 'features/admin/admin_rewards_screen.dart';
import 'features/admin/admin_add_reward_screen.dart';
import 'features/admin/admin_redemptions_screen.dart';
import 'features/admin/admin_reviews_screen.dart';

// --- RESERVATION ROUTES ---
import 'features/reservations/reservation_form_screen.dart';
import 'features/reservations/my_reservations_screen.dart';
import 'features/reservations/reservation_detail_screen.dart';
import 'features/reservations/payment_instruction_screen.dart';

const String supabaseUrl = 'https://qitxjhavagqhfnkmmiyw.supabase.co';
const String supabaseAnonKey = 'sb_publishable_Xmw5kGeXzCLMQG871sRQPA_B72M137t';

// ✅ GLOBAL ROUTE OBSERVER
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

  // ✅ Inisialisasi role admin SEBELUM router dibuat
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
    observers: [routeObserver],
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
        // ✅ PERBAIKAN: HAPUS paksaan redirect admin ke dashboard. 
        // Biarkan admin masuk ke halaman user biasa (/) seperti user lainnya.
        // Admin bisa masuk ke dashboard secara manual lewat menu di aplikasi.

        // ✅ Jika sudah login, jangan biarkan membuka halaman login/register/admin-login lagi
        if (path == '/login' ||
            path == '/register' ||
            path == '/forgot-password' ||
            path == '/admin-login') {
          return '/'; // SELALU arahkan ke halaman utama user
        }

        // ✅ Jika User biasa mencoba membuka halaman Admin, lempar ke User Dashboard
        if (!isAdmin && path.startsWith('/admin')) {
          return '/';
        }
      }

      // 4. Izinkan akses normal untuk rute lainnya
      return null;
    },

    routes: [
      // --- AUTH ROUTES ---
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          print('🟢 [SUCCESS] ResetPasswordScreen BUILDING!');
          return const ResetPasswordScreen();
        },
      ),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),

      // --- USER APP ROUTES ---
      GoRoute(path: '/', builder: (context, state) => const MainShell()),
      GoRoute(path: '/properties', builder: (context, state) => const PropertiesScreen()),
      GoRoute(
        path: '/property/:id',
        builder: (context, state) => PropertyDetailScreen(propertyId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/offers', builder: (context, state) => const OffersScreen()),
      GoRoute(path: '/spa', builder: (context, state) => const SpaScreen()),
      GoRoute(
        path: '/spa/:id',
        builder: (context, state) => SpaDetailScreen(serviceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/restaurant/:id',
        builder: (context, state) => DiningDetailScreen(restaurantId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/wedding', builder: (context, state) => const WeddingScreen()),
      GoRoute(
        path: '/wedding/:id',
        builder: (context, state) => WeddingDetailScreen(packageId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/reservation', builder: (context, state) => const ReservationScreen()),
      GoRoute(path: '/my-reservations', builder: (context, state) => const MyReservationsScreen()),
      GoRoute(
        path: '/reservation-detail/:id',
        builder: (context, state) => ReservationDetailScreen(reservationId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/my-favorites', builder: (context, state) => const MyFavoritesScreen()),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/booking-confirmation',
        builder: (context, state) => BookingConfirmationScreen(order: state.extra as Order),
      ),
      GoRoute(path: '/my-bookings', builder: (context, state) => const MyBookingsScreen()),
      GoRoute(
        path: '/booking-detail/:id',
        builder: (context, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/reservation-form',
        builder: (context, state) => ReservationFormScreen(bookingData: state.extra as Map<String, dynamic>),
      ),
      GoRoute(
        path: '/payment-instruction/:id',
        builder: (context, state) => PaymentInstructionScreen(reservationId: state.pathParameters['id']!),
      ),

      // --- ADMIN ROUTES ---
      GoRoute(path: '/admin-login', builder: (context, state) => const AdminLoginScreen()),
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) {
          if (!AuthService.isAdmin) return const AdminLoginScreen();
          return const AdminDashboardScreen();
        },
      ),
      GoRoute(path: '/admin/properties', builder: (context, state) => const AdminPropertiesScreen()),
      GoRoute(
        path: '/admin/rooms',
        builder: (context, state) => AdminRoomsScreen(
          propertyId: state.uri.queryParameters['propertyId'] ?? '',
          propertyName: state.uri.queryParameters['propertyName'] ?? 'Property',
        ),
      ),
      GoRoute(path: '/admin/spa', builder: (context, state) => const AdminSpaScreen()),
      GoRoute(path: '/admin/restaurants', builder: (context, state) => const AdminRestaurantsScreen()),
      GoRoute(
        path: '/admin/menu-items',
        builder: (context, state) => AdminMenuItemsScreen(
          restaurantId: state.uri.queryParameters['restaurantId'] ?? '',
          restaurantName: state.uri.queryParameters['restaurantName'] ?? 'Restaurant',
        ),
      ),
      GoRoute(path: '/admin/hero-slides', builder: (context, state) => const AdminHeroSlidesScreen()),
      GoRoute(path: '/admin/special-offers', builder: (context, state) => const AdminSpecialOffersScreen()),
      GoRoute(path: '/admin/experiences', builder: (context, state) => const AdminExperiencesScreen()),
      GoRoute(path: '/admin/weddings', builder: (context, state) => const AdminWeddingsScreen()),
      GoRoute(path: '/admin/bookings', builder: (context, state) => const AdminBookingsScreen()),
      GoRoute(
        path: '/admin/booking-detail/:id',
        builder: (context, state) => AdminBookingDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin/reservations', builder: (context, state) => const AdminReservationsScreen()),
      GoRoute(
        path: '/admin/reservation-detail/:id',
        builder: (context, state) => AdminReservationDetailScreen(reservationId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/admin/promotions', builder: (context, state) => const AdminPromotionsScreen()),
      GoRoute(path: '/admin/payment-verification', builder: (context, state) => const AdminPaymentVerificationScreen()),
      GoRoute(path: '/admin/rewards', builder: (context, state) => const AdminRewardsScreen()),
      GoRoute(
        path: '/admin/add-reward',
        builder: (context, state) => AdminAddRewardScreen(rewardToEdit: state.extra as Reward?),
      ),
      GoRoute(path: '/admin/redemptions', builder: (context, state) => const AdminRedemptionsScreen()),
      GoRoute(path: '/admin/reviews', builder: (context, state) => const AdminReviewsScreen()),
    ],
  );
}