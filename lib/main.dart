import 'package:flutter/material.dart'; // 导入 Flutter 提供的 Material UI 库，包含了构建用户界面的基本组件和主题。
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 导入 Riverpod 状态管理库，用于在应用程序中管理和共享状态。
import 'package:shared_preferences/shared_preferences.dart'; // 导入 shared_preferences 插件，用于在本地存储简单的键值对数据。
import 'core/theme/app_theme.dart'; // 导入自定义的应用主题配置，包括亮色和暗色主题。
import 'core/navigation/app_router.dart'; // 导入自定义的路由配置，用于管理应用程序的导航。
import 'core/providers/provider_manager.dart'; // 导入Provider管理器

void main() async {
  // 定义应用程序的入口函数 main，使用 async 表明这是一个异步函数。
  WidgetsFlutterBinding
      .ensureInitialized(); // 确保 Flutter 框架的 Widgets 绑定已经初始化，这在执行平台相关的操作（如 shared_preferences）之前是必需的。

  // 初始化 SharedPreferences
  final sharedPreferences = await SharedPreferences
      .getInstance(); // 异步地获取 SharedPreferences 的实例，用于本地数据存储。

  runApp(
    ProviderScope(
      // ProviderScope 是 Riverpod 的根 Widget，它使得应用程序中的其他 Widget 可以访问 Riverpod 的 Provider。
      overrides: [
        // 使用Provider管理器统一管理override
        ...ProviderManager.getAllOverrides(sharedPreferences),
      ],
      child:
          const MyApp(), // MyApp 是应用程序的主要 Widget。使用 const 表明这个 Widget 是不可变的，可以提高性能。
    ),
  );
}

class MyApp extends ConsumerWidget {
  // 定义应用程序的主要 Widget MyApp，它继承自 ConsumerWidget，这意味着它可以监听 Riverpod 的 Provider。
  const MyApp(
      {super.key}); // MyApp 的构造函数，接收一个可选的 key 参数，用于标识 Widget 在 Widget 树中的位置。super.key 将 key 传递给父类 StatelessWidget 的构造函数。

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 重写 build 方法，它是 ConsumerWidget 的核心，用于构建 Widget 的 UI。它接收 BuildContext 和 WidgetRef 参数，WidgetRef 用于与 Riverpod 的 Provider 交互。
    // 使用提供者获取路由配置
    final router = ref.watch(
        appRouterProvider); // 使用 ref.watch 监听 appRouterProvider，当 appRouterProvider 的值发生变化时，会重新构建当前 Widget。这里获取的是应用程序的路由配置。

    return MaterialApp.router(
      // 返回一个 MaterialApp.router Widget，它是使用 Router 进行导航的 MaterialApp。
      title: '音乐播放器', // 设置应用程序的标题，通常在任务管理器或最近使用的应用程序列表中显示。
      theme: AppTheme.lightTheme, // 设置应用程序的默认亮色主题，从自定义的 AppTheme 中获取。
      darkTheme: AppTheme.darkTheme, // 设置应用程序的暗色主题，从自定义的 AppTheme 中获取。
      themeMode: ThemeMode.system, // 设置应用程序的主题模式为系统模式，即跟随设备的系统主题设置。
      routerConfig: router, // 将之前获取的路由配置应用到 MaterialApp.router。
      debugShowCheckedModeBanner: false, // 设置是否显示右上角的调试模式标签，这里设置为 false 不显示。
    );
  }
}
