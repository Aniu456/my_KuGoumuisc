import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../data/models/models.dart';
                
/// API服务类
/// 负责处理所有与后端服务器的HTTP请求
/// 使用Dio作为HTTP客户端，CookieJar进行Cookie管理，SharedPreferences进行本地数据存储
class ApiService {
  /// 服务器基础URL
  static const String baseUrl = 'http://8.148.7.143:3000';
  // static const String baseUrl = 'http://127.0.0.1:3000';
  // static const String baseUrl = 'http://10.0.2.2:3000';

  /// 本地存储的歌单缓存键名
  static const String _playlistsCacheKey = 'playlists_cache';
  static const String _recentSongsCacheKey = 'recent_songs_cache';
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
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 3);
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
                  'auth_token',
                  _extractCookieValue(cookie, 'token'),
                );
              } else if (cookie.contains('userid=')) {
                _prefs.setString(
                  'user_id',
                  _extractCookieValue(cookie, 'userid'),
                );
              } else if (cookie.contains('vip_token=')) {
                _prefs.setString(
                  'vip_token',
                  _extractCookieValue(cookie, 'vip_token'),
                );
              } else if (cookie.contains('vip_type=')) {
                _prefs.setString(
                  'vip_type',
                  _extractCookieValue(cookie, 'vip_type'),
                );
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
            clearAuthData();
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

  /// 清除歌单缓存
  void clearPlaylistsCache() {
    _prefs.remove(_playlistsCacheKey);
  }

  /// 清除认证相关数据
  Future<void> clearAuthData() async {
    // 清除SharedPreferences中的认证数据
    await _prefs.remove('auth_token');
    await _prefs.remove('user_id');
    await _prefs.remove('vip_token');
    await _prefs.remove('vip_type');
    await _prefs.remove('user_data');
    // 清除歌单缓存
    clearPlaylistsCache();
  }

  /// 手机号登录
  /// @param phone 手机号
  /// @param code 验证码
  /// @return 返回登录响应数据，包含用户信息和token
  /// @throws Exception 当登录失败时抛出异常
  Future<Map<String, dynamic>> loginWithPhone(String phone, String code) async {
    try {
      final response = await _dio.post(
        '/login/cellphone',
        queryParameters: {
          'mobile': phone,
          'code': code,
        },
      );

      final responseData = response.data as Map<String, dynamic>;

      if (responseData['status'] == 1) {
        // 检查data字段是否存在
        if (responseData['data'] != null &&
            responseData['data'] is Map<String, dynamic>) {
          final data = responseData['data'] as Map<String, dynamic>;

          // 确保必要的字段存在，若不存在则添加默认值
          if (data['token'] == null && responseData['token'] != null) {
            data['token'] = responseData['token'];
          }

          // 将token保存到本地
          if (data['token'] != null) {
            _prefs.setString('auth_token', data['token']);
          }

          // 处理其他可能有用的字段
          if (data['vip_token'] != null) {
            _prefs.setString('vip_token', data['vip_token']);
          }
        } else if (responseData['token'] != null) {
          // 如果data不存在但token在根部，则创建data
          responseData['data'] = {'token': responseData['token']};
          _prefs.setString('auth_token', responseData['token']);
        }

        return responseData;
      }

      throw Exception(
          responseData['error_msg'] ?? responseData['data'] ?? '登录失败');
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw Exception('登录过程中发生错误: $e');
    }
  }

  /// 发送验证码
  /// @param phone 手机号
  /// @return 返回是否发送成功
  Future<bool> sendVerificationCode(String phone) async {
    try {
      final response = await _dio.post(
        '/captcha/sent',
        queryParameters: {'mobile': phone},
      );

      if (response.data['status'] == 1) {
        return true;
      } else {
        throw Exception(response.data['data']);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 使用用户名和密码登录
  /// @param username 用户名
  /// @param password 密码
  /// @return 返回登录响应数据，包含用户信息和token
  Future<Map<String, dynamic>> loginWithPassword(
      String username, String password) async {
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
        // 检查data字段是否存在
        if (responseData['data'] != null &&
            responseData['data'] is Map<String, dynamic>) {
          final data = responseData['data'] as Map<String, dynamic>;

          // 确保必要的字段存在，若不存在则添加默认值
          if (data['token'] == null && responseData['token'] != null) {
            data['token'] = responseData['token'];
          }

          // 将token保存到本地
          if (data['token'] != null) {
            _prefs.setString('auth_token', data['token']);
          }

          // 处理其他可能有用的字段
          if (data['vip_token'] != null) {
            _prefs.setString('vip_token', data['vip_token']);
          }
        } else if (responseData['token'] != null) {
          // 如果data不存在但token在根部，则创建data
          responseData['data'] = {'token': responseData['token']};
          _prefs.setString('auth_token', responseData['token']);
        }

        return responseData;
      }

      throw Exception(
          responseData['error_msg'] ?? responseData['data'] ?? '登录失败');
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw Exception('登录过程中发生错误: $e');
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

  /// 获取用户歌单列表
  /// @param forceRefresh 是否强制刷新，默认false
  /// @return 返回用户歌单列表数据
  /// @throws Exception 当获取失败时抛出异常
  Future<Map<String, dynamic>> getUserPlaylists(
      {bool forceRefresh = false}) async {
    try {
      // 尝试从缓存获取
      if (!forceRefresh) {
        final cachedData = getValidCache(_playlistsCacheKey);
        if (cachedData != null) {
          // 如果有有效缓存，在后台刷新缓存数据
          refreshCacheInBackground(
              _playlistsCacheKey, () => _fetchUserPlaylists());
          return cachedData;
        }
      }

      // 如果没有缓存或强制刷新，直接从服务器获取
      return await _fetchUserPlaylists();
    } catch (e) {
      print('获取用户歌单列表失败: $e');

      // 如果请求失败但有缓存，返回缓存
      final cachedData = getValidCache(_playlistsCacheKey);
      if (cachedData != null) {
        return cachedData;
      }

      // 如果是认证错误，清除认证数据
      if (e.toString().contains('401') ||
          e.toString().contains('未授权') ||
          e.toString().contains('token')) {
        await clearAuthData();
      }

      rethrow;
    }
  }

  // 实际从服务器获取歌单数据
  Future<Map<String, dynamic>> _fetchUserPlaylists() async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final token = _prefs.getString('auth_token');
        if (token == null) {
          throw Exception('未登录或token已失效');
        }

        final response = await _dio.get('/user/playlist');
        print('原始歌单响应: ${response.data}');

        if (response.data['status'] == 1) {
          // 确保返回的响应格式是正确的
          final Map<String, dynamic> responseData = response.data;

          final Map<String, dynamic> cacheData = {
            'data': responseData,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };

          // 更新缓存
          await updateCache(_playlistsCacheKey, cacheData);
          return responseData;
        } else {
          throw Exception(response.data['error_msg'] ?? '获取歌单失败');
        }
      } on DioException catch (e) {
        retryCount++;
        if (retryCount >= _maxRetries) {
          throw _handleDioError(e);
        }
        // 等待一段时间后重试
        await Future.delayed(Duration(seconds: retryCount));
      } catch (e) {
        retryCount++;
        if (retryCount >= _maxRetries) {
          rethrow;
        }
        // 等待一段时间后重试
        await Future.delayed(Duration(seconds: retryCount));
      }
    }
    throw Exception('获取歌单失败，请稍后重试');
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
      print('开始获取歌单曲目，歌单ID: $globalCollectionId, 页码: $page, 每页数量: $pageSize');

      final response = await _dio.get(
        '/playlist/track/all',
        queryParameters: {
          'id': globalCollectionId, // 这里的参数名是正确的，但确保传入的是完整的global_collection_id
          'page': page,
          'pagesize': pageSize,
        },
      );

      print('获取歌单曲目响应: ${response.data}');

      if (response.data['status'] == 1) {
        // 检查data字段是否存在
        if (response.data['data'] == null) {
          print('响应data字段为空');
          return [];
        }

        final data = response.data['data'];

        // 检查songs字段是否存在并为列表（根据API返回的实际格式）
        if (data['songs'] == null || data['songs'] is! List) {
          print('响应songs字段为空或不是列表');
          // 兼容处理：尝试从info字段获取数据
          if (data['info'] != null && data['info'] is List) {
            final List<dynamic> infoList = data['info'];
            print('从info字段获取到歌单曲目，数量: ${infoList.length}');
            return _processTrackList(infoList);
          }
          return [];
        }

        final List<dynamic> songsList = data['songs'];
        print('成功获取歌单曲目，数量: ${songsList.length}');

        return _processTrackList(songsList);
      } else {
        throw Exception(response.data['error_msg'] ?? '获取歌单歌曲失败');
      }
    } on DioException catch (e) {
      print('获取歌单曲目DioException: $e');
      throw _handleDioError(e);
    } catch (e) {
      print('获取歌单曲目异常: $e');
      throw Exception('获取歌单歌曲失败: $e');
    }
  }

  // 处理曲目列表，提取为单独方法方便复用
  List<Map<String, dynamic>> _processTrackList(List<dynamic> trackList) {
    // 将每个元素转换为Map<String, dynamic>
    return trackList.map((item) {
      // 确保item是Map类型
      if (item is Map) {
        return Map<String, dynamic>.from(item);
      } else {
        // 如果不是Map，创建一个包含错误信息的Map
        print('歌曲项目格式错误: $item');
        return <String, dynamic>{
          'hash': '',
          'title': '格式错误的歌曲',
          'artist': '未知艺术家',
          'error': '歌曲数据格式错误'
        };
      }
    }).toList();
  }

  /// 获取歌曲播放地址
  /// @param hash 歌曲hash
  /// @param albumId 专辑ID
  /// @return 返回歌曲播放地址
  /// @throws Exception 当获取失败时抛出异常
  Future<String> getSongUrl(String hash, String albumId) async {
    try {
      final response = await _dio.get('/song/url', queryParameters: {
        'hash': hash,
        'album_id': albumId,
      });

      final responseData = response.data;
      print('获取到的歌曲URL响应数据: $responseData');

      // 检查歌曲权限状态
      if (responseData['status'] == 2) {
        final failProcess = responseData['fail_process'] as List?;
        if (failProcess?.contains('pkg') == true ||
            failProcess?.contains('buy') == true) {
          throw Exception('该歌曲需要购买或者VIP会员才能播放');
        }
        throw Exception('无法播放该歌曲，可能是版权限制');
      }

      // 首先尝试使用主 URL 列表
      if (responseData['url'] != null &&
          responseData['url'] is List &&
          (responseData['url'] as List).isNotEmpty) {
        return (responseData['url'] as List).first.toString();
      }

      // 如果主 URL 列表为空，尝试使用备用 URL 列表
      if (responseData['backupUrl'] != null &&
          responseData['backupUrl'] is List &&
          (responseData['backupUrl'] as List).isNotEmpty) {
        return (responseData['backupUrl'] as List).first.toString();
      }

      throw Exception('无法获取歌曲播放地址');
    } catch (e) {
      print('获取歌曲URL失败: $e');
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
        final cachedData = getValidCache(_recentSongsCacheKey);
        if (cachedData != null) {
          // 在后台刷新缓存
          refreshCacheInBackground(
              _recentSongsCacheKey, () => fetchRecentSongs(bq: bq));
          return RecentSongsResponse.fromJson(cachedData);
        }
      }

      // 从服务器获取新数据
      return await fetchRecentSongs(bq: bq);
    } catch (e) {
      // 如果请求失败但有缓存，返回缓存
      final cachedData = getValidCache(_recentSongsCacheKey);
      if (cachedData != null) {
        return RecentSongsResponse.fromJson(cachedData);
      }
      throw Exception('获取最近播放记录失败: $e');
    }
  }

  // 从服务器获取最近播放数据
  Future<RecentSongsResponse> fetchRecentSongs({String? bq}) async {
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
      await updateCache(_recentSongsCacheKey, cacheData);
      return RecentSongsResponse.fromJson(response.data);
    } else {
      throw Exception(response.data['error_msg'] ?? '获取最近播放记录失败');
    }
  }

  // 获取有效的缓存数据
  Map<String, dynamic>? getValidCache(String key) {
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

  // 在后台刷新缓存，带重试机制
  Future<void> refreshCacheInBackground(
      String key, Future<dynamic> Function() fetchData) async {
    Future.delayed(Duration.zero, () async {
      int retryCount = 0;
      while (retryCount < _maxRetries) {
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
          'isValid': isValidCache(playlistsCache),
        },
        'recentSongs': {
          'hasCache': recentSongsCache != null,
          'timestamp': recentSongsCache?['timestamp'],
          'isValid': isValidCache(recentSongsCache),
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
  bool isValidCache(Map<String, dynamic>? cache) {
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
      if (getValidCache(key) == null) {
        await clearCache(key);
      }
    }
  }

  /// 退出登录
  /// 清除本地存储的token和用户数据
  /// @throws Exception 当退出失败时抛出异常
  Future<void> logout() async {
    try {
      await _dio.post('/logout');
      clearAuthData();
    } catch (e) {
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
