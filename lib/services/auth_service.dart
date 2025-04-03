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
  /// 包括token、用户ID和用户数据
  Future<void> _loadPersistedAuth() async {
    try {
      _token = _prefs.getString(_tokenKey);
      _userId = _prefs.getString(_userIdKey);

      final userJson = _prefs.getString(_userKey);
      if (userJson != null) {
        print('从缓存加载用户信息: $userJson');
        final Map<String, dynamic> userData = jsonDecode(userJson);

        // 确保 extraInfo 中的 VIP 信息正确
        if (userData['extraInfo'] != null) {
          final extraInfo = userData['extraInfo'] as Map<String, dynamic>;
          if (extraInfo['vipInfo'] != null) {
            final vipInfo = extraInfo['vipInfo'] as Map<String, dynamic>;
            print('缓存的VIP信息: $vipInfo');
          }
        }

        _currentUser = User.fromJson(userData);
        print(
            '用户VIP状态: isVip=${_currentUser!.isVip}, isVipValid=${_currentUser!.isVipValid}');
        print(
            'VIP时间: begin=${_currentUser!.vipBeginTime}, end=${_currentUser!.vipEndTime}');

        _authStateController.add(AuthState.authenticated);
      } else {
        print('未找到缓存的用户信息');
        _authStateController.add(AuthState.unauthenticated);
      }
    } catch (e) {
      print('加载缓存的认证信息失败: $e');
      _authStateController.add(AuthState.unauthenticated);
    }
  }

  /// 使用手机号和验证码登录
  /// @param phone 手机号
  /// @param code 验证码
  Future<void> loginWithPhone(String phone, String code) async {
    try {
      final response = await _apiService.loginWithPhone(phone, code);
      await handleLoginResponse(response);
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
      await handleLoginResponse(response);
    } catch (e) {
      _authStateController.add(AuthState.error);
      rethrow;
    }
  }

  /// 处理登录响应
  /// @param response 登录接口返回的响应数据
  /// @throws Exception 当登录失败或响应格式无效时抛出异常
  Future<void> handleLoginResponse(Map<String, dynamic> response) async {
    if (response['status'] != 1) {
      throw Exception(response['error_msg'] ?? '登录失败');
    }

    print('处理登录响应: $response');
    final data = response['data'] as Map<String, dynamic>;
    final token = data['token'] as String?;
    final userId = data['userid']?.toString();

    if (token == null || userId == null) {
      throw Exception('Invalid response format');
    }

    _token = token;
    _userId = userId;
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_userIdKey, userId);

    // 确定VIP状态
    bool isVip = false;
    if (data['vip_begin_time'] != null && data['vip_end_time'] != null) {
      try {
        final now = DateTime.now();
        final begin = DateTime.parse(data['vip_begin_time']);
        final end = DateTime.parse(data['vip_end_time']);
        isVip = now.isAfter(begin) && now.isBefore(end);
      } catch (e) {
        print('解析VIP时间错误: $e');
      }
    } else if (data['is_vip'] == 1 || data['is_vip'] == true) {
      isVip = true;
    }

    // 构建完整的VIP信息
    final vipInfo = {
      'isVip': isVip,
      'beginTime': data['su_vip_begin_time'] ?? data['vip_begin_time'],
      'endTime': data['su_vip_end_time'] ?? data['vip_end_time'],
    };

    // 创建用户对象
    final user = User(
      userId: userId,
      nickname: data['nickname'] ?? data['username'] ?? userId,
      pic: data['pic'] as String?,
      isVip: isVip,
      token: token,
      serverTime: DateTime.now(),
      vipBeginTime: data['su_vip_begin_time'] as String? ??
          data['vip_begin_time'] as String?,
      vipEndTime:
          data['su_vip_end_time'] as String? ?? data['vip_end_time'] as String?,
      extraInfo: {
        'userDetail': data,
        'vipInfo': vipInfo,
      },
    );

    // 重要：设置当前用户
    _currentUser = user;

    await persistAuth(user, token);
    print('登录成功，用户信息已设置: ${user.toJson()}');
    _authStateController.add(AuthState.authenticated);
  }

  /// 退出登录
  /// 清除本地存储的认证信息并通知服务器
  Future<void> logout() async {
    try {
      print('开始退出登录流程');
      await _apiService.logout();
      await clearAuth();
      _authStateController.add(AuthState.unauthenticated);
      print('退出登录成功');
    } catch (e) {
      print('退出登录失败: $e');
      // 即使退出失败，也要清除本地认证状态
      await clearAuth();
      _authStateController.add(AuthState.unauthenticated);
      rethrow;
    }
  }

  /// 持久化认证信息
  /// @param user 用户实例
  /// @param token 认证token
  Future<void> persistAuth(User user, String token) async {
    // 先保存数据
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_userIdKey, user.userId);

    // 确保缓存完整的用户信息，包括VIP状态
    final userJson = user.toJson();
    if (user.extraInfo != null) {
      userJson['extraInfo'] = user.extraInfo;
    }
    await _prefs.setString(_userKey, jsonEncode(userJson));

    // 确保设置内存中的用户信息
    _token = token;
    _userId = user.userId;
    _currentUser = user;

    print('认证信息已持久化: token=$token, userId=${user.userId}，用户信息已缓存');
  }

  /// 清除本地存储的认证信息
  Future<void> clearAuth() async {
    print('清除认证信息');
    _currentUser = null;
    _token = null;
    _userId = null;

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
