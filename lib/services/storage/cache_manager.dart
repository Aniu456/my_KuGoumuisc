import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/play_song_info.dart';

/// 缓存类型枚举
enum CacheType {
  playlist, // 歌单缓存
  song, // 歌曲缓存
  songUrl, // 歌曲URL缓存
  lyric, // 歌词缓存
  userData, // 用户数据缓存
  searchResult // 搜索结果缓存
}

/// 缓存管理器
/// 负责处理应用中的数据缓存，包括存储、检索、验证和刷新
class CacheManager {
  /// 默认缓存过期时间
  static const Duration defaultExpiration = Duration(minutes: 30);

  /// 最大重试次数
  static const int defaultMaxRetries = 3;

  /// SharedPreferences实例，用于本地数据存储
  final SharedPreferences _prefs;

  /// 构造函数
  /// @param _prefs SharedPreferences实例
  CacheManager(this._prefs);

  /// 根据不同类型生成缓存键
  String generateCacheKey(CacheType type, String id) {
    switch (type) {
      case CacheType.playlist:
        return 'playlist_$id';
      case CacheType.song:
        return 'song_$id';
      case CacheType.songUrl:
        return 'song_url_$id';
      case CacheType.lyric:
        return 'lyric_$id';
      case CacheType.userData:
        return 'user_data_$id';
      case CacheType.searchResult:
        return 'search_$id';
    }
  }

  /// 获取不同类型缓存的过期时间
  Duration getCacheExpiration(CacheType type) {
    switch (type) {
      case CacheType.playlist:
        return const Duration(hours: 6);
      case CacheType.song:
        return const Duration(days: 7);
      case CacheType.songUrl:
        return const Duration(hours: 2);
      case CacheType.lyric:
        return const Duration(days: 30);
      case CacheType.userData:
        return const Duration(days: 1);
      case CacheType.searchResult:
        return const Duration(hours: 1);
    }
  }

  /// 获取有效的缓存数据
  /// @param key 缓存键名
  /// @param expiration 过期时间，默认为defaultExpiration
  /// @return 如果缓存有效，返回缓存的数据；否则返回null
  Map<String, dynamic>? getValidCache(String key, {Duration? expiration}) {
    try {
      final cachedString = _prefs.getString(key);
      if (cachedString != null) {
        final cached = json.decode(cachedString);
        final timestamp = cached['timestamp'] ?? 0;
        final expirationDuration = expiration ?? defaultExpiration;

        // 检查缓存是否过期
        if (DateTime.now().millisecondsSinceEpoch - timestamp <
            expirationDuration.inMilliseconds) {
          if (cached['data'] != null) {
            return cached['data']; // 直接返回原始响应数据
          }
        }
      }
    } catch (e) {
      print('读取缓存失败: $e');
    }
    return null;
  }

  /// 缓存歌曲信息
  Future<void> cacheSong(String hash, Map<String, dynamic> songData) async {
    final key = generateCacheKey(CacheType.song, hash);
    await updateCache(key, {
      'data': songData,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 获取缓存的歌曲信息
  Map<String, dynamic>? getCachedSong(String hash) {
    final key = generateCacheKey(CacheType.song, hash);
    return getValidCache(key, expiration: getCacheExpiration(CacheType.song));
  }

  /// 缓存歌单信息
  Future<void> cachePlaylist(
      String playlistId, List<Map<String, dynamic>> tracks) async {
    final key = generateCacheKey(CacheType.playlist, playlistId);
    await updateCache(key, {
      'data': {'tracks': tracks},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 获取缓存的歌单信息
  List<Map<String, dynamic>>? getCachedPlaylist(String playlistId) {
    final key = generateCacheKey(CacheType.playlist, playlistId);
    final cache =
        getValidCache(key, expiration: getCacheExpiration(CacheType.playlist));
    if (cache != null && cache['tracks'] is List) {
      return List<Map<String, dynamic>>.from(cache['tracks']);
    }
    return null;
  }

  /// 缓存歌曲URL
  Future<void> cacheSongUrl(String hash, String url) async {
    final key = generateCacheKey(CacheType.songUrl, hash);
    await updateCache(key, {
      'data': {'url': url},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 获取缓存的歌曲URL
  String? getCachedSongUrl(String hash) {
    final key = generateCacheKey(CacheType.songUrl, hash);
    final cache =
        getValidCache(key, expiration: getCacheExpiration(CacheType.songUrl));
    return cache?['url'] as String?;
  }

  /// 缓存歌词
  Future<void> cacheLyric(String hash, String lyric) async {
    final key = generateCacheKey(CacheType.lyric, hash);
    await updateCache(key, {
      'data': {'lyric': lyric},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 获取缓存的歌词
  String? getCachedLyric(String hash) {
    final key = generateCacheKey(CacheType.lyric, hash);
    final cache =
        getValidCache(key, expiration: getCacheExpiration(CacheType.lyric));
    return cache?['lyric'] as String?;
  }

  /// 更新缓存
  /// @param key 缓存键名
  /// @param data 要缓存的数据，应包含'data'字段
  /// @return 更新缓存的Future
  Future<void> updateCache(String key, Map<String, dynamic> data) async {
    try {
      // 确保数据中包含时间戳
      if (!data.containsKey('timestamp')) {
        data['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      }

      final String jsonData = json.encode(data);
      await _prefs.setString(key, jsonData);
    } catch (e) {
      print('更新缓存失败: $e');
    }
  }

  /// 在后台刷新缓存
  /// @param key 缓存键名
  /// @param fetchData 获取新数据的函数
  /// @param maxRetries 最大重试次数，默认为defaultMaxRetries
  /// @return 刷新操作的Future
  Future<void> refreshInBackground(
      String key, Future<dynamic> Function() fetchData,
      {int maxRetries = defaultMaxRetries}) async {
    Future.delayed(Duration.zero, () async {
      int retryCount = 0;
      while (retryCount < maxRetries) {
        try {
          final result = await fetchData();
          if (result != null) {
            // 如果操作成功，退出循环
            print('后台刷新缓存成功: $key');
            break;
          }
          // 如果结果为null，增加重试次数
          retryCount++;
        } catch (e) {
          retryCount++;
          if (retryCount >= maxRetries) {
            print('后台刷新缓存失败 ($retryCount/$maxRetries): $e');
            break;
          }
          // 等待一段时间后重试，使用指数退避策略
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      }
    });
  }

  /// 检查缓存是否有效
  /// @param cache 缓存数据
  /// @param expiration 过期时间，默认为defaultExpiration
  /// @return 缓存是否有效
  bool isValid(Map<String, dynamic>? cache, {Duration? expiration}) {
    if (cache == null) return false;
    final timestamp = cache['timestamp'] ?? 0;
    final expirationDuration = expiration ?? defaultExpiration;
    return DateTime.now().millisecondsSinceEpoch - timestamp <
        expirationDuration.inMilliseconds;
  }

  /// 获取多个缓存的状态
  /// @param keys 要检查的缓存键名列表
  /// @return 包含每个缓存状态的Map
  Future<Map<String, dynamic>> getStatus(List<String> keys) async {
    final result = <String, dynamic>{};

    try {
      for (final key in keys) {
        final cacheStr = _prefs.getString(key);
        final cache = cacheStr != null ? json.decode(cacheStr) : null;

        result[key] = {
          'hasCache': cache != null,
          'timestamp': cache?['timestamp'],
          'isValid': isValid(cache),
        };
      }
    } catch (e) {
      print('获取缓存状态失败: $e');
    }

    return result;
  }

  /// 清除指定缓存
  /// @param key 要清除的缓存键名
  /// @return 清除操作的Future
  Future<void> clear(String key) async {
    await _prefs.remove(key);
  }

  /// 清除过期缓存
  /// @param keys 要检查的缓存键名列表
  /// @param expiration 过期时间，默认为defaultExpiration
  /// @return 清除操作的Future
  Future<void> clearExpired(List<String> keys, {Duration? expiration}) async {
    for (final key in keys) {
      final cacheStr = _prefs.getString(key);
      if (cacheStr != null) {
        try {
          final cache = json.decode(cacheStr);
          if (!isValid(cache, expiration: expiration)) {
            await clear(key);
          }
        } catch (e) {
          // 如果解析失败，也清除这个缓存
          await clear(key);
        }
      }
    }
  }

  /// 清除特定类型的所有缓存
  Future<void> clearCacheByType(CacheType type) async {
    final keys = await _getAllCacheKeys();
    final prefix = type.toString().split('.').last + '_';

    for (final key in keys) {
      if (key.startsWith(prefix)) {
        await clear(key);
      }
    }
  }

  /// 获取所有缓存键
  Future<List<String>> _getAllCacheKeys() async {
    return _prefs
        .getKeys()
        .where((key) =>
            key.startsWith('playlist_') ||
            key.startsWith('song_') ||
            key.startsWith('song_url_') ||
            key.startsWith('lyric_') ||
            key.startsWith('user_data_') ||
            key.startsWith('search_'))
        .toList();
  }

  /// 获取所有缓存的歌曲信息
  /// 返回所有缓存的歌曲对象列表
  Future<List<PlaySongInfo>> getAllCachedSongs() async {
    final List<PlaySongInfo> result = [];
    final keys = await _getAllCacheKeys();

    print('开始获取缓存歌曲，总键数: ${keys.length}');

    // 筛选出所有歌曲相关的缓存键
    final songKeys = keys.where((key) =>
        key.startsWith('song_') ||
        key.startsWith('song_url_') ||
        key.startsWith('lyric_'))
        .toList();

    print('找到歌曲相关缓存键: ${songKeys.length}');

    // 收集所有歌曲hash
    final Set<String> songHashes = {};

    // 从所有类型的缓存中提取hash
    for (final key in songKeys) {
      String hash = '';
      if (key.startsWith('song_')) {
        hash = key.substring(5); // 移除'song_'前缀
      } else if (key.startsWith('song_url_')) {
        hash = key.substring(9); // 移除'song_url_'前缀
      } else if (key.startsWith('lyric_')) {
        hash = key.substring(6); // 移除'lyric_'前缀
      }

      if (hash.isNotEmpty) {
        songHashes.add(hash);
      }
    }

    print('找到不同的歌曲hash数: ${songHashes.length}');

    // 遍历所有hash，尝试构建PlaySongInfo对象
    for (final hash in songHashes) {
      try {
        // 尝试从歌曲详情缓存中获取信息
        final songKey = generateCacheKey(CacheType.song, hash);
        final songData = getValidCache(songKey, expiration: getCacheExpiration(CacheType.song));

        // 优先使用歌曲详情缓存，如果不存在，也尝试创建基础信息
        if (songData != null) {
          // 尝试不同的数据结构模式
          Map<String, dynamic> songInfo;
          if (songData['info'] != null) {
            songInfo = Map<String, dynamic>.from(songData['info']);
          } else if (songData['data'] != null && songData['data']['info'] != null) {
            songInfo = Map<String, dynamic>.from(songData['data']['info']);
          } else if (songData['data'] != null && songData['data'] is Map) {
            songInfo = Map<String, dynamic>.from(songData['data']);
          } else {
            songInfo = Map<String, dynamic>.from(songData);
          }

          // 尝试不同的字段名称
          final title = songInfo['songname'] ??
                        songInfo['song_name'] ??
                        songInfo['filename'] ??
                        songInfo['name'] ??
                        '未知歌曲';

          final artist = songInfo['singername'] ??
                         songInfo['author_name'] ??
                         songInfo['singerName'] ??
                         songInfo['singer'] ??
                         songInfo['author'] ??
                         '未知歌手';

          final albumId = songInfo['album_id'] ??
                          songInfo['albumid'] ??
                          songInfo['albumId'] ??
                          '';

          final cover = songInfo['album_img'] ??
                        songInfo['img'] ??
                        songInfo['imgUrl'] ??
                        songInfo['image'] ??
                        songInfo['pic'] ??
                        songInfo['cover'] ??
                        '';

          final mixsongid = songInfo['mixsongid'] ??
                            songInfo['mixSongId'] ??
                            songInfo['songId'] ??
                            '';

          // 确保 duration 是 int 类型 (假设 API 返回的是秒)
          final durationRaw = songInfo['duration'] ??
                           songInfo['timelength'] ??
                           songInfo['timeLength'] ??
                           0;
          final durationInSeconds = durationRaw is int ? durationRaw : (int.tryParse(durationRaw.toString()) ?? 0);

          // 确保创建PlaySongInfo对象
          final songInfoObj = PlaySongInfo(
            hash: hash,
            title: title.toString(), // 确保是String
            artist: artist.toString(), // 确保是String
            albumId: albumId?.toString() ?? '', // 处理可能的null
            cover: cover?.toString() ?? '', // 处理可能的null
            mixsongid: mixsongid?.toString() ?? '', // 处理可能的null
            duration: durationInSeconds, // 传递 int? (秒)
          );
          result.add(songInfoObj);

        } else {
          // 如果 songData 为 null，但 hash 存在 (意味着有 URL 或 Lyric 缓存)
          // 创建一个只包含 hash 的基本 PlaySongInfo 对象
          print('歌曲 $hash 缺少详细信息缓存，创建基础条目');
          final songInfoObj = PlaySongInfo(
            hash: hash,
            title: '歌曲信息加载中...', // 或使用 hash 作为临时标题
            artist: '未知歌手',
            albumId: '',
            cover: '',
            mixsongid: '',
            duration: null, // 或者 0，根据 PlaySongInfo 定义决定
          );
          result.add(songInfoObj);
        }

      } catch (e) {
        print('处理歌曲 $hash 缓存时出错: $e');
        // 即使单个歌曲处理出错，也继续处理下一个
        continue;
      }
    }

    print('完成获取缓存歌曲，共 ${result.length} 首');
    return result;
  }

  /// 缓存统计
  Future<Map<String, int>> getCacheStats() async {
    final keys = await _getAllCacheKeys();
    final stats = <String, int>{};

    for (final type in CacheType.values) {
      final prefix = type.toString().split('.').last + '_';
      stats[type.toString()] =
          keys.where((key) => key.startsWith(prefix)).length;
    }

    return stats;
  }

  /// 缓存PlaySongInfo对象列表
  Future<void> cachePlaySongInfoList(
      String playlistId, List<PlaySongInfo> songs) async {
    final key = generateCacheKey(CacheType.playlist, playlistId);

    // 将 PlaySongInfo 列表转换为可序列化的 Map 列表
    final List<Map<String, dynamic>> serializableList = songs
        .map((song) => {
              'hash': song.hash,
              'title': song.title,
              'artist': song.artist,
              'cover': song.cover,
              'albumId': song.albumId,
              'mixsongid': song.mixsongid,
              // 存储秒数 (int?), 处理可能的 null duration
              'duration': song.duration,
            })
        .toList();

    await updateCache(key, {
      'data': {'tracks': serializableList},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 获取缓存的PlaySongInfo对象列表
  List<PlaySongInfo>? getCachedPlaySongInfoList(String playlistId) {
    final key = generateCacheKey(CacheType.playlist, playlistId);
    final cache =
        getValidCache(key, expiration: getCacheExpiration(CacheType.playlist));

    if (cache != null && cache['tracks'] is List) {
      final List<PlaySongInfo> result = [];
      final tracks = List<Map<String, dynamic>>.from(cache['tracks']);

      for (final songData in tracks) {
        try {
          // 确保从缓存读取时 duration 是 int?
          final durationSeconds = songData['duration'] as int?;

          result.add(PlaySongInfo(
            hash: songData['hash'] ?? '',
            title: songData['title'] ?? '未知歌曲',
            artist: songData['artist'] ?? '未知歌手',
            cover: songData['cover'] ?? '',
            albumId: songData['albumId'] ?? '',
            mixsongid: songData['mixsongid'] ?? '',
            duration: durationSeconds, // 直接使用缓存的 int?
          ));
        } catch (e) {
          print('解析缓存的歌曲数据失败: $e');
        }
      }
      return result;
    }
    return null;
  }
}
