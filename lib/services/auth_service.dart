import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';

/// 认证服务类
/// 负责处理用户认证相关的所有操作
/// 包括登录、登出、token管理、认证状态管理等
class AuthService {
  /// 本地存储的token键名
  static const String _tokenKey = 'auth_token';

  /// 本地存储的用户数据键名
  static const String _userKey = 'user_data';

  /// 本地存储的设备ID键名
  static const String _deviceIdKey = 'device_id';

  /// 本地存储的用户ID键名
  static const String _userIdKey = 'user_id';

  /// SharedPreferences实例，用于本地数据存储
  final SharedPreferences _prefs;

  /// API服务实例，用于网络请求
  final ApiService _apiService;

  /// 当前登录的用户实例
  User? _currentUser;

  /// 当前的认证token
  String? _token;

  /// 设备唯一标识
  String? _deviceId;

  /// 当前用户ID
  String? _userId;

  /// 认证状态流控制器
  /// 用于广播认证状态的变化
  final _authStateController = StreamController<AuthState>.broadcast();

  /// 认证状态流，用于监听认证状态变化
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  /// 构造函数
  /// @param _prefs SharedPreferences实例
  /// @param _apiService API服务实例
  AuthService(this._prefs, this._apiService) {
    _loadPersistedAuth();
  }

  /// 获取当前登录的用户
  User? get currentUser => _currentUser;

  /// 获取当前的认证token
  String? get token => _token;

  /// 获取当前用户ID
  String? get userId => _userId;

  /// 判断用户是否已登录
  bool get isAuthenticated => _currentUser != null && _token != null;

  /// 加载本地存储的认证信息
  /// 包括token、用户ID、设备ID和用户数据
  Future<void> _loadPersistedAuth() async {
    try {
      _token = _prefs.getString(_tokenKey);
      _userId = _prefs.getString(_userIdKey);
      _deviceId = _prefs.getString(_deviceIdKey);

      final userJson = _prefs.getString(_userKey);
      if (userJson != null) {
        _currentUser = User.fromJson(
          Map<String, dynamic>.from(
            jsonDecode(userJson),
          ),
        );
        // 刷新登录状态
        await refreshAuth();
        _authStateController.add(AuthState.authenticated);
      } else {
        _authStateController.add(AuthState.unauthenticated);
      }
    } catch (e) {
      _authStateController.add(AuthState.unauthenticated);
    }
  }

  /// 刷新认证状态
  /// 使用当前的token和用户ID请求新的认证信息
  Future<void> refreshAuth() async {
    if (_token == null || _userId == null) return;

    try {
      final response = await _apiService.refreshToken(
        token: _token,
        userId: _userId,
      );
      await _handleLoginResponse(response);
    } catch (e) {
      _authStateController.add(AuthState.error);
      rethrow;
    }
  }

  /// 使用手机号和验证码登录
  /// @param phone 手机号
  /// @param code 验证码
  Future<void> loginWithPhone(String phone, String code) async {
    try {
      // // 确保有设备ID
      // try {
      //   await _ensureDeviceId();
      //   if (_deviceId == null) {
      //     throw Exception('设备ID为空');
      //   }
      // } catch (e) {
      //   throw Exception('获取设备ID失败，请稍后重试');
      // }
      final response = await _apiService.loginWithPhone(phone, code);
      print(response);
      await _handleLoginResponse(response);

      // 获取额外信息
      await _fetchUserExtraInfo();
    } catch (e) {
      _authStateController.add(AuthState.error);
      rethrow;
    }
  }

  /// 使用账号密码登录
  /// @param username 用户名
  /// @param password 密码
  Future<void> loginWithPassword(String username, String password) async {
    try {
      final response = await _apiService.loginWithPassword(username, password);
      print('密码登录响应: $response');

      // 检查响应状态
      if (response['status'] != 1) {
        throw Exception(response['error_msg'] ?? '登录失败');
      }

      final data = response['data'] as Map<String, dynamic>;
      final token = data['token'] as String?;
      final userId = data['userid']?.toString();

      if (token == null || userId == null) {
        throw Exception('登录响应格式无效');
      }

      _userId = userId;
      await _prefs.setString(_userIdKey, userId);

      // 创建基础用户信息
      final user = User(
        userId: userId,
        nickname: data['nickname'] ?? data['username'] ?? userId,
        pic: data['pic'] as String?,
        isVip: data['is_vip'] == 1,
        token: token,
        serverTime: DateTime.now(),
        vipToken: data['vip_token'] as String?,
        vipBeginTime: data['vip_begin_time'] as String?,
        vipEndTime: data['vip_end_time'] as String?,
        extraInfo: {
          'userDetail': data,
          'vipInfo': {
            'is_vip': data['is_vip'] ?? 0,
            'vip_type': data['vip_type'] ?? 0,
            'vip_begin_time': data['vip_begin_time'],
            'vip_end_time': data['vip_end_time'],
          },
        },
      );

      await _persistAuth(user, token);
      _authStateController.add(AuthState.authenticated);

      // 获取额外信息
      await _fetchUserExtraInfo();
    } catch (e) {
      print('密码登录失败: $e');
      _authStateController.add(AuthState.error);
      rethrow;
    }
  }

  /// 确保设备ID存在
  /// 如果本地没有存储设备ID，则从服务器获取新的设备ID
  Future<void> _ensureDeviceId() async {
    if (_deviceId == null) {
      _deviceId = await _apiService.getDeviceId();
      await _prefs.setString(_deviceIdKey, _deviceId!);
    }
  }

  /// 获取用户的额外信息
  /// 包括用户详细信息和VIP信息
  Future<void> _fetchUserExtraInfo() async {
    try {
      print('开始获取用户额外信息');
      // 获取用户详细信息
      final userDetail = await _apiService.getUserDetail();
      print('用户详细信息: $userDetail');

      // 获取VIP信息
      final vipInfo = await _apiService.getUserVipInfo();
      print('VIP信息: $vipInfo');

      // 更新用户信息
      if (_currentUser != null) {
        final updatedUser = _currentUser!.copyWith(
          extraInfo: {
            ...?_currentUser!.extraInfo,
            'userDetail': userDetail['data'] ?? userDetail,
            'vipInfo': vipInfo['data'] ?? vipInfo,
          },
        );
        await _persistAuth(updatedUser, _token!);
        print('用户额外信息更新成功');
      }
    } catch (e) {
      // 获取额外信息失败不影响登录状态
      print('获取用户额外信息失败: $e');
    }
  }

  /// 处理登录响应
  /// @param response 登录接口返回的响应数据
  /// @throws Exception 当登录失败或响应格式无效时抛出异常
  Future<void> _handleLoginResponse(Map<String, dynamic> response) async {
    if (response['status'] != 1) {
      throw Exception(response['error_msg'] ?? '登录失败');
    }

    final data = response['data'] as Map<String, dynamic>;
    final token = data['token'] as String?;
    final userId = data['userid']?.toString();

    if (token == null || userId == null) {
      throw Exception('Invalid response format');
    }

    _userId = userId;
    await _prefs.setString(_userIdKey, userId);

    final user = User(
      userId: userId,
      nickname: data['nickname'] ?? data['username'] ?? userId,
      pic: data['pic'] as String?,
      isVip: data['is_vip'] == 1,
      token: token,
      serverTime: DateTime.now(),
      vipToken: data['vip_token'] as String?,
      vipBeginTime: data['vip_begin_time'] as String?,
      vipEndTime: data['vip_end_time'] as String?,
      extraInfo: {
        'userDetail': data,
        'vipInfo': {
          'is_vip': data['is_vip'] ?? 0,
          'vip_type': data['vip_type'] ?? 0,
          'vip_begin_time': data['vip_begin_time'],
          'vip_end_time': data['vip_end_time'],
        },
      },
    );

    await _persistAuth(user, token);
    _authStateController.add(AuthState.authenticated);
  }

  /// 退出登录
  /// 清除本地存储的认证信息并通知服务器
  Future<void> logout() async {
    try {
      print('开始退出登录流程');
      await _apiService.logout();
      await _clearAuth();
      _authStateController.add(AuthState.unauthenticated);
      print('退出登录成功');
    } catch (e) {
      print('退出登录失败: $e');
      // 即使退出失败，也要清除本地认证状态
      await _clearAuth();
      _authStateController.add(AuthState.unauthenticated);
      rethrow;
    }
  }

  /// 持久化认证信息
  /// @param user 用户实例
  /// @param token 认证token
  Future<void> _persistAuth(User user, String token) async {
    _currentUser = user;
    _token = token;

    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  /// 清除本地存储的认证信息
  /// 注意：不会清除设备ID
  Future<void> _clearAuth() async {
    print('清除认证信息');
    _currentUser = null;
    _token = null;
    _userId = null;
    // 保留设备ID

    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);
    await _prefs.remove(_userIdKey);
    print('认证信息清除完成');
  }

  /// 释放资源
  void dispose() {
    _authStateController.close();
  }
}

/// 认证状态枚举
/// initial: 初始状态
/// authenticated: 已认证
/// unauthenticated: 未认证
/// error: 发生错误
enum AuthState {
  initial,
  authenticated,
  unauthenticated,
  error,
}
