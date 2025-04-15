import 'package:flutter/material.dart'; // 导入 Flutter UI 库。
import 'package:go_router/go_router.dart'; // 导入 GoRouter 库，用于声明式导航。
import '../../screens/login_screen.dart'; // 导入登录页面。
import '../../screens/phone_login_screen.dart'; // 导入手机号登录页面。
import '../../screens/home_screen.dart'; // 导入应用主页。
import '../../shared/widgets/music_list_screen.dart'; // 导入音乐列表页面。
import '../../shared/widgets/player_page.dart'; // 导入播放器页面。
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 导入 Riverpod 状态管理库。
import '../providers/provider_manager.dart'; // 导入 Provider 管理器

/// 应用路由配置
final appRouterProvider = Provider<GoRouter>((ref) {
  // 定义一个 Riverpod Provider，用于提供 GoRouter 实例。
  final isLoggedIn = ref.watch(
      ProviderManager.isLoggedInProvider); // 监听 isLoggedInProvider，获取用户的登录状态。

  return GoRouter(
    // 返回一个 GoRouter 实例，用于配置应用的导航。
    initialLocation: isLoggedIn
        ? '/home'
        : '/login', // 根据登录状态设置应用的初始路由，已登录跳转到 '/home'，未登录跳转到 '/login'。
    debugLogDiagnostics: true, // 启用调试日志，帮助排查路由问题
    redirect: (context, state) {
      // 定义路由重定向逻辑。
      // 检查用户是否已登录，未登录用户只能访问登录相关页面
      final path = state.uri.toString();
      if (!isLoggedIn && !path.startsWith('/login') && path != '/phone-login') {
        // 如果用户未登录且当前访问的不是登录相关的页面。
        return '/login'; // 则重定向到登录页面。
      }

      // 已登录用户不能访问登录页面
      if (isLoggedIn && (path == '/login' || path == '/phone-login')) {
        // 如果用户已登录且当前访问的是登录页面。
        return '/home'; // 则重定向到主页。
      }
      return null; // 没有重定向。
    },
    routes: [
      // 定义应用的路由列表。
      GoRoute(
        // 定义一个路由。
        path: '/login', // 路由路径为 '/login'。
        builder: (context, state) =>
            const LoginScreen(), // 当导航到此路径时，构建 LoginScreen Widget。
      ),
      GoRoute(
        // 定义另一个路由。
        path: '/phone-login', // 路由路径为 '/phone-login'。
        builder: (context, state) =>
            const PhoneLoginScreen(), // 当导航到此路径时，构建 PhoneLoginScreen Widget。
      ),
      GoRoute(
        // 定义主页路由。
        path: '/home', // 路由路径为 '/home'。
        builder: (context, state) =>
            HomeScreen(), // 当导航到此路径时，构建 HomeScreen Widget。
      ),
      GoRoute(
        // 定义音乐列表路由。
        path: '/music_list', // 路由路径为 '/music_list'。
        builder: (context, state) {
          // 当导航到此路径时，构建 MusicListScreen Widget，并接收参数。
          final args = state.extra as Map<String, dynamic>? ??
              {}; // 从路由状态中获取额外参数，如果为空则使用空 Map。
          return MusicListScreen(
            // 构建音乐列表页面，并传递参数。
            title: args['playlistName'] ?? '播放列表', // 播放列表标题，如果参数中没有则使用默认值。
            playlistId: args['playlistId']?.toString(), // 播放列表 ID。
          );
        },
      ),
      GoRoute(
        // 定义播放器页面路由
        path: '/player',
        name: 'player',
        builder: (context, state) {
          return const PlayerPage();
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      // 定义当导航发生错误时的处理页面。
      body: Center(
        // 居中显示。
        child: Text('路径不存在: ${state.uri.toString()}'), // 显示错误的路径。
      ),
    ),
  );
});
