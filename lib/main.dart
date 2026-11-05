import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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

// --- ADMIN ROUTES (PASTIKAN IMPORT INI ADA) ---
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


// ✅ TAMBAHKAN FUNGSI INI DI BAGIAN PALING ATAS FILE (Di luar class MyApp)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🔔 [FCM] Handling a background message: ${message.messageId}");
}

const String supabaseUrl = 'https://qitxjhavagqhfnkmmiyw.supabase.co';
const String supabaseAnonKey = 'sb_publishable_Xmw5kGeXzCLMQG871sRQPA_B72M137t';

// ✅ GLOBAL ROUTE OBSERVER
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  // 1. Wajib ada di paling atas
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ PERBAIKAN: Hanya inisialisasi Firebase jika TIDAK berjalan di Web (PWA)
  if (!kIsWeb) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    print('🔥 [MAIN] Firebase initialized for Mobile.');
  } else {
    print('🌐 [MAIN] Running on Web/PWA. Skipping Firebase native init.');
  }

  // 2. Load .env dengan aman (Mencegah crash jika file .env hilang/bermasalah)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print('⚠️ [MAIN] Gagal memuat .env, melanjutkan tanpa env: $e');
  }

  final uri = Uri.base;
  final isPasswordRecovery =
      uri.queryParameters.containsKey('code') ||
      uri.fragment.contains('type=recovery') ||
      uri.fragment.contains('access_token');

  // 3. Inisialisasi Supabase
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  // 4. Inisialisasi AuthService dengan AMAN (Mencegah crash fatal saat startup)
  try {
    await AuthService.initialize();
  } catch (e) {
    print('⚠️ [MAIN] AuthService.initialize gagal, aplikasi tetap berjalan sebagai Guest: $e');
  }

  // 5. Jalankan Aplikasi
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

      bool isAdmin = false;
      try {
        isAdmin = AuthService.isAdmin;
      } catch (e) {
        isAdmin = false;
      }

      // 1. Biarkan reset password lewat
      if (path == '/reset-password') return null;

      // 2. Jika BELUM login
      if (!isLoggedIn) {
        if (path.startsWith('/admin')) return '/login';

        if (path == '/' ||
            path == '/login' ||
            path == '/register' ||
            path == '/forgot-password' ||
            path == '/cart' ||
            path.startsWith('/property') ||
            path.startsWith('/spa') ||
            path.startsWith('/wedding') ||
            path.startsWith('/restaurant')) {
          return null;
        }
        return '/login';
      }

      // 3. Jika SUDAH login
      if (isLoggedIn) {
        // ✅ ANTI-LOOP: Cegah user yang sudah login membuka halaman login lagi
        if (path == '/login' ||
            path == '/register' ||
            path == '/forgot-password') {
          final target = isAdmin ? '/admin/dashboard' : '/';
          // PENTING: Hanya redirect jika path saat ini BUKAN targetnya
          if (path != target) return target;
        }

        // ✅ ANTI-LOOP: Cegah user BIASA masuk ke area admin
        if (!isAdmin && path.startsWith('/admin')) {
          if (path != '/') return '/';
        }

        // ✅ ANTI-LOOP: Jika Admin membuka halaman utama, arahkan ke Dashboard
        if (isAdmin && path == '/') {
          if (path != '/admin/dashboard') return '/admin/dashboard';
        }
      }

      // 4. Izinkan akses normal
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
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // --- USER APP ROUTES ---
      GoRoute(path: '/', builder: (context, state) => const MainShell()),
      GoRoute(
        path: '/properties',
        builder: (context, state) => const PropertiesScreen(),
      ),
      GoRoute(
        path: '/property/:id',
        builder: (context, state) =>
            PropertyDetailScreen(propertyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/offers',
        builder: (context, state) => const OffersScreen(),
      ),
      GoRoute(path: '/spa', builder: (context, state) => const SpaScreen()),
      GoRoute(
        path: '/spa/:id',
        builder: (context, state) =>
            SpaDetailScreen(serviceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/restaurant/:id',
        builder: (context, state) =>
            DiningDetailScreen(restaurantId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/wedding',
        builder: (context, state) => const WeddingScreen(),
      ),
      GoRoute(
        path: '/wedding/:id',
        builder: (context, state) =>
            WeddingDetailScreen(packageId: state.pathParameters['id']!),
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
        builder: (context, state) =>
            ReservationDetailScreen(reservationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/my-favorites',
        builder: (context, state) => const MyFavoritesScreen(),
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/booking-confirmation',
        builder: (context, state) =>
            BookingConfirmationScreen(order: state.extra as Order),
      ),
      GoRoute(
        path: '/my-bookings',
        builder: (context, state) => const MyBookingsScreen(),
      ),
      GoRoute(
        path: '/booking-detail/:id',
        builder: (context, state) =>
            OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/reservation-form',
        builder: (context, state) => ReservationFormScreen(
          bookingData: state.extra as Map<String, dynamic>,
        ),
      ),
      GoRoute(
        path: '/payment-instruction/:id',
        builder: (context, state) => PaymentInstructionScreen(
          reservationId: state.pathParameters['id']!,
        ),
      ),

      // --- ADMIN ROUTES (PASTIKAN BAGIAN INI ADA) ---
      GoRoute(
        path: '/admin/dashboard', // ✅ INI KUNCINYA
        builder: (context, state) {
          if (!AuthService.isAdmin) return const LoginScreen(); // Fallback aman
          return const AdminDashboardScreen();
        },
      ),
      GoRoute(
        path: '/admin/properties',
        builder: (context, state) => const AdminPropertiesScreen(),
      ),
      GoRoute(
        path: '/admin/rooms',
        builder: (context, state) => AdminRoomsScreen(
          propertyId: state.uri.queryParameters['propertyId'] ?? '',
          propertyName: state.uri.queryParameters['propertyName'] ?? 'Property',
        ),
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
        builder: (context, state) => AdminMenuItemsScreen(
          restaurantId: state.uri.queryParameters['restaurantId'] ?? '',
          restaurantName:
              state.uri.queryParameters['restaurantName'] ?? 'Restaurant',
        ),
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
        builder: (context, state) =>
            AdminBookingDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/admin/reservations',
        builder: (context, state) => const AdminReservationsScreen(),
      ),
      GoRoute(
        path: '/admin/reservation-detail/:id',
        builder: (context, state) => AdminReservationDetailScreen(
          reservationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/admin/promotions',
        builder: (context, state) => const AdminPromotionsScreen(),
      ),
      GoRoute(
        path: '/admin/payment-verification',
        builder: (context, state) => const AdminPaymentVerificationScreen(),
      ),
      GoRoute(
        path: '/admin/rewards',
        builder: (context, state) => const AdminRewardsScreen(),
      ),
      GoRoute(
        path: '/admin/add-reward',
        builder: (context, state) =>
            AdminAddRewardScreen(rewardToEdit: state.extra as Reward?),
      ),
      GoRoute(
        path: '/admin/redemptions',
        builder: (context, state) => const AdminRedemptionsScreen(),
      ),
      GoRoute(
        path: '/admin/reviews',
        builder: (context, state) => const AdminReviewsScreen(),
      ),
    ],
  );
}
