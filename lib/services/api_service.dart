import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/recent_song.dart';
import '../models/search_response.dart';
import '../models/play_song_info.dart';
import '../models/song_mv.dart';

/// API服务类
/// 负责处理所有与后端服务器的HTTP请求
/// 使用Dio作为HTTP客户端，SharedPreferences进行本地数据存储
class ApiService {
  /// 服务器基础URL
  static const String baseUrl = 'http://8.148.7.143:3000';

  /// 本地存储的歌单缓存键名
  static const String _playlistsCacheKey = 'playlists_cache';
  static const String _recentSongsCacheKey = 'recent_songs_cache';
  static const String _favoritePlaylistIdKey = 'favorite_playlist_id';
  static const Duration _cacheExpiration = Duration(minutes: 30); // 缓存过期时间
  static const int _maxRetries = 3; // 最大重试次数

  /// Dio实例，用于发送HTTP请求
  final Dio _dio;

  /// SharedPreferences实例，用于本地数据存储
  final SharedPreferences _prefs;

  /// 构造函数
  /// @param _prefs SharedPreferences实例，用于存储token等数据
  ApiService(this._prefs) : _dio = Dio() {
    // 配置Dio基本设置
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10); // 增加连接超时时间
    _dio.options.receiveTimeout = const Duration(seconds: 10); // 增加接收超时时间
    _dio.options.sendTimeout = const Duration(seconds: 10); // 增加发送超时时间
    _dio.options.validateStatus = (status) {
      return status! < 500 || status == 500 || status == 502;
    };

    // 启用Cookie管理
    _dio.options.receiveDataWhenStatusError = true;
    _dio.options.followRedirects = false;
    _dio.options.validateStatus = (status) => true;

    // 添加请求/响应拦截器
    _dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          // 检查响应头中的Set-Cookie
          final cookies = response.headers['set-cookie'];
          if (cookies != null && cookies.isNotEmpty) {
            // 解析并保存Cookie
            for (var cookie in cookies) {
              if (cookie.contains('token=')) {
                _prefs.setString(
                    'auth_token', _extractCookieValue(cookie, 'token'));
              } else if (cookie.contains('userid=')) {
                _prefs.setString(
                    'user_id', _extractCookieValue(cookie, 'userid'));
              } else if (cookie.contains('vip_token=')) {
                _prefs.setString(
                    'vip_token', _extractCookieValue(cookie, 'vip_token'));
              } else if (cookie.contains('vip_type=')) {
                _prefs.setString(
                    'vip_type', _extractCookieValue(cookie, 'vip_type'));
              }
            }
          }
          return handler.next(response);
        },
        onRequest: (options, handler) {
          // 添加已保存的Cookie到请求头
          final cookies = <String>[];
          final token = _prefs.getString('auth_token');
          final userId = _prefs.getString('user_id');
          final vipToken = _prefs.getString('vip_token');
          final vipType = _prefs.getString('vip_type');

          if (token != null) cookies.add('token=$token');
          if (userId != null) cookies.add('userid=$userId');
          if (vipToken != null) cookies.add('vip_token=$vipToken');
          if (vipType != null) cookies.add('vip_type=$vipType');

          if (cookies.isNotEmpty) {
            options.headers['Cookie'] = cookies.join('; ');
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // Token过期，清除本地存储的认证信息
            _clearAuthData();
          }
          return handler.next(error);
        },
      ),
    );
  }

  // 从Cookie字符串中提取值
  String _extractCookieValue(String cookie, String key) {
    final match = RegExp('$key=([^;]*)').firstMatch(cookie);
    return match?.group(1) ?? '';
  }

  /// 手机号登录
  /// @param phone 手机号
  /// @param code 验证码
  /// @return 返回登录响应数据，包含用户信息和token
  /// @throws Exception 当登录失败时抛出异常
  Future<Map<String, dynamic>> loginWithPhone(String phone, String code) async {
    try {
      print('手机号登录请求开始 - 手机号: $phone, 验证码: $code');
      final response = await _dio.post(
        '/login/cellphone',
        queryParameters: {
          'mobile': phone,
          'code': code,
        },
      );

      print('手机号登录响应: ${response.data}');
      final responseData = response.data as Map<String, dynamic>;
      if (responseData['status'] == 1) {
        // 登录成功后立即缓存我喜欢歌单ID
        print('手机号登录成功，开始缓存歌单信息');
        await _cacheFavoritePlaylistId();
        return responseData;
      }

      final errorMsg =
          responseData['error_msg'] ?? responseData['data'] ?? '登录失败';
      print('手机号登录失败: $errorMsg');
      throw Exception(errorMsg);
    } on DioException catch (e) {
      print('手机号登录网络异常: ${e.message}');
      if (e.response != null) {
        print('响应数据: ${e.response?.data}');
      }
      throw _handleDioError(e);
    } catch (e) {
      print('手机号登录其他异常: $e');
      rethrow;
    }
  }

  /// 账号密码登录
  /// @param username 用户名
  /// @param password 密码
  /// @return 返回登录响应数据
  /// @throws Exception 当登录失败时抛出异常
  Future<Map<String, dynamic>> loginWithPassword(
    String username,
    String password,
  ) async {
    try {
      final response = await _dio.post(
        '/login',
        queryParameters: {
          'username': username,
          'password': password,
        },
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['status'] == 1) {
        // 登录成功后立即缓存我喜欢歌单ID
        await _cacheFavoritePlaylistId();
        return responseData;
      }

      throw Exception(responseData['error_msg'] ?? '登录失败');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 缓存我喜欢歌单ID
  Future<void> _cacheFavoritePlaylistId() async {
    try {
      final playlists = await getUserPlaylists();
      final List playlistInfo = playlists['info'] as List;

      // 查找"我喜欢"歌单
      final favoritePlaylist = playlistInfo.firstWhere(
        (playlist) => playlist['name'].toString().trim() == '我喜欢',
        orElse: () => playlistInfo.firstWhere(
          (playlist) => playlist['name'].toString().trim() == '收藏',
          orElse: () => {},
        ),
      );

      if (favoritePlaylist.isNotEmpty) {
        final listId = favoritePlaylist['listid']?.toString();
        if (listId != null && listId.isNotEmpty) {
          await _prefs.setString(_favoritePlaylistIdKey, listId);
          print('成功缓存我喜欢歌单ID: $listId');
        }
      }
    } catch (e) {
      print('缓存我喜欢歌单ID失败: $e');
    }
  }

  /// 获取缓存的我喜欢歌单ID
  String? getFavoritePlaylistIdFromCache() {
    return _prefs.getString(_favoritePlaylistIdKey);
  }

  /// 清除所有认证相关数据
  void _clearAuthData() {
    _prefs.remove('auth_token');
    _prefs.remove('user_id');
    _prefs.remove('vip_token');
    _prefs.remove('vip_type');
    _prefs.remove('user_data');
    _prefs.remove(_favoritePlaylistIdKey);
    _clearPlaylistsCache();
  }

  /// 发送验证码
  /// @param phone 手机号
  /// @return 返回是否发送成功
  Future<bool> sendVerificationCode(String phone) async {
    try {
      print('开始发送验证码 - 手机号: $phone');
      final response = await _dio.post(
        '/captcha/sent',
        queryParameters: {'mobile': phone},
      );

      print('发送验证码响应: ${response.data}');
      if (response.data['status'] == 1) {
        print('验证码发送成功');
        return true;
      } else {
        final errorMsg =
            response.data['data'] ?? response.data['error_msg'] ?? '发送验证码失败';
        print('验证码发送失败: $errorMsg');
        throw Exception(errorMsg);
      }
    } on DioException catch (e) {
      print('发送验证码网络异常: ${e.message}');
      if (e.response != null) {
        print('响应数据: ${e.response?.data}');
      }
      throw _handleDioError(e);
    } catch (e) {
      print('发送验证码其他异常: $e');
      rethrow;
    }
  }

  /// 获取用户详细信息
  /// @return 返回用户详细信息
  /// @throws Exception 当获取失败时抛出异常
  Future<Map<String, dynamic>> getUserDetail() async {
    try {
      final token = _prefs.getString('auth_token');
      if (token == null) {
        throw Exception('未登录或token已失效');
      }
      final response = await _dio.get('/user/detail');
      if (response.data['status'] == 1) {
        return response.data;
      } else {
        throw Exception(response.data['data'] ?? '获取用户信息失败');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 获取用户VIP详情
  Future<Map<String, dynamic>> getUserVipDetail() async {
    try {
      final response = await _dio.get('/user/vip/detail');
      print('获取VIP详情响应: ${response.data}');
      if (response.data['status'] == 1) {
        return response.data['data'];
      }
      throw Exception(response.data['error_msg'] ?? '获取VIP信息失败');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 清除歌单缓存
  void _clearPlaylistsCache() {
    _prefs.remove(_playlistsCacheKey);
  }

  /// 获取用户歌单
  Future<Map<String, dynamic>> getUserPlaylists(
      {bool forceRefresh = false}) async {
    try {
      // 尝试从缓存获取
      if (!forceRefresh) {
        final cachedData = _getValidCache(_playlistsCacheKey);
        if (cachedData != null) {
          // 在后台刷新缓存
          Future.delayed(Duration.zero, () async {
            try {
              final response = await _dio.get('/user/playlist');
              print('后台刷新歌单缓存响应: ${response.data}');
              if (response.data['status'] == 1) {
                final cacheData = {
                  'data': response.data['data'],
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                };
                await _updateCache(_playlistsCacheKey, cacheData);
              }
            } catch (e) {
              print('后台刷新歌单缓存失败: $e');
            }
          });
          return {
            'info': cachedData['data']['info'] as List,
            'list_count': cachedData['data']['info'].length,
          };
        }
      }

      // 从服务器获取新数据
      final response = await _dio.get('/user/playlist');
      print('获取用户歌单响应: ${response.data}');

      if (response.data['status'] == 1) {
        final responseData = response.data['data'];
        final cacheData = {
          'data': responseData,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        await _updateCache(_playlistsCacheKey, cacheData);
        return {
          'info': responseData['info'] as List,
          'list_count': responseData['info'].length,
        };
      } else {
        // 处理错误状态
        final errorCode = response.data['error_code'];
        final errorMsg = response.data['error_msg'] ?? '未知错误';
        print('获取歌单失败 - 错误码: $errorCode, 错误信息: $errorMsg');

        // 如果是token过期或未登录错误，清除认证数据
        if (errorCode == 20017) {
          print('Token已过期或未登录，清除认证数据');
          _clearAuthData();
        }

        throw Exception('获取歌单失败: $errorMsg (错误码: $errorCode)');
      }
    } catch (e) {
      print('获取歌单异常: $e');
      // 如果请求失败但有缓存，返回缓存
      final cachedData = _getValidCache(_playlistsCacheKey);
      if (cachedData != null) {
        print('使用缓存的歌单数据');
        return {
          'info': cachedData['data']['info'] as List,
          'list_count': cachedData['data']['info'].length,
        };
      }
      rethrow;
    }
  }

  /// 添加歌曲到"我喜欢"歌单
  Future<bool> addToFavorite(PlaySongInfo songInfo) async {
    print('准备添加歌曲到"我喜欢"歌单: ${songInfo.title}');
    print(
        '歌曲完整信息: hash=${songInfo.hash}, title=${songInfo.title}, artist=${songInfo.artist}, mixsongid=${songInfo.mixsongid}');

    final listId = getFavoritePlaylistIdFromCache();
    if (listId == null) {
      // 如果缓存中没有，尝试重新获取并缓存
      await _cacheFavoritePlaylistId();
      final newListId = getFavoritePlaylistIdFromCache();
      if (newListId == null) {
        throw Exception('未找到"我喜欢"歌单');
      }
    }

    final songData = <String, dynamic>{
      'name': songInfo.title,
      'hash': songInfo.hash,
      'mixsongid': songInfo.mixsongid ?? '', // 如果为空则使用空字符串
    };

    print('歌曲信息: $songData');
    return addSongToPlaylist(listId!, songData);
  }

  /// 添加歌曲到歌单
  Future<bool> addSongToPlaylist(
      String listId, Map<String, dynamic> songData) async {
    try {
      print('正在添加歌曲到歌单，歌单ID: $listId, 歌曲数据: $songData');

      // 构建数据字符串：歌名|hash|mixsongid
      final dataString =
          '${songData['name']}|${songData['hash']}|${songData['mixsongid']}';
      print('发送的数据: $dataString');

      final response = await _dio.post(
        '/playlist/tracks/add',
        queryParameters: {
          'listid': listId,
          'data': dataString,
        },
      );

      print('添加歌曲响应: ${response.data}');
      if (response.data['status'] == 1) {
        return true;
      }
      throw Exception(response.data['error_msg'] ?? '添加歌曲到歌单失败');
    } on DioException catch (e) {
      print('添加歌曲到歌单失败: ${e.response?.data}');
      throw _handleDioError(e);
    }
  }

  /// 获取歌单内的所有歌曲
  /// @param globalCollectionId 歌单的global_collection_id
  /// @param page 页码，从1开始
  /// @param pageSize 每页数量，默认30
  /// @return 返回歌单内的歌曲列表
  /// @throws Exception 当获取失败时抛出异常
  Future<List<Map<String, dynamic>>> getPlaylistTracks(
    String globalCollectionId, {
    int page = 1,
    int pageSize = 30,
  }) async {
    try {
      final response = await _dio.get(
        '/playlist/track/all',
        queryParameters: {
          'id': globalCollectionId,
          'page': page,
          'pagesize': pageSize,
        },
      );

      if (response.data['status'] == 1) {
        return List<Map<String, dynamic>>.from(response.data['data']['info']);
      } else {
        throw Exception(response.data['error_msg'] ?? '获取歌单歌曲失败');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 获取歌曲播放地址
  /// @param hash 歌曲hash
  /// @param albumId 歌曲所属专辑ID，可选
  /// @return 返回歌曲播放URL
  Future<String> getSongUrl(String hash, String albumId) async {
    try {
      // 构建请求参数
      final queryParams = {
        'mid': 1,
        'hash': hash,
        'album_id': albumId,
      };

      // 发送请求
      final response =
          await _dio.get('/song/url', queryParameters: queryParams);
      final responseData = response.data;

      print('获取到的歌曲URL响应数据: $responseData');

      // 检查状态码
      if (responseData['status'] != 1) {
        throw Exception(responseData['error_msg'] ?? '获取歌曲播放地址失败');
      }

      // 提取URL
      String? songUrl;

      // 方法1：直接从url数组中获取第一个URL
      if (responseData['url'] != null &&
          responseData['url'] is List &&
          (responseData['url'] as List).isNotEmpty) {
        songUrl = (responseData['url'] as List).first.toString();
      }

      // 方法2：如果没有找到url数组，尝试从backupUrl获取
      if (songUrl == null &&
          responseData['backupUrl'] != null &&
          responseData['backupUrl'] is List &&
          (responseData['backupUrl'] as List).isNotEmpty) {
        songUrl = (responseData['backupUrl'] as List).first.toString();
      }

      // 方法3：如果没有找到url和backupUrl，尝试从data字段中获取
      if (songUrl == null && responseData['data'] != null) {
        final data = responseData['data'];
        if (data is Map && data['url'] != null) {
          songUrl = data['url'].toString();
        }
      }

      // 如果所有方法都失败，抛出异常
      if (songUrl == null || songUrl.isEmpty) {
        throw Exception('未找到歌曲播放地址');
      }

      print('解析到的播放URL: $songUrl');
      return songUrl;
    } on DioException catch (e) {
      print('获取歌曲播放地址失败: ${e.message}');
      throw _handleDioError(e);
    } catch (e) {
      print('处理歌曲播放地址失败: $e');
      rethrow;
    }
  }

  /// 搜索歌词信息
  /// @param hash 歌曲hash
  /// @return 返回歌词ID和accesskey
  /// @throws Exception 当获取失败时抛出异常
  Future<Map<String, String>> searchLyric(String hash) async {
    try {
      final response = await _dio.get(
        '/search/lyric',
        queryParameters: {'hash': hash},
      );

      final responseData = response.data;
      if (responseData['status'] == 200) {
        final candidates = responseData['candidates'] as List;
        if (candidates.isNotEmpty) {
          final firstCandidate = candidates[0];
          return {
            'id': firstCandidate['id']?.toString() ?? '',
            'accesskey': firstCandidate['accesskey']?.toString() ?? '',
          };
        }
      }
      throw Exception('获取歌词信息失败');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 获取歌词内容
  /// @param id 歌词ID
  /// @param accesskey 访问密钥
  /// @return 返回歌词内容
  /// @throws Exception 当获取失败时抛出异常
  Future<String> getLyric(String id, String accesskey) async {
    try {
      final response = await _dio.get(
        '/lyric',
        queryParameters: {
          'id': id,
          'accesskey': accesskey,
          'decode': true,
          'fmt': 'lrc',
        },
      );

      final responseData = response.data;
      if (responseData['status'] == 200) {
        // 尝试获取解码后的内容，如果没有则获取原始内容
        final content =
            responseData['decodeContent'] ?? responseData['content'];
        if (content != null) {
          return content.toString();
        }
      }
      throw Exception('获取歌词内容失败');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 获取完整的歌词（包含搜索和获取内容）
  /// @param hash 歌曲hash
  /// @return 返回歌词内容
  /// @throws Exception 当获取失败时抛出异常
  Future<String> getFullLyric(String hash) async {
    try {
      final lyricInfo = await searchLyric(hash);
      if (lyricInfo['id']?.isNotEmpty == true &&
          lyricInfo['accesskey']?.isNotEmpty == true) {
        return await getLyric(lyricInfo['id']!, lyricInfo['accesskey']!);
      }
      throw Exception('获取歌词失败');
    } catch (e) {
      rethrow;
    }
  }

  /// 获取最近播放记录
  /// @param bq 分页参数，可选
  /// @param forceRefresh 是否强制刷新，默认false
  Future<RecentSongsResponse> getRecentSongs({
    String? bq,
    bool forceRefresh = false,
  }) async {
    try {
      // 尝试从缓存获取
      if (!forceRefresh) {
        final cachedData = _getValidCache(_recentSongsCacheKey);
        if (cachedData != null) {
          // 在后台刷新缓存
          _refreshCacheInBackground(
              _recentSongsCacheKey, () => _fetchRecentSongs(bq: bq));
          return RecentSongsResponse.fromJson(cachedData);
        }
      }

      // 从服务器获取新数据
      return await _fetchRecentSongs(bq: bq);
    } catch (e) {
      // 如果请求失败但有缓存，返回缓存
      final cachedData = _getValidCache(_recentSongsCacheKey);
      if (cachedData != null) {
        return RecentSongsResponse.fromJson(cachedData);
      }
      throw Exception('获取最近播放记录失败: $e');
    }
  }

  // 从服务器获取最近播放数据
  Future<RecentSongsResponse> _fetchRecentSongs({String? bq}) async {
    final queryParams = <String, dynamic>{};
    if (bq != null && bq.isNotEmpty) {
      queryParams['bq'] = bq;
    }

    final response =
        await _dio.get('/user/history', queryParameters: queryParams);
    print('获取最近播放响应: ${response.data}');

    if (response.data['status'] == 1) {
      final Map<String, dynamic> cacheData = {
        'data': response.data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      // 更新缓存
      await _updateCache(_recentSongsCacheKey, cacheData);
      return RecentSongsResponse.fromJson(response.data);
    } else {
      throw Exception(response.data['error_msg'] ?? '获取最近播放记录失败');
    }
  }

  // 获取有效的缓存数据
  Map<String, dynamic>? _getValidCache(String key) {
    try {
      final cachedString = _prefs.getString(key);
      if (cachedString != null) {
        final cached = json.decode(cachedString);
        final timestamp = cached['timestamp'] ?? 0;

        // 检查缓存是否过期
        if (DateTime.now().millisecondsSinceEpoch - timestamp <
            _cacheExpiration.inMilliseconds) {
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

  // 更新缓存
  Future<void> _updateCache(String key, Map<String, dynamic> data) async {
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

  // 在后台刷新缓存，带重试机制
  Future<void> _refreshCacheInBackground(
      String key, Future<dynamic> Function() fetchData) async {
    Future.delayed(Duration.zero, () async {
      int retryCount = 0;
      while (retryCount < _maxRetries) {
        try {
          await fetchData();
          break; // 成功后跳出循环
        } catch (e) {
          retryCount++;
          if (retryCount >= _maxRetries) {
            print('后台刷新缓存失败 ($retryCount/$_maxRetries): $e');
            break;
          }
          // 等待一段时间后重试
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      }
    });
  }

  // 获取缓存状态
  Future<Map<String, dynamic>> getCacheStatus() async {
    try {
      final playlistsCacheStr = _prefs.getString(_playlistsCacheKey);
      final recentSongsCacheStr = _prefs.getString(_recentSongsCacheKey);

      final playlistsCache =
          playlistsCacheStr != null ? json.decode(playlistsCacheStr) : null;
      final recentSongsCache =
          recentSongsCacheStr != null ? json.decode(recentSongsCacheStr) : null;

      return {
        'playlists': {
          'hasCache': playlistsCache != null,
          'timestamp': playlistsCache?['timestamp'],
          'isValid': _isValidCache(playlistsCache),
        },
        'recentSongs': {
          'hasCache': recentSongsCache != null,
          'timestamp': recentSongsCache?['timestamp'],
          'isValid': _isValidCache(recentSongsCache),
        },
      };
    } catch (e) {
      print('获取缓存状态失败: $e');
      return {
        'playlists': {'hasCache': false, 'isValid': false},
        'recentSongs': {'hasCache': false, 'isValid': false},
      };
    }
  }

  // 检查缓存是否有效
  bool _isValidCache(Map<String, dynamic>? cache) {
    if (cache == null) return false;
    final timestamp = cache['timestamp'] ?? 0;
    return DateTime.now().millisecondsSinceEpoch - timestamp <
        _cacheExpiration.inMilliseconds;
  }

  // 清除指定缓存
  Future<void> clearCache(String key) async {
    await _prefs.remove(key);
  }

  // 清除过期缓存
  Future<void> clearExpiredCache() async {
    final keys = [_playlistsCacheKey, _recentSongsCacheKey];
    for (final key in keys) {
      if (_getValidCache(key) == null) {
        await clearCache(key);
      }
    }
  }

  /// 处理Dio异常
  /// 将Dio的异常转换为用户友好的错误信息
  /// @param e Dio异常
  /// @return 转换后的异常对象
  Exception _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('网络连接超时，请检查网络');

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data['message'] ?? '未知错误';
        switch (statusCode) {
          case 400:
            return Exception('请求参数错误: $message');
          case 401:
            return Exception('未授权或登录已过期');
          case 403:
            return Exception('没有权限访问');
          case 404:
            return Exception('请求的资源不存在');
          case 500:
          case 502:
            return Exception('服务器错误: $message');
          default:
            return Exception('请求失败: $message');
        }

      case DioExceptionType.cancel:
        return Exception('请求已取消');

      case DioExceptionType.unknown:
        if (e.error != null) {
          return Exception('未知错误: ${e.error}');
        }
        return Exception('网络错误，请检查网络连接');

      default:
        return Exception('请求失败，请稍后重试');
    }
  }

  /// 退出登录
  /// 清除本地存储的token和用户数据
  /// @throws Exception 当退出失败时抛出异常
  Future<void> logout() async {
    try {
      await _dio.post('/logout');
      _clearAuthData();
    } catch (e) {
      print('退出登录过程中出错: $e');
      rethrow;
    }
  }

  /// 搜索歌曲
  /// @param keyword 搜索关键词
  /// @param page 页码，默认1
  /// @param pageSize 每页数量，默认20
  /// @return 返回搜索结果
  Future<SearchResponse> searchSongs(String keyword,
      {int page = 1, int pageSize = 20}) async {
    try {
      final response = await _dio.get('/search', queryParameters: {
        'keywords': keyword,
        'page': page,
        'pagesize': pageSize,
      });
      print(response.data);
      if (response.data['status'] == 1) {
        return SearchResponse.fromJson(response.data);
      } else {
        throw Exception(response.data['error_msg'] ?? '搜索失败');
      }
    } catch (e) {
      print('搜索歌曲失败: $e');
      rethrow;
    }
  }

  /// 从歌单删除歌曲
  Future<bool> removeSongFromPlaylist(String listId, String fileId) async {
    try {
      print('正在从歌单删除歌曲，歌单ID: $listId, fileId: $fileId');

      final response = await _dio.post(
        '/playlist/tracks/del',
        queryParameters: {
          'listid': listId,
          'fileids': fileId,
        },
      );

      print('删除歌曲响应: ${response.data}');
      if (response.data['status'] == 1) {
        return true;
      }
      throw Exception(response.data['error_msg'] ?? '从歌单删除歌曲失败');
    } on DioException catch (e) {
      print('从歌单删除歌曲失败: ${e.response?.data}');
      throw _handleDioError(e);
    }
  }

  // 1. 获取MV列表
  Future<List<MvInfo>> getMVList(String albumAudioId) async {
    try {
      final response = await _dio.get('/kmr/audio/mv', queryParameters: {
        'album_audio_id': albumAudioId,
      });

      if (response.data['status'] == 1) {
        // 添加空值和类型检查
        final data = response.data['data'];
        if (data == null || data is! List || data.isEmpty) {
          print('MV列表数据为空或格式不正确');
          return [];
        }

        final mvData = data[0];
        if (mvData == null || mvData is! List) {
          print('MV列表数据格式不正确');
          return [];
        }

        return mvData.map((json) => MvInfo.fromJson(json)).toList();
      }
      print('获取MV列表失败: ${response.data}');
      return []; // 返回空列表而不是抛出异常
    } catch (e) {
      print('获取MV列表异常: $e');
      return []; // 出现异常时返回空列表
    }
  }

  // 2. 获取视频详细信息
  Future<String?> getVideoHash(int videoId) async {
    final response = await _dio.get('/video/detail', queryParameters: {
      'id': videoId,
    });
    // print(response.data['data']['hd_hash_265']);
    if (response.data['status'] == 1) {
      // 优先使用FHD版本，如果没有则使用HD版本
      final String? fhdHash = response.data['data'][0]['fhd_hash_265'];
      final String? hdHash = response.data['data'][0]['hd_hash_265'];
      return fhdHash ?? hdHash;
    }
    throw Exception('获取视频详情失败');
  }

  // 3. 获取视频播放地址
  Future<String> getVideoUrl(String videoHash) async {
    final response = await _dio.get('/video/url', queryParameters: {
      'hash': videoHash,
    });

    if (response.data['status'] == 1) {
      final data = response.data['data'][videoHash.toLowerCase()];
      // 优先使用主下载地址，如果失败可以使用备用地址
      return data['downurl'] ?? data['backupdownurl'][0];
    }
    throw Exception('获取视频地址失败');
  }

  // 4. 便捷方法：一次性获取视频播放地址
  Future<String> getPlayableVideoUrl(int videoId) async {
    final videoHash = await getVideoHash(videoId);
    return await getVideoUrl(videoHash!);
  }
}
