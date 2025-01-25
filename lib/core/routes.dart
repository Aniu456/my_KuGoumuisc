import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../screens/home_screen.dart';
import '../pages/player_page.dart';
import '../screens/login_screen.dart';
import '../screens/phone_login_screen.dart';
import '../screens/account_login_screen.dart';
import '../screens/splash_screen.dart';

final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/login/phone',
      builder: (BuildContext context, GoRouterState state) {
        return const PhoneLoginScreen();
      },
    ),
    GoRoute(
      path: '/login/account',
      builder: (BuildContext context, GoRouterState state) {
        return const AccountLoginScreen();
      },
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/player',
      builder: (BuildContext context, GoRouterState state) {
        return const PlayerPage();
      },
    ),
  ],
  redirect: (context, state) {
    final authState = context.read<AuthBloc>().state;
    final isAuthenticated = authState is AuthAuthenticated;
    final isSplash = state.matchedLocation == '/splash';
    final isLoggingIn = state.matchedLocation == '/login';

    // 在Splash页面时，等待认证状态检查
    if (isSplash) {
      return null;
    }

    // 如果已登录，重定向到主页
    if (isAuthenticated) {
      return isLoggingIn ? '/' : null;
    }

    // 如果未登录，重定向到登录页
    return isLoggingIn ? null : '/login';
  },
);

class AppRoutes {
  static const String login = '/login';
  static const String phoneLogin = '/login/phone';
  static const String accountLogin = '/login/account';
  static const String home = '/';
  static const String player = '/player';
}
