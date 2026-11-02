import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadhinjatra/controllers/app_state_controller.dart';
import 'package:shadhinjatra/screens/login_screen.dart';
import 'package:shadhinjatra/screens/registration_screen.dart';
import 'package:shadhinjatra/screens/live_suspend_screen.dart';
import 'package:shadhinjatra/screens/main_navigation.dart';
import 'package:shadhinjatra/screens/chat_screen.dart';
import 'package:shadhinjatra/screens/account/account_dashboard.dart';
import 'package:shadhinjatra/screens/account/notifications/notifications_screen.dart';
import 'package:shadhinjatra/screens/account/about/about_screen.dart';
import 'package:shadhinjatra/screens/account/emergency/emergency_screen.dart';
import 'package:shadhinjatra/screens/account/payment/payment_methods_screen.dart';
import 'package:shadhinjatra/screens/account/privacy/privacy_screen.dart';
import 'package:shadhinjatra/screens/account/privacy/privacy_security_screen.dart';
import 'package:shadhinjatra/screens/account/profile/profile_screen.dart';
import 'package:shadhinjatra/screens/account/profile/edit_profile_screen.dart';
import 'package:shadhinjatra/screens/account/promotions_screen.dart';
import 'package:shadhinjatra/screens/account/safety/safety_screen.dart';
import 'package:shadhinjatra/screens/account/saved_places/saved_places_screen.dart';
import 'package:shadhinjatra/screens/account/settings/settings_screen.dart';
import 'package:shadhinjatra/screens/account/support/support_screen.dart';
import 'package:shadhinjatra/screens/account/wallet/wallet_screen.dart';
import 'package:shadhinjatra/screens/account/earnings/earnings_screen.dart';
import 'package:shadhinjatra/screens/account/subscription/subscription_screen.dart';

class AuthNotifier extends ChangeNotifier {
  static final AuthNotifier instance = AuthNotifier._();
  AuthNotifier._();

  bool _isLoggedIn = false;
  bool _isSuspended = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isSuspended => _isSuspended;

  void setLoggedIn(bool value) {
    if (_isLoggedIn != value) {
      _isLoggedIn = value;
      notifyListeners();
    }
  }

  void setSuspended(bool value) {
    if (_isSuspended != value) {
      _isSuspended = value;
      notifyListeners();
    }
  }
}

class AppRouter {
  static const String home = '/';
  static const String services = '/services';
  static const String activity = '/activity';
  static const String account = '/account';
  static const String login = '/login';
  static const String register = '/register';
  static const String suspend = '/suspend';
  static const String accountDashboard = '/account-dashboard';
  static const String notifications = '/notifications';
  static const String chat = '/chat/:rideId';

  // Account nested routes
  static const String about = '/account/about';
  static const String privacy = '/account/privacy';
  static const String privacySecurity = '/account/privacy-security';
  static const String profile = '/account/profile';
  static const String editProfile = '/account/profile/edit';
  static const String wallet = '/account/wallet';
  static const String earnings = '/account/earnings';
  static const String subscription = '/account/subscription';
  static const String paymentMethods = '/account/payment-methods';
  static const String promotions = '/account/promotions';
  static const String savedPlaces = '/account/saved-places';
  static const String emergency = '/account/emergency';
  static const String safety = '/account/safety';
  static const String settings = '/account/settings';
  static const String support = '/account/support';

  static GoRouter? _router;

  static GoRouter get router => _router ?? createRouter(isLoggedIn: AuthNotifier.instance.isLoggedIn);

  static GoRouter createRouter({required bool isLoggedIn}) {
    AuthNotifier.instance._isLoggedIn = isLoggedIn;
    final appState = AppStateController.to;

    _router = GoRouter(
      refreshListenable: AuthNotifier.instance,
      initialLocation: AuthNotifier.instance.isLoggedIn
          ? (appState.isSuspended.value ? suspend : home)
          : login,
      redirect: (BuildContext context, GoRouterState state) {
        final isSuspended = AuthNotifier.instance.isSuspended || appState.isSuspended.value;
        final loggedIn = AuthNotifier.instance.isLoggedIn;
        final loc = state.matchedLocation;
        final isAuthRoute = loc == login || loc == register;

        if (isSuspended) {
          if (loc != suspend) return suspend;
          return null;
        }

        if (!loggedIn) {
          if (!isAuthRoute) return login;
          return null;
        }

        if (isAuthRoute || loc == suspend) {
          return home;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: home,
          builder: (context, state) {
            final vehicle = state.uri.queryParameters['vehicle'];
            return MainNavigation(
              initialIndex: 0,
              initialVehicleType: vehicle,
            );
          },
        ),
        GoRoute(
          path: services,
          builder: (context, state) => const MainNavigation(initialIndex: 1),
        ),
        GoRoute(
          path: activity,
          builder: (context, state) => const MainNavigation(initialIndex: 2),
        ),
        GoRoute(
          path: account,
          builder: (context, state) => const MainNavigation(initialIndex: 3),
        ),
        GoRoute(
          path: login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: register,
          builder: (context, state) => const RegistrationScreen(),
        ),
        GoRoute(
          path: suspend,
          builder: (context, state) => const LiveSuspendScreen(),
        ),
        GoRoute(
          path: accountDashboard,
          builder: (context, state) => const AccountDashboard(),
        ),
        GoRoute(
          path: notifications,
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: chat,
          builder: (context, state) {
            final rideIdStr = state.pathParameters['rideId'] ?? '0';
            final rideId = int.tryParse(rideIdStr) ?? 0;
            final otherName = (state.extra as String?) ?? 'Driver';
            return ChatScreen(
              rideId: rideId,
              otherPersonName: otherName,
            );
          },
        ),
        GoRoute(
          path: about,
          builder: (context, state) => const AboutScreen(),
        ),
        GoRoute(
          path: privacy,
          builder: (context, state) => const PrivacyScreen(),
        ),
        GoRoute(
          path: privacySecurity,
          builder: (context, state) => const PrivacySecurityScreen(),
        ),
        GoRoute(
          path: profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: editProfile,
          builder: (context, state) {
            final userData = (state.extra as Map<String, dynamic>?) ?? {};
            return EditProfileScreen(userData: userData);
          },
        ),
        GoRoute(
          path: wallet,
          builder: (context, state) => const WalletScreen(),
        ),
        GoRoute(
          path: earnings,
          builder: (context, state) => const EarningsScreen(),
        ),
        GoRoute(
          path: subscription,
          builder: (context, state) => const SubscriptionScreen(),
        ),
        GoRoute(
          path: paymentMethods,
          builder: (context, state) => const PaymentMethodsScreen(),
        ),
        GoRoute(
          path: promotions,
          builder: (context, state) => const PromotionsScreen(),
        ),
        GoRoute(
          path: savedPlaces,
          builder: (context, state) => const SavedPlacesScreen(),
        ),
        GoRoute(
          path: emergency,
          builder: (context, state) => const EmergencyScreen(),
        ),
        GoRoute(
          path: safety,
          builder: (context, state) => const SafetyScreen(),
        ),
        GoRoute(
          path: settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: support,
          builder: (context, state) => const SupportScreen(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Page Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('No route defined for ${state.matchedLocation}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(home),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );

    return _router!;
  }
}

