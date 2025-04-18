import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/image_service.dart';
import '../../services/player_service.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/profile_controller.dart';
import '../../data/repositories/music_repository.dart';
import '../../features/search/search_controller.dart';
import '../../features/playlist/playlist_controller.dart';

/// Provider管理器 - 集中管理应用中的所有Provider
class ProviderManager {
  // 核心服务Provider
  static final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
    throw UnimplementedError('SharedPreferences实例需要在main.dart中初始化');
  });

  static final apiServiceProvider = Provider<ApiService>((ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ApiService(prefs);
  });

  static final imageServiceProvider = Provider<ImageService>((ref) {
    return ImageService();
  });

  static final playerServiceProvider =
      ChangeNotifierProvider<PlayerService>((ref) {
    final apiService = ref.watch(apiServiceProvider);
    return PlayerService(apiService);
  });

  // 数据仓库Provider
  static final musicRepositoryProvider = Provider<MusicRepository>((ref) {
    final apiService = ref.watch(apiServiceProvider);
    return MusicRepository(apiService);
  });

  // 认证相关Provider
  static final authControllerProvider =
      ChangeNotifierProvider<AuthController>((ref) {
    final apiService = ref.watch(apiServiceProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    return AuthController(apiService, prefs);
  });

  static final profileControllerProvider =
      StateNotifierProvider<ProfileController, ProfileState>((ref) {
    final apiService = ref.watch(apiServiceProvider);
    return ProfileController(apiService);
  });

  static final isLoggedInProvider = Provider<bool>((ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final token = prefs.getString('auth_token');
    final isLoggedIn = token != null && token.isNotEmpty;
    print('检查登录状态 - token: $token, isLoggedIn: $isLoggedIn');

    // 检查所有的 SharedPreferences 键
    final allKeys = prefs.getKeys();
    print('登录检查 - 所有存储的键: $allKeys');

    return isLoggedIn;
  });

  // 功能控制器Provider
  static final searchControllerProvider =
      StateNotifierProvider<SearchController, SearchState>((ref) {
    final apiService = ref.watch(apiServiceProvider);
    return SearchController(apiService);
  });

  static final playlistProvider =
      StateNotifierProvider<PlaylistNotifier, PlaylistState>((ref) {
    final musicRepository = ref.watch(musicRepositoryProvider);
    return PlaylistNotifier(musicRepository, ref);
  });

  /// 获取所有Provider列表，用于ProviderScope的overrides
  static List<Override> getAllOverrides(SharedPreferences sharedPreferences) {
    return [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    ];
  }
}
