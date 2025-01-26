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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final apiService = ApiService(prefs);
  final playerService = PlayerService(apiService);

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
      ],
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => playerService),
          BlocProvider(
            create: (context) => AuthBloc(
              authService: AuthService(prefs, apiService),
            )..add(AuthCheckRequested()),
          ),
        ],
        child: MaterialApp(
          title: 'Music App',
          theme: ThemeData(
            primaryColor: const Color(0xFF2196F3),
            scaffoldBackgroundColor: Colors.white,
            brightness: Brightness.light,
          ),
          home: const MainPage(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/player': (context) => const PlayerPage(),
          },
          debugShowCheckedModeBanner: false,
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

  final List<Widget> _pages = [
    const DiscoveryTab(),
    const ProfileTab(),
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
    super.dispose();
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
          IndexedStack(
            index: _currentIndex,
            children: _pages,
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
                      onPressed: () => setState(() => _currentIndex = 0),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.person,
                        color: _currentIndex == 1
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        size: 28,
                      ),
                      onPressed: () => setState(() => _currentIndex = 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: GestureDetector(
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
                            ImageUtils.getThumbnailUrl(currentSong.cover ?? ''),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
