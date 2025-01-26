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
          home: const MainScreen(),
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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DiscoveryTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
