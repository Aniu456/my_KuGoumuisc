import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/player_service.dart';
import 'bloc/auth/auth_bloc.dart';
import 'widgets/discovery_tab.dart';
import 'widgets/profile_tab.dart';
import 'screens/login_screen.dart';
import 'pages/player_page.dart';
import 'package:provider/provider.dart';
import 'utils/image_utils.dart';

// 添加主题状态管理
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('dark_mode') ?? false;
    notifyListeners();
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDarkMode);
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final apiService = ApiService(prefs);
  final playerService = PlayerService(apiService);

  // 添加捕获全局错误的逻辑
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  runApp(MyApp(
    prefs: prefs,
    apiService: apiService,
    playerService: playerService,
  ));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  final ApiService apiService;
  final PlayerService playerService;

  const MyApp({
    super.key,
    required this.prefs,
    required this.apiService,
    required this.playerService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: apiService),
        RepositoryProvider<AuthService>(
          create: (context) => AuthService(prefs, apiService),
        ),
      ],
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => playerService),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authService: context.read<AuthService>(),
            )..add(AuthCheckRequested()),
          ),
        ],
        child:
            Consumer<ThemeProvider>(builder: (context, themeProvider, child) {
          return MaterialApp(
            title: '酷狗音乐',
            theme: ThemeData(
              primaryColor: const Color(0xFF2196F3),
              scaffoldBackgroundColor: Colors.white,
              brightness: Brightness.light,
              useMaterial3: true,
              colorScheme: ColorScheme.light(
                primary: const Color(0xFF2196F3),
                secondary: Colors.blue[300]!,
                surface: Colors.white,
              ),
            ),
            darkTheme: ThemeData(
              primaryColor: const Color(0xFF2196F3),
              scaffoldBackgroundColor: const Color(0xFF121212),
              brightness: Brightness.dark,
              useMaterial3: true,
              colorScheme: ColorScheme.dark(
                primary: const Color(0xFF2196F3),
                secondary: Colors.blue[300]!,
                surface: const Color(0xFF202020),
              ),
            ),
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const SplashScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/player': (context) => const PlayerPage(),
              '/main': (context) => const MainPage(),
            },
            debugShowCheckedModeBanner: false,
          );
        }),
      ),
    );
  }
}

// 添加启动屏幕
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToMain();
  }

  Future<void> _navigateToMain() async {
    // 模拟加载过程，2秒后跳转到主页面
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 应用图标
            Image.asset(
              'assets/images/logo.png',
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.music_note,
                size: 120,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '酷狗音乐',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _rotationController;

  // 使用PageController提高页面切换性能
  final PageController _pageController = PageController();

  // 使用AutomaticKeepAliveClientMixin保持页面状态
  final List<Widget> _pages = [
    const DiscoveryTab(key: PageStorageKey('discovery')),
    const ProfileTab(key: PageStorageKey('profile')),
  ];

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // 切换页面的方法
  void _changePage(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerService = context.watch<PlayerService>();
    final currentSong = playerService.currentSongInfo;
    final isPlaying = playerService.isPlaying;

    // 控制旋转动画
    if (isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }

    return Scaffold(
      body: Stack(
        children: [
          // 使用PageView替代IndexedStack提高性能
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // 禁用滑动
            children: _pages,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
          ),
          // 底部导航栏
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Container(
                height: 55,
                width: 260,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(27.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.home,
                        color: _currentIndex == 0
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        size: 28,
                      ),
                      onPressed: () => _changePage(0),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.person,
                        color: _currentIndex == 1
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        size: 28,
                      ),
                      onPressed: () => _changePage(1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Hero(
        tag: 'player_fab',
        child: GestureDetector(
          onTap: () {
            if (currentSong != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlayerPage()),
              );
            }
          },
          child: Container(
            width: 75,
            height: 75,
            margin: const EdgeInsets.only(bottom: 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue[300]!,
                  Colors.blue[600]!,
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: currentSong != null
                ? Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 4,
                      ),
                    ),
                    child: RotationTransition(
                      turns: _rotationController,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(35),
                        child: Stack(
                          children: [
                            Image.network(
                              ImageUtils.getThumbnailUrl(
                                  currentSong.cover ?? ''),
                              width: 75,
                              height: 75,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.music_note,
                                    color: Colors.white, size: 35),
                              ),
                            ),
                            // 添加渐变遮罩
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.2),
                                    Colors.black.withOpacity(0),
                                    Colors.black.withOpacity(0.2),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.music_note,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
