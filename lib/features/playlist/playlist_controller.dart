import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/provider_manager.dart';
import '../../data/models/models.dart';
import '../../data/repositories/music_repository.dart';

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
        return;
      }

      /// 检查用户是否已登录
      final isLoggedIn = _ref.read(ProviderManager.isLoggedInProvider);

      if (!isLoggedIn) {
        state = state.copyWith(
          loadState: PlaylistLoadState.error,
          errorMessage: '请先登录后查看歌单',
        );
        return;
      }

      /// 设置加载状态为 loading
      state = state.copyWith(loadState: PlaylistLoadState.loading);

      /// 调用 MusicRepository 获取用户歌单数据
      final response = await _musicRepository.getUserPlaylists(
        forceRefresh: forceRefresh,
      );

      /// 将返回的 JSON 响应转换为 PlaylistResponse 模型对象
      final playlistResponse = PlaylistResponse.fromJson(response);

      /// 更新状态为 loaded，并设置歌单数据
      state = state.copyWith(
        loadState: PlaylistLoadState.loaded,
        playlistResponse: playlistResponse,
      );
    } catch (e) {
      /// 捕获加载过程中发生的错误，并更新状态为 error，设置错误消息
      state = state.copyWith(
        loadState: PlaylistLoadState.error,
        errorMessage: e.toString(),
      );

      /// 如果错误是认证相关的，可能需要刷新登录状态
      if (e.toString().contains('401') ||
          e.toString().contains('未授权') ||
          e.toString().contains('token') ||
          e.toString().contains('登录')) {
        _ref.invalidate(ProviderManager.isLoggedInProvider);
      }
    }
  }
}
