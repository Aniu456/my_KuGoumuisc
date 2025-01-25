import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// API服务类
/// 负责处理所有与后端服务器的HTTP请求
/// 使用Dio作为HTTP客户端，SharedPreferences进行本地数据存储
class ApiService {
  /// 服务器基础URL
  static const String baseUrl = 'http://localhost:3000';

  /// 本地存储的歌单缓存键名
  static const String _playlistsCacheKey = 'playlists_cache';

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

  // 清除所有认证相关数据
  void _clearAuthData() {
    _prefs.remove('auth_token');
    _prefs.remove('user_id');
    _prefs.remove('vip_token');
    _prefs.remove('vip_type');
    _prefs.remove('user_data');
    _clearPlaylistsCache();
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
        return responseData;
      }

      throw Exception(responseData['data'] ?? '登录失败');
    } on DioException catch (e) {
      throw _handleDioError(e);
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
        return responseData;
      }

      throw Exception(responseData['error_msg'] ?? '登录失败');
    } on DioException catch (e) {
      throw _handleDioError(e);
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

  /// 清除歌单缓存
  void _clearPlaylistsCache() {
    _prefs.remove(_playlistsCacheKey);
  }

  /// 获取用户歌单
  /// @param forceRefresh 是否强制刷新，默认false
  /// @return 返回用户歌单
  /// @throws Exception 当获取失败时抛出异常
  Future<Map<String, dynamic>> getUserPlaylists(
      {bool forceRefresh = false}) async {
    try {
      // 如果不是强制刷新，尝试从缓存获取
      if (!forceRefresh) {
        final cachedData = _prefs.getString(_playlistsCacheKey);
        if (cachedData != null) {
          final decoded = json.decode(cachedData);
          return {
            'info': decoded['info'] as List,
            'list_count': decoded['list_count'],
          };
        }
      }

      // 从服务器获取新数据
      final response = await _dio.get('/user/playlist');
      print(response.data);
      if (response.data['status'] == 1) {
        final result = {
          'info': response.data['data']['info'] as List,
          'list_count': response.data['data']['list_count'],
        };

        // 更新缓存
        await _prefs.setString(_playlistsCacheKey, json.encode(result));

        return result;
      } else {
        throw Exception(response.data['data'] ?? '获取用户歌单失败');
      }
    } on DioException catch (e) {
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
}
