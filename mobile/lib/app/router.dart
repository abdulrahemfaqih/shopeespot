import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/session_state.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionStateProvider);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MapScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    redirect: (context, state) {
      // Do not redirect while initial session check is in flight
      if (session.status == SessionStatus.initial) {
        return null;
      }

      final isLoggingIn = state.matchedLocation == '/login';

      if (session.status == SessionStatus.unauthenticated && !isLoggingIn) {
        return '/login';
      }

      if (session.status == SessionStatus.authenticated && isLoggingIn) {
        return '/';
      }

      return null;
    },
  );
});
