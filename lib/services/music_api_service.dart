import 'package:dio/dio.dart';
import '../models/user.dart';

class MusicApiService {
  static const String baseUrl = 'http://8.148.7.143:3000';
  final Dio _dio;
  String? _token;
  String? _userId;

  MusicApiService() : _dio = Dio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 3);
  }

  // 设置认证信息
  void setAuthInfo(String token, String userId) {
    _token = token;
    _userId = userId;
    _dio.options.queryParameters = {
      'token': token,
      'userid': userId,
    };
  }

  // 手机号登录
  Future<Map<String, dynamic>> loginWithPhone(
      String mobile, String code) async {
    try {
      final response = await _dio.get(
        '/login/cellphone',
        queryParameters: {
          'mobile': mobile,
          'code': code,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // 账号密码登录
  Future<Map<String, dynamic>> loginWithPassword(
    String username,
    String password,
  ) async {
    try {
      final response = await _dio.get(
        '/login',
        queryParameters: {
          'username': username,
          'password': password,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // 发送验证码
  Future<bool> sendVerificationCode(String mobile) async {
    try {
      final response = await _dio.get(
        '/captcha/sent',
        queryParameters: {'mobile': mobile},
      );
      return response.data['code'] == 200;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // 刷新登录状态
  Future<void> refreshToken() async {
    if (_token == null || _userId == null) {
      throw Exception('未登录');
    }

    try {
      await _dio.get('/login/token');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // 获取用户详情
  Future<Map<String, dynamic>> getUserDetail() async {
    try {
      final response = await _dio.get('/user/detail');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // 获取用户VIP信息
  Future<Map<String, dynamic>> getUserVipInfo() async {
    try {
      final response = await _dio.get('/user/vip/detail');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // 获取用户歌单
  Future<List<Map<String, dynamic>>> getUserPlaylists({
    int page = 1,
    int pageSize = 30,
  }) async {
    try {
      final response = await _dio.get(
        '/user/playlist',
        queryParameters: {
          'page': page,
          'pagesize': pageSize,
        },
      );
      return List<Map<String, dynamic>>.from(response.data['playlists'] ?? []);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // 微信登录 - 生成二维码
  Future<Map<String, dynamic>> createWxLoginQR() async {
    try {
      final response = await _dio.get('/login/wx/create');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // 微信登录 - 检查扫码状态
  Future<Map<String, dynamic>> checkWxLoginStatus(String uuid) async {
    try {
      final response = await _dio.get(
        '/login/wx/check',
        queryParameters: {
          'uuid': uuid,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // 处理Dio错误
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
}
