import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song_cache.dart';
import '../models/play_song_info.dart';
import 'api_service.dart';

class AudioCacheManager {
  static const int maxCacheSize = 2 * 1024 * 1024 * 1024; // 2GB
  static const String _cacheInfoKey = 'audio_cache_info';

  final SharedPreferences _prefs;
  final ApiService _apiService;
  final String _cacheDir;

  static AudioCacheManager? _instance;

  // 私有构造函数
  AudioCacheManager._(this._prefs, this._apiService, this._cacheDir);

  // 单例工厂
  static Future<AudioCacheManager> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      final apiService = ApiService(prefs);
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = '${dir.path}/audio_cache';
      // 确保缓存目录存在
      await Directory(cacheDir).create(recursive: true);

      _instance = AudioCacheManager._(prefs, apiService, cacheDir);
    }
    return _instance!;
  }

  // 获取缓存路径
  Future<String?> getCachedPath(String hash) async {
    print('查询歌曲缓存状态: $hash');
    final cacheInfo = await _loadCacheInfo();
    final songInfo = cacheInfo[hash];
    if (songInfo == null) {
      print('歌曲未缓存');
      return null;
    }

    final file = File(songInfo.localPath);
    if (!file.existsSync()) {
      print('缓存文件不存在: ${songInfo.localPath}');
      // 如果文件不存在，删除缓存信息
      await _removeCacheInfo(hash);
      return null;
    }

    print('找到缓存文件: ${songInfo.localPath}');
    return songInfo.localPath;
  }

  // 缓存音频
  Future<void> cacheAudio(PlaySongInfo songInfo) async {
    try {
      print('开始缓存歌曲: ${songInfo.title}');
      // 检查是否已缓存
      if (await getCachedPath(songInfo.hash) != null) {
        print('歌曲已缓存: ${songInfo.title}');
        return;
      }

      // 获取音频URL
      final url =
          await _apiService.getSongUrl(songInfo.hash, songInfo.albumId ?? '');
      print('获取到歌曲URL: $url');

      // 获取文件大小
      final response = await http.head(Uri.parse(url));
      final fileSize = int.parse(response.headers['content-length'] ?? '0');
      print('歌曲大小: ${fileSize / 1024 / 1024}MB');

      // 确保有足够空间
      await _ensureEnoughSpace(fileSize);

      // 下载文件
      final localPath = '$_cacheDir/${songInfo.hash}.mp3';
      print('开始下载到: $localPath');
      await _downloadFile(url, localPath);
      print('下载完成');

      // 保存缓存信息
      await _saveCacheInfo(SongCache(
        hash: songInfo.hash,
        title: songInfo.title,
        artist: songInfo.artist,
        cover: songInfo.cover ?? '',
        localPath: localPath,
        size: fileSize,
        lastPlayTime: DateTime.now(),
        playCount: 1,
      ));
      print('缓存信息已保存');
    } catch (e) {
      print('缓存音频失败: $e');
      rethrow;
    }
  }

  // 更新播放信息
  Future<void> updatePlayInfo(String hash) async {
    final cacheInfo = await _loadCacheInfo();
    final songInfo = cacheInfo[hash];
    if (songInfo == null) return;

    final updatedInfo = songInfo.copyWithIncrementedPlayCount();
    await _saveCacheInfo(updatedInfo);
  }

  // 获取缓存歌曲列表
  Future<List<SongCache>> getCachedSongs() async {
    final cacheInfo = await _loadCacheInfo();
    return cacheInfo.values.toList();
  }

  // 获取缓存数量
  Future<int> getCachedCount() async {
    final cacheInfo = await _loadCacheInfo();
    return cacheInfo.length;
  }

  // 获取当前缓存大小
  Future<int> getCurrentCacheSize() async {
    final cacheInfo = await _loadCacheInfo();
    int totalSize = 0;
    for (var song in cacheInfo.values) {
      totalSize += song.size;
    }
    print('当前缓存总大小: ${totalSize / 1024 / 1024}MB');
    return totalSize;
  }

  // 清除所有缓存
  Future<void> clearAllCached() async {
    print('开始清除所有音频缓存');
    final cacheInfo = await _loadCacheInfo();

    // 删除所有缓存文件
    for (final songCache in cacheInfo.values) {
      final file = File(songCache.localPath);
      if (file.existsSync()) {
        try {
          await file.delete();
          print('删除缓存文件: ${songCache.localPath}');
        } catch (e) {
          print('删除文件失败: ${songCache.localPath}, 错误: $e');
        }
      }
    }

    // 清空缓存信息
    await _prefs.remove(_cacheInfoKey);
    print('缓存信息已清空');
  }

  // 确保有足够的缓存空间
  Future<void> _ensureEnoughSpace(int requiredSize) async {
    final currentSize = await getCurrentCacheSize();
    if (currentSize + requiredSize > maxCacheSize) {
      await _cleanupCache(requiredSize);
    }
  }

  // 清理缓存
  Future<void> _cleanupCache(int requiredSize) async {
    final songs = await getCachedSongs();
    if (songs.isEmpty) return;

    // 按播放次数和最后播放时间排序
    songs.sort((a, b) {
      if (a.playCount != b.playCount) {
        return a.playCount.compareTo(b.playCount);
      }
      return a.lastPlayTime.compareTo(b.lastPlayTime);
    });

    var freedSpace = 0;
    for (final song in songs) {
      await _deleteCachedSong(song.hash);
      freedSpace += song.size;
      if (freedSpace >= requiredSize) break;
    }
  }

  // 删除缓存的歌曲
  Future<void> _deleteCachedSong(String hash) async {
    final cacheInfo = await _loadCacheInfo();
    final songInfo = cacheInfo[hash];
    if (songInfo == null) return;

    // 删除文件
    final file = File(songInfo.localPath);
    if (file.existsSync()) {
      await file.delete();
    }

    // 删除缓存信息
    await _removeCacheInfo(hash);
  }

  // 下载文件
  Future<void> _downloadFile(String url, String savePath) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      await File(savePath).writeAsBytes(response.bodyBytes);
    } else {
      throw Exception('下载文件失败: ${response.statusCode}');
    }
  }

  // 加载缓存信息
  Future<Map<String, SongCache>> _loadCacheInfo() async {
    final jsonStr = _prefs.getString(_cacheInfoKey);
    if (jsonStr == null) return {};

    final jsonMap = json.decode(jsonStr) as Map<String, dynamic>;
    return jsonMap.map((key, value) => MapEntry(
          key,
          SongCache.fromJson(value as Map<String, dynamic>),
        ));
  }

  // 保存缓存信息
  Future<void> _saveCacheInfo(SongCache songCache) async {
    final cacheInfo = await _loadCacheInfo();
    cacheInfo[songCache.hash] = songCache;
    await _prefs.setString(_cacheInfoKey, json.encode(cacheInfo));
  }

  // 删除缓存信息
  Future<void> _removeCacheInfo(String hash) async {
    final cacheInfo = await _loadCacheInfo();
    cacheInfo.remove(hash);
    await _prefs.setString(_cacheInfoKey, json.encode(cacheInfo));
  }
}
