import '../../services/api_service.dart';
import '../../core/providers/provider_manager.dart';
import '../models/models.dart';

/// 音乐数据仓库类
/// 负责处理与音乐相关的数据操作，是API服务和业务逻辑之间的抽象层
class MusicRepository {
  final ApiService _apiService;

  MusicRepository(this._apiService);

  /// 获取用户歌单列表
  Future<Map<String, dynamic>> getUserPlaylists(
      {bool forceRefresh = false}) async {
    try {
      final response =
          await _apiService.getUserPlaylists(forceRefresh: forceRefresh);
      print('获取歌单响应: $response');
      return response;
    } catch (e) {
      print('获取歌单失败: $e');
      // 获取歌单失败时可能是Token过期，需要清除认证数据
      if (e.toString().contains('401') ||
          e.toString().contains('未授权') ||
          e.toString().contains('认证') ||
          e.toString().contains('登录')) {
        await _apiService.clearAuthData();
      }
      rethrow;
    }
  }

  /// 获取歌单内的歌曲
  Future<List<Map<String, dynamic>>> getPlaylistTracks(
    String globalCollectionId, {
    int page = 1,
    int pageSize = 30,
  }) {
    return _apiService.getPlaylistTracks(
      globalCollectionId,
      page: page,
      pageSize: pageSize,
    );
  }

  /// 获取歌曲播放地址
  Future<String> getSongUrl(String hash, String albumId) {
    return _apiService.getSongUrl(hash, albumId);
  }

  /// 获取歌词内容
  Future<String> getLyrics(String hash) {
    return _apiService.getFullLyric(hash);
  }

  /// 搜索歌曲
  Future<SearchResponse> searchSongs(String keyword,
      {int page = 1, int pageSize = 20}) {
    return _apiService.searchSongs(keyword, page: page, pageSize: pageSize);
  }

  /// 获取最近播放记录
  Future<RecentSongsResponse> getRecentSongs(
      {String? bq, bool forceRefresh = false}) {
    return _apiService.getRecentSongs(bq: bq, forceRefresh: forceRefresh);
  }
}

/// 音乐仓库提供者已移至ProviderManager.musicRepositoryProvider
@Deprecated('请使用ProviderManager.musicRepositoryProvider')
final musicRepositoryProvider = ProviderManager.musicRepositoryProvider;
