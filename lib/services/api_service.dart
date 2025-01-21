import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// API服务类
/// 负责处理所有与后端服务器的HTTP请求
/// 使用Dio作为HTTP客户端，SharedPreferences进行本地数据存储
class ApiService {
  /// 服务器基础URL
  static const String baseUrl = 'http://localhost:3000/';

  /// Dio实例，用于发送HTTP请求
  final Dio _dio;

  /// SharedPreferences实例，用于本地数据存储
  final SharedPreferences _prefs;

  /// 构造函数
  /// @param _prefs SharedPreferences实例，用于存储token等数据
  ApiService(this._prefs) : _dio = Dio() {
    // 配置Dio基本设置
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 5); // 连接超时时间
    _dio.options.receiveTimeout = const Duration(seconds: 3); // 接收超时时间

    // 添加请求/响应拦截器
    _dio.interceptors.add(
      InterceptorsWrapper(
        // 请求拦截器：在每个请求头中添加token
        onRequest: (options, handler) {
          final token = _prefs.getString('auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        // 错误拦截器：处理401认证错误
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // Token过期，清除本地存储的认证信息
            _prefs.remove('auth_token');
            _prefs.remove('user_data');
          }
          return handler.next(error);
        },
      ),
    );
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
        options: Options(
          validateStatus: (status) {
            // print(status);
            return status! < 500 || status == 500 || status == 502;
          },
        ),
      );
      // 解析响应数据
      final responseData = response.data as Map<String, dynamic>;

      // 检查登录状态
      if (responseData['status'] == 1) {
        // 保存token
        final token = responseData['data']?['token'] as String?;
        print(token);
        if (token != null) {
          await _prefs.setString('auth_token', token);
        }
        return responseData;
      }

      // 登录失败抛出异常
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
        options: Options(
          validateStatus: (status) {
            return status! < 500 || status == 500 || status == 502;
          },
        ),
      );
      print('账号密码登录响应: ${response.data}');

      // 解析响应数据
      final responseData = response.data as Map<String, dynamic>;

      // 检查登录状态
      if (responseData['status'] == 1) {
        // 保存token
        final token = responseData['data']?['token'] as String?;
        if (token != null) {
          await _prefs.setString('auth_token', token);
          // 保存用户ID
          final userId = responseData['data']?['userid']?.toString();
          if (userId != null) {
            await _prefs.setString('user_id', userId);
          }
        }
        return responseData;
      }

      // 登录失败抛出异常
      throw Exception(responseData['error_msg'] ?? '登录失败');
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      rethrow;
    }
  }

  /// 刷新登录状态
  /// @param token 可选，当前的token
  /// @param userId 可选，用户ID
  /// @return 返回刷新后的认证信息
  /// @throws Exception 当刷新失败时抛出异常
  Future<Map<String, dynamic>> refreshToken({
    String? token,
    String? userId,
  }) async {
    try {
      final response = await _dio.get(
        '/login/token',
        queryParameters: {
          if (token != null) 'token': token,
          if (userId != null) 'userid': userId,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 发送验证码
  /// @param phone 手机号
  /// @return 返回是否发送成功
  /// @throws Exception 当发送失败时抛出异常
  Future<bool> sendVerificationCode(String phone) async {
    try {
      final response = await _dio.post(
        '/captcha/sent',
        queryParameters: {'mobile': phone},
        options: Options(
          validateStatus: (status) {
            return status! < 500 || status == 500 || status == 502;
          },
        ),
      );
      print('发送验证码响应: ${response.data}');

      if (response.data['status'] == 1) {
        return true;
      } else {
        throw Exception(response.data['data']);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 获取设备ID
  /// @return 返回设备ID字符串
  /// @throws Exception 当获取失败时抛出异常
  Future<String> getDeviceId() async {
    try {
      final response = await _dio.get('/register/dev');
      return response.data['dfid'] as String;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 获取用户详细信息
  /// @return 返回用户详细信息
  /// @throws Exception 当获取失败时抛出异常
  Future<Map<String, dynamic>> getUserDetail() async {
    try {
      print('开始获取用户详细信息');
      final token = _prefs.getString('auth_token');
      if (token == null) {
        throw Exception('未登录或token已失效');
      }

      final response = await _dio.get(
        '/user/detail',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) {
            return status! < 500 || status == 500 || status == 502;
          },
        ),
      );
      print('获取用户详细信息响应: ${response.data}');

      // 检查响应状态
      if (response.statusCode == 502) {
        print('服务器暂时不可用，返回默认用户信息');
        // 返回一个默认的用户信息结构
        return {
          'status': 1,
          'data': {
            'userid': _prefs.getString('user_id'),
            'username': '未知用户',
            'nickname': '未知用户',
            'mobile': '',
            'pic': '',
            'is_vip': 0,
            'vip_type': 0,
          }
        };
      }

      if (response.data['status'] == 1) {
        return response.data;
      } else {
        throw Exception(response.data['error_msg'] ?? '获取用户信息失败');
      }
    } on DioException catch (e) {
      print('获取用户详细信息失败: $e');
      // 如果是服务器错误，返回默认用户信息
      if (e.response?.statusCode == 502) {
        return {
          'status': 1,
          'data': {
            'userid': _prefs.getString('user_id'),
            'username': '未知用户',
            'nickname': '未知用户',
            'mobile': '',
            'pic': '',
            'is_vip': 0,
            'vip_type': 0,
          }
        };
      }
      throw _handleDioError(e);
    }
  }

  /// 获取用户VIP信息
  /// @return 返回用户的VIP信息
  /// @throws Exception 当获取失败时抛出异常
  Future<Map<String, dynamic>> getUserVipInfo() async {
    try {
      print('开始获取用户VIP信息');
      final token = _prefs.getString('auth_token');
      if (token == null) {
        throw Exception('未登录或token已失效');
      }

      final response = await _dio.get(
        '/user/vip/detail',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) {
            return status! < 500 || status == 500 || status == 502;
          },
        ),
      );
      print('获取用户VIP信息响应: ${response.data}');

      // 检查响应状态
      if (response.statusCode == 502) {
        print('服务器暂时不可用，返回默认VIP信息');
        return {
          'status': 1,
          'data': {
            'is_vip': 0,
            'vip_type': 0,
            'vip_begin_time': null,
            'vip_end_time': null,
          }
        };
      }

      if (response.data['status'] == 1) {
        return response.data;
      } else {
        throw Exception(response.data['error_msg'] ?? '获取VIP信息失败');
      }
    } on DioException catch (e) {
      print('获取用户VIP信息失败: $e');
      // 如果是服务器错误，返回默认VIP信息
      if (e.response?.statusCode == 502) {
        return {
          'status': 1,
          'data': {
            'is_vip': 0,
            'vip_type': 0,
            'vip_begin_time': null,
            'vip_end_time': null,
          }
        };
      }
      throw _handleDioError(e);
    }
  }

  /// 退出登录
  /// 清除本地存储的token和用户数据
  /// @throws Exception 当退出失败时抛出异常
  Future<void> logout() async {
    try {
      if (_prefs.getString('auth_token') == null ||
          _prefs.getString('user_id') == null) {
        throw Exception('未登录');
      }

      try {
        await _dio.post('/logout', queryParameters: {
          'token': _prefs.getString('auth_token'),
          'userid': _prefs.getString('user_id'),
        });
      } catch (e) {
        print('服务器退出登录失败: $e');
        // 继续执行本地清理
      }

      // 清除认证信息
      await _prefs.remove('auth_token');
      await _prefs.remove('user_data');
      await _prefs.remove('user_id');
      _dio.options.headers.remove('Authorization');
      _dio.options.queryParameters.clear();
    } catch (e) {
      print('退出登录过程中出错: $e');
      rethrow;
    }
  }

  /// 处理Dio异常
  /// 将Dio的异常转换为用户友好的错误信息
  /// @param e Dio异常
  /// @return 转换后的异常对象
  Exception _handleDioError(DioException e) {
    switch (e.type) {
      // 处理超时错误
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('网络连接超时，请检查网络');

      // 处理响应错误
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

      // 处理请求取消
      case DioExceptionType.cancel:
        return Exception('请求已取消');

      // 处理未知错误
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
