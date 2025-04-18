import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/models.dart';
import 'storage/cache_manager.dart';

/// API服务类
class ApiService {
  // 服务器基础URL
  static const String baseUrl = 'http://8.148.7.143:3000';
  // 缓存键名
  static const String _playlistsCacheKey = 'playlists_cache';
  static const String _recentSongsCacheKey = 'recent_songs_cache';

  final Dio _dio;
  final SharedPreferences _prefs;
  final CacheManager _cacheManager;

  ApiService(this._prefs)
      : _dio = Dio(),
        _cacheManager = CacheManager(_prefs) {
    _initDio();
  }

  // 初始化Dio配置
  void _initDio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 3);
    _dio.options.validateStatus = (status) => true;
    _dio.options.receiveDataWhenStatusError = true;
    _dio.options.followRedirects = false;

    // 添加拦截器
    _dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: _handleResponse,
        onRequest: _handleRequest,
        onError: _handleInterceptorError,
      ),
    );
  }

  // 响应拦截器
  void _handleResponse(Response response, ResponseInterceptorHandler handler) {
    print('响应拦截器 - 路径: ${response.requestOptions.path}');
    print('响应拦截器 - 状态码: ${response.statusCode}');
    print('响应拦截器 - 响应头: ${response.headers}');

    final cookies = response.headers['set-cookie'];
    print('响应拦截器 - set-cookie: $cookies');

    if (cookies != null && cookies.isNotEmpty) {
      for (var cookie in cookies) {
        print('处理 cookie: $cookie');
        _processCookie(cookie);
      }
    } else {
      print('没有设置 cookie');
    }

    handler.next(response);
  }

  // 请求拦截器
  void _handleRequest(
      RequestOptions options, RequestInterceptorHandler handler) {
    final cookies = <String>[];
    final token = _prefs.getString('auth_token');
    final userId = _prefs.getString('user_id');
    final vipToken = _prefs.getString('vip_token');
    final vipType = _prefs.getString('vip_type');

    print('请求拦截器 - 路径: ${options.path}');
    print('请求拦截器 - token: $token');
    print('请求拦截器 - userId: $userId');

    if (token != null) cookies.add('token=$token');
    if (userId != null) cookies.add('userid=$userId');
    if (vipToken != null) cookies.add('vip_token=$vipToken');
    if (vipType != null) cookies.add('vip_type=$vipType');

    if (cookies.isNotEmpty) {
      options.headers['Cookie'] = cookies.join('; ');
      print('请求拦截器 - 设置 Cookie: ${cookies.join('; ')}');
    } else {
      print('请求拦截器 - 没有设置 Cookie，因为没有认证信息');
    }

    // 添加其他必要的请求头
    options.headers['User-Agent'] =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
    options.headers['Accept'] = '*/*';

    print('请求拦截器 - 最终请求头: ${options.headers}');

    handler.next(options);
  }

  // 错误拦截器
  void _handleInterceptorError(
      DioException error, ErrorInterceptorHandler handler) {
    if (error.response?.statusCode == 401) {
      clearAuthData();
    }
    handler.next(error);
  }

  // 处理Cookie
  void _processCookie(String cookie) {
    print('开始处理 cookie: $cookie');

    final cookieMap = {
      'token': 'auth_token',
      'userid': 'user_id',
      'vip_token': 'vip_token',
      'vip_type': 'vip_type',
    };

    for (var entry in cookieMap.entries) {
      if (cookie.contains('${entry.key}=')) {
        final value = _extractCookieValue(cookie, entry.key);
        print('提取到 ${entry.key}=$value，存储为 ${entry.value}');

        _prefs.setString(entry.value, value);
      }
    }

    // 检查存储后的值
    for (var entry in cookieMap.entries) {
      final storedValue = _prefs.getString(entry.value);
      print('存储后的 ${entry.value}: $storedValue');
    }
  }

  // 从Cookie字符串中提取值
  String _extractCookieValue(String cookie, String key) {
    print('尝试从 cookie 中提取 $key: $cookie');
    final match = RegExp('$key=([^;]*)').firstMatch(cookie);
    final value = match?.group(1) ?? '';
    print('提取结果: $value');
    return value;
  }

  /// 通用API请求方法
  Future<dynamic> _apiRequest(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? queryParams,
    dynamic data,
    bool checkCache = false,
    String? cacheKey,
    Function(dynamic)? processResponse,
  }) async {
    try {
      // 检查缓存
      if (checkCache && cacheKey != null) {
        final cachedData = _cacheManager.getValidCache(cacheKey);
        if (cachedData != null) return cachedData;
      }

      // 发送请求
      Response response;
      switch (method) {
        case 'GET':
          response = await _dio.get(path, queryParameters: queryParams);
          break;
        case 'POST':
          response =
              await _dio.post(path, queryParameters: queryParams, data: data);
          break;
        default:
          throw Exception('不支持的HTTP方法');
      }

      // 处理响应
      final responseData = response.data;
      final status = responseData['status'];

      if (status == 1 || status == 200) {
        // 更新缓存
        if (checkCache && cacheKey != null) {
          _cacheManager.updateCache(cacheKey, {
            'data': responseData,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }

        return processResponse != null
            ? processResponse(responseData)
            : responseData['data'] ?? responseData;
      }

      throw Exception(
          responseData['error_msg'] ?? responseData['data'] ?? '请求失败');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 清除认证相关数据
  Future<void> clearAuthData() async {
    final authKeys = [
      'auth_token',
      'user_id',
      'vip_token',
      'vip_type',
      'user_data'
    ];
    for (var key in authKeys) {
      await _prefs.remove(key);
    }

    await _cacheManager.clear(_playlistsCacheKey);
    await _cacheManager.clear(_recentSongsCacheKey);
  }

  /// 清除歌单缓存
  Future<void> clearPlaylistsCache() async {
    await _cacheManager.clear(_playlistsCacheKey);
  }

  /// 统一登录函数
  Future<Map<String, dynamic>> login(
      String loginType, Map<String, String> params) async {
    final endpoint = loginType == 'phone' ? '/login/cellphone' : '/login';
    final queryParams = loginType == 'phone'
        ? {'mobile': params['phone'], 'code': params['code']}
        : {'username': params['username'], 'password': params['password']};

    return await _apiRequest(
      endpoint,
      method: 'POST',
      queryParams: queryParams,
      processResponse: (responseData) {
        _saveAuthData(responseData);
        return responseData;
      },
    );
  }

  /// 手机号登录
  Future<Map<String, dynamic>> loginWithPhone(String phone, String code) async {
    return login('phone', {'phone': phone, 'code': code});
  }

  /// 用户名密码登录
  Future<Map<String, dynamic>> loginWithPassword(
      String username, String password) async {
    return login('password', {'username': username, 'password': password});
  }

  /// 发送验证码
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

  /// 保存认证数据
  void _saveAuthData(Map<String, dynamic> responseData) {
    print('保存认证数据: $responseData');

    final data = responseData['data'] is Map<String, dynamic>
        ? responseData['data'] as Map<String, dynamic>
        : null;

    print('提取的 data: $data');

    if (data != null) {
      if (data['token'] != null) {
        print('从 data 中提取到 token: ${data['token']}');
        _prefs.setString('auth_token', data['token']);
      }

      if (data['userid'] != null) {
        print('从 data 中提取到 userid: ${data['userid']}');
        _prefs.setString('user_id', data['userid'].toString());
      }

      if (data['vip_token'] != null) {
        print('从 data 中提取到 vip_token: ${data['vip_token']}');
        _prefs.setString('vip_token', data['vip_token']);
      }
    } else {
      if (responseData['token'] != null) {
        print('从 responseData 中提取到 token: ${responseData['token']}');
        _prefs.setString('auth_token', responseData['token']);
      }

      if (responseData['userid'] != null) {
        print('从 responseData 中提取到 userid: ${responseData['userid']}');
        _prefs.setString('user_id', responseData['userid'].toString());
      }
    }

    // 检查存储后的值
    final token = _prefs.getString('auth_token');
    final userId = _prefs.getString('user_id');
    print('存储后的 auth_token: $token');
    print('存储后的 user_id: $userId');
  }

  /// 获取用户详细信息
  Future<Map<String, dynamic>> getUserDetail() async {
    print('开始获取用户详细信息...');
    try {
      // 检查用户是否已登录
      _checkAuthentication();

      // 获取当前的 token 和 userId
      final token = _prefs.getString('auth_token');
      final userId = _prefs.getString('user_id');

      // 尝试从本地缓存获取用户信息
      final cachedUserData = _prefs.getString('user_data');
      if (cachedUserData != null) {
        print('从缓存中获取到用户数据');
        try {
          // 尝试解析缓存的用户数据
          final userData = json.decode(cachedUserData);
          return {
            'status': 1,
            'data': userData,
          };
        } catch (e) {
          print('解析缓存的用户数据失败: $e');
          // 继续从服务器获取
        }
      }


      // 直接尝试从服务器获取用户信息
      final result = await _apiRequest('/user/detail');

      // 如果成功，缓存用户数据
      if (result['status'] == 1 && result['data'] != null) {
        _prefs.setString('user_data', json.encode(result['data']));
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// 获取用户VIP详情
  Future<Map<String, dynamic>> getUserVipDetail() async {
    _checkAuthentication();
    return await _apiRequest('/user/vip/detail');
  }

  /// 获取用户歌单列表
  Future<Map<String, dynamic>> getUserPlaylists(
      {bool forceRefresh = false}) async {
    _checkAuthentication();
    return await _apiRequest('/user/playlist',
        checkCache: !forceRefresh, cacheKey: _playlistsCacheKey);
  }

  /// 获取歌单内的所有歌曲
  Future<List<Map<String, dynamic>>> getPlaylistTracks(
    String globalCollectionId, {
    int page = 1,
    int pageSize = 30,
  }) async {
    return await _apiRequest(
      '/playlist/track/all',
      queryParams: {
        'id': globalCollectionId,
        'page': page,
        'pagesize': pageSize,
      },
      processResponse: (responseData) {
        if (responseData['data'] == null) return [];

        final data = responseData['data'];

        // 尝试从songs或info字段获取数据
        if (data['songs'] is List) return _processTrackList(data['songs']);
        if (data['info'] is List) return _processTrackList(data['info']);

        return [];
      },
    );
  }

  // 处理曲目列表
  List<Map<String, dynamic>> _processTrackList(List<dynamic> trackList) {
    return trackList.map((item) {
      if (item is Map) {
        return Map<String, dynamic>.from(item);
      } else {
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
  Future<String> getSongUrl(String hash, String albumId) async {
    return await _apiRequest(
      '/song/url',
      queryParams: {'hash': hash, 'album_id': albumId},
      processResponse: (responseData) {
        // 尝试从主要和备用URL中获取
        final urls =
            responseData['url'] is List ? responseData['url'] as List : null;
        final backupUrls = responseData['backupUrl'] is List
            ? responseData['backupUrl'] as List
            : null;

        if (urls?.isNotEmpty == true) return urls!.first.toString();
        if (backupUrls?.isNotEmpty == true) return backupUrls!.first.toString();

        throw Exception('无法获取歌曲播放地址');
      },
    );
  }

  /// 获取完整的歌词（包含搜索和获取内容）
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

  /// 搜索歌词信息
  Future<Map<String, String>> searchLyric(String hash) async {
    try {
      final response = await _dio.get(
        '/search/lyric',
        queryParameters: {'hash': hash},
      );

      final responseData = response.data;
      if (responseData['status'] == 200 && responseData['candidates'] is List) {
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
    } catch (e) {
      throw _handleError(e, '获取歌词信息失败');
    }
  }

  /// 获取歌词内容
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
        final content =
            responseData['decodeContent'] ?? responseData['content'];
        if (content != null) {
          return content.toString();
        }
      }
      throw Exception('获取歌词内容失败');
    } catch (e) {
      throw _handleError(e, '获取歌词内容失败');
    }
  }

  /// 获取最近播放记录
  Future<RecentSongsResponse> getRecentSongs({
    String? bq,
    bool forceRefresh = false,
  }) async {
    try {
      // 尝试从缓存获取
      if (!forceRefresh) {
        final cachedData = _cacheManager.getValidCache(_recentSongsCacheKey);
        if (cachedData != null) {
          // 在后台刷新缓存
          _cacheManager.refreshInBackground(
              _recentSongsCacheKey, () => fetchRecentSongs(bq: bq));
          return RecentSongsResponse.fromJson(cachedData);
        }
      }

      // 从服务器获取新数据
      return await fetchRecentSongs(bq: bq);
    } catch (e) {
      // 如果请求失败但有缓存，返回缓存
      final cachedData = _cacheManager.getValidCache(_recentSongsCacheKey);
      if (cachedData != null) {
        return RecentSongsResponse.fromJson(cachedData);
      }
      throw Exception('获取最近播放记录失败: $e');
    }
  }

  // 从服务器获取最近播放数据
  Future<RecentSongsResponse> fetchRecentSongs({String? bq}) async {
    final queryParams =
        bq != null && bq.isNotEmpty ? {'bq': bq} : <String, dynamic>{};

    final response =
        await _dio.get('/user/history', queryParameters: queryParams);

    if (response.data['status'] == 1) {
      final Map<String, dynamic> cacheData = {
        'data': response.data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      // 更新缓存
      await _cacheManager.updateCache(_recentSongsCacheKey, cacheData);
      return RecentSongsResponse.fromJson(response.data);
    } else {
      throw Exception(response.data['error_msg'] ?? '获取最近播放记录失败');
    }
  }

  // 获取缓存状态
  Future<Map<String, dynamic>> getCacheStatus() async {
    return await _cacheManager
        .getStatus([_playlistsCacheKey, _recentSongsCacheKey]);
  }

  // 清除过期缓存
  Future<void> clearExpiredCache() async {
    await _cacheManager
        .clearExpired([_playlistsCacheKey, _recentSongsCacheKey]);
  }

  /// 退出登录
  Future<void> logout() async {
    try {
      await _dio.post('/logout');
      clearAuthData();
    } catch (e) {
      rethrow;
    }
  }

  /// 搜索歌曲
  Future<SearchResponse> searchSongs(String keyword,
      {int page = 1, int pageSize = 20}) async {
    return await _apiRequest(
      '/search',
      queryParams: {
        'keywords': keyword,
        'page': page,
        'pagesize': pageSize,
      },
      processResponse: (responseData) => SearchResponse.fromJson(responseData),
    );
  }

  // 检查用户是否已认证
  void _checkAuthentication() {
    final token = _prefs.getString('auth_token');
    print('认证检查 - token: $token');

    // 检查所有存储的认证相关数据
    final userId = _prefs.getString('user_id');
    final vipToken = _prefs.getString('vip_token');
    final vipType = _prefs.getString('vip_type');

    print('认证检查 - userId: $userId');
    print('认证检查 - vipToken: $vipToken');
    print('认证检查 - vipType: $vipType');

    // 检查所有的 SharedPreferences 键
    final allKeys = _prefs.getKeys();
    print('所有存储的键: $allKeys');

    if (token == null) {
      print('认证失败: token 为空');
      throw Exception('未登录或token已失效');
    }
  }

  // 处理Dio异常
  Exception _handleDioError(DioException e) {
    if (e.response?.statusCode == 401) {
      return Exception('未授权或登录已过期');
    }
    return Exception('请求失败，请稍后重试');
  }

  // 通用错误处理方法
  Exception _handleError(dynamic e, String defaultMessage) {
    if (e is DioException) {
      return _handleDioError(e);
    } else if (e is Exception) {
      return e;
    }
    return Exception('$defaultMessage: $e');
  }
}
