import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/models.dart';
import '../../services/api_service.dart';
import '../../services/image_service.dart';
import '../../services/player_service.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/profile_controller.dart';
import '../../data/repositories/music_repository.dart';
import '../../features/search/search_controller.dart';

// 便于外部直接引用
final apiServiceProvider = Provider<ApiService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ApiService(prefs);
});

/// Provider管理器
/// 集中管理应用中的所有Provider
class ProviderManager {
  /// 核心服务Provider组
  static final coreProviders = [
    /// SharedPreferences Provider
    Provider<SharedPreferences>((ref) {
      throw UnimplementedError('SharedPreferences实例需要在main.dart中初始化');
    }),

    /// ApiService Provider
    Provider<ApiService>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return ApiService(prefs);
    }),

    /// ImageService Provider
    Provider<ImageService>((ref) {
      return ImageService();
    }),

    /// PlayerService Provider
    ChangeNotifierProvider<PlayerService>((ref) {
      final apiService = ref.watch(apiServiceProvider);
      return PlayerService(apiService);
    }),
  ];

  /// 认证相关Provider组
  static final authProviders = [
    /// AuthController Provider
    ChangeNotifierProvider<AuthController>((ref) {
      final apiService = ref.watch(apiServiceProvider);
      final prefs = ref.watch(sharedPreferencesProvider);
      return AuthController(apiService, prefs);
    }),

    /// ProfileController Provider
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
      final apiService = ref.watch(apiServiceProvider);
      return ProfileController(apiService);
    }),

    /// 登录状态Provider
    Provider<bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      final token = prefs.getString('auth_token');
      return token != null && token.isNotEmpty;
    }),
  ];

  /// 数据仓库Provider组
  static final repositoryProviders = [
    /// MusicRepository Provider
    Provider<MusicRepository>((ref) {
      final apiService = ref.watch(apiServiceProvider);
      return MusicRepository(apiService);
    }),
  ];

  /// 功能控制器Provider组
  static final controllerProviders = [
    /// SearchController Provider
    StateNotifierProvider<SearchController, SearchState>((ref) {
      final apiService = ref.watch(apiServiceProvider);
      return SearchController(apiService);
    }),

    /// PlaylistNotifier Provider
    StateNotifierProvider<PlaylistNotifier, PlaylistState>((ref) {
      final musicRepository = ref.watch(musicRepositoryProvider);
      return PlaylistNotifier(musicRepository, ref);
    }),
  ];

  /// 获取所有Provider列表，用于ProviderScope的overrides
  static List<Override> getAllOverrides(SharedPreferences sharedPreferences) {
    return [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    ];
  }

  // Provider引用常量，方便在应用中直接使用

  /// SharedPreferences Provider引用
  static final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
    throw UnimplementedError('SharedPreferences实例需要在main.dart中初始化');
  });

  /// ApiService Provider引用
  static final apiServiceProvider = Provider<ApiService>((ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ApiService(prefs);
  });

  /// ImageService Provider引用
  static final imageServiceProvider = Provider<ImageService>((ref) {
    return ImageService();
  });

  /// PlayerService Provider引用
  static final playerServiceProvider =
      ChangeNotifierProvider<PlayerService>((ref) {
    final apiService = ref.watch(apiServiceProvider);
    return PlayerService(apiService);
  });

  /// AuthController Provider引用
  static final authControllerProvider =
      ChangeNotifierProvider<AuthController>((ref) {
    final apiService = ref.watch(apiServiceProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    return AuthController(apiService, prefs);
  });

  /// ProfileController Provider引用
  static final profileControllerProvider =
      StateNotifierProvider<ProfileController, ProfileState>((ref) {
    final apiService = ref.watch(apiServiceProvider);
    return ProfileController(apiService);
  });

  /// 登录状态Provider引用
  static final isLoggedInProvider = Provider<bool>((ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final token = prefs.getString('auth_token');
    return token != null && token.isNotEmpty;
  });

  /// MusicRepository Provider引用
  static final musicRepositoryProvider = Provider<MusicRepository>((ref) {
    final apiService = ref.watch(apiServiceProvider);
    return MusicRepository(apiService);
  });

  /// SearchController Provider引用
  static final searchControllerProvider =
      StateNotifierProvider<SearchController, SearchState>((ref) {
    final musicRepository = ref.watch(musicRepositoryProvider);
    return SearchController(musicRepository);
  });

  /// PlaylistNotifier Provider引用
  static final playlistProvider =
      StateNotifierProvider<PlaylistNotifier, PlaylistState>((ref) {
    final musicRepository = ref.watch(musicRepositoryProvider);
    return PlaylistNotifier(musicRepository, ref);
  });
}

/// 歌单加载状态
enum PlaylistLoadState {
  /// 初始状态，尚未开始加载
  initial,

  /// 加载中状态
  loading,

  /// 加载成功状态
  loaded,

  /// 加载失败状态
  error,
}

/// 歌单状态类
class PlaylistState {
  /// 当前歌单的加载状态
  final PlaylistLoadState loadState;

  /// 包含歌单数据的响应模型，可能为空
  final PlaylistResponse? playlistResponse;

  /// 加载过程中出现的错误消息，可能为空
  final String? errorMessage;

  /// 构造函数，初始化歌单状态
  PlaylistState({
    this.loadState = PlaylistLoadState.initial,
    this.playlistResponse,
    this.errorMessage,
  });

  /// 复制当前状态并允许修改部分属性
  PlaylistState copyWith({
    PlaylistLoadState? loadState,
    PlaylistResponse? playlistResponse,
    String? errorMessage,
  }) {
    return PlaylistState(
      loadState: loadState ?? this.loadState,
      playlistResponse: playlistResponse ?? this.playlistResponse,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// 是否正在加载歌单数据
  bool get isLoading => loadState == PlaylistLoadState.loading;

  /// 加载歌单数据是否发生错误
  bool get hasError => loadState == PlaylistLoadState.error;

  /// 歌单数据是否加载成功
  bool get isLoaded => loadState == PlaylistLoadState.loaded;
}

/// 歌单状态提供者
class PlaylistNotifier extends StateNotifier<PlaylistState> {
  /// 注入 MusicRepository 实例，用于获取音乐数据
  final MusicRepository _musicRepository;
  final Ref _ref;

  /// 构造函数，接收 MusicRepository 实例并初始化状态
  PlaylistNotifier(this._musicRepository, this._ref) : super(PlaylistState());

  /// 加载用户歌单
  /// @param forceRefresh 是否强制刷新数据，默认为 false
  Future<void> loadUserPlaylists({bool forceRefresh = false}) async {
    try {
      /// 如果当前正在加载，则直接返回，防止重复加载
      if (state.isLoading) {
        print('歌单已在加载中，跳过重复请求');
        return;
      }

      /// 检查用户是否已登录
      final isLoggedIn = _ref.read(ProviderManager.isLoggedInProvider);
      print('加载歌单: 用户登录状态 = $isLoggedIn');

      if (!isLoggedIn) {
        print('用户未登录，无法加载歌单');
        state = state.copyWith(
          loadState: PlaylistLoadState.error,
          errorMessage: '请先登录后查看歌单',
        );
        return;
      }

      /// 设置加载状态为 loading
      print('开始加载歌单...');
      state = state.copyWith(loadState: PlaylistLoadState.loading);

      /// 调用 MusicRepository 获取用户歌单数据
      final response = await _musicRepository.getUserPlaylists(
        forceRefresh: forceRefresh,
      );

      print('成功获取歌单数据: ${response.runtimeType}');

      /// 将返回的 JSON 响应转换为 PlaylistResponse 模型对象
      final playlistResponse = PlaylistResponse.fromJson(response);
      print('成功解析歌单: 创建的歌单 ${playlistResponse.createdPlaylists.length} 个, '
          '收藏的歌单 ${playlistResponse.collectedPlaylists.length} 个');

      /// 更新状态为 loaded，并设置歌单数据
      state = state.copyWith(
        loadState: PlaylistLoadState.loaded,
        playlistResponse: playlistResponse,
      );
      print('歌单加载完成');
    } catch (e) {
      /// 捕获加载过程中发生的错误，并更新状态为 error，设置错误消息
      print('加载歌单出现错误: $e');
      state = state.copyWith(
        loadState: PlaylistLoadState.error,
        errorMessage: e.toString(),
      );

      /// 如果错误是认证相关的，可能需要刷新登录状态
      if (e.toString().contains('401') ||
          e.toString().contains('未授权') ||
          e.toString().contains('token') ||
          e.toString().contains('登录')) {
        print('检测到认证错误，刷新登录状态');
        _ref.invalidate(ProviderManager.isLoggedInProvider);
      }
    }
  }
}
