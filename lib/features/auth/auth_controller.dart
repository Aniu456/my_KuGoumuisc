import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

/// 认证控制器
/// 负责处理登录、注册等认证相关操作
class AuthController extends ChangeNotifier {
  /// 注入 ApiService 实例，用于进行网络请求
  final ApiService _apiService;

  /// 注入 SharedPreferences 实例，用于本地数据存储（如 token）
  final SharedPreferences _prefs;

  /// 构造函数，接收 ApiService 和 SharedPreferences 实例
  AuthController(this._apiService, this._prefs);

  /// 使用用户名和密码登录
  /// @param username 用户名
  /// @param password 密码
  /// @return 登录是否成功
  Future<bool> loginWithPassword(String username, String password) async {
    try {
      print('开始使用用户名和密码登录: $username');

      /// 调用 ApiService 的登录接口
      final response = await _apiService.loginWithPassword(username, password);
      print('登录响应: $response');

      /// 判断登录是否成功
      if (response['status'] == 1) {
        /// 从响应中获取data字段
        final data = response['data'];
        print('登录成功，提取的 data: $data');

        /// 确保data不为null并且包含token
        if (data != null && data['token'] != null) {
          /// 将返回的 token 存储到本地
          await _prefs.setString('auth_token', data['token']);
          print('存储 token: ${data['token']}');

          // 存储用户ID
          if (data['userid'] != null) {
            await _prefs.setString('user_id', data['userid'].toString());
            print('存储 user_id: ${data['userid']}');
          }
        } else if (response['token'] != null) {
          /// 兼容token可能在响应根目录的情况
          await _prefs.setString('auth_token', response['token']);
          print('存储 token(根目录): ${response['token']}');

          // 存储用户ID
          if (response['userid'] != null) {
            await _prefs.setString('user_id', response['userid'].toString());
            print('存储 user_id(根目录): ${response['userid']}');
          }
        }

        // 检查存储后的值
        final storedToken = _prefs.getString('auth_token');
        final storedUserId = _prefs.getString('user_id');
        print('存储后的 auth_token: $storedToken');
        print('存储后的 user_id: $storedUserId');

        /// 通知监听器（Provider）状态已改变，触发 UI 更新
        notifyListeners();

        /// 返回登录成功
        return true;
      }

      /// 如果登录失败，抛出异常，包含错误信息
      throw Exception(response['error_msg'] ?? response['data'] ?? '登录失败');
    } catch (e) {
      /// 捕获异常并重新抛出
      rethrow;
    }
  }

  /// 使用手机号和验证码登录
  /// @param phone 手机号码
  /// @param code 验证码
  /// @return 登录是否成功
  Future<bool> loginWithPhone(String phone, String code) async {
    try {
      print('开始使用手机号登录: $phone');

      /// 调用 ApiService 的登录接口
      final response = await _apiService.loginWithPhone(phone, code);
      print('手机号登录响应: $response');

      /// 判断登录是否成功
      if (response['status'] == 1) {
        /// 从响应中获取data字段
        final data = response['data'];
        print('手机号登录成功，提取的 data: $data');

        /// 确保data不为null并且包含token
        if (data != null && data['token'] != null) {
          /// 将返回的 token 存储到本地
          await _prefs.setString('auth_token', data['token']);
          print('存储 token: ${data['token']}');

          // 存储用户ID
          if (data['userid'] != null) {
            await _prefs.setString('user_id', data['userid'].toString());
            print('存储 user_id: ${data['userid']}');
          }
        } else if (response['token'] != null) {
          /// 兼容token可能在响应根目录的情况
          await _prefs.setString('auth_token', response['token']);
          print('存储 token(根目录): ${response['token']}');

          // 存储用户ID
          if (response['userid'] != null) {
            await _prefs.setString('user_id', response['userid'].toString());
            print('存储 user_id(根目录): ${response['userid']}');
          }
        }

        // 检查存储后的值
        final storedToken = _prefs.getString('auth_token');
        final storedUserId = _prefs.getString('user_id');
        print('存储后的 auth_token: $storedToken');
        print('存储后的 user_id: $storedUserId');

        /// 通知监听器（Provider）状态已改变，触发 UI 更新
        notifyListeners();

        /// 返回登录成功
        return true;
      }

      /// 如果登录失败，抛出异常，包含错误信息
      throw Exception(response['error_msg'] ?? response['data'] ?? '登录失败');
    } catch (e) {
      /// 捕获异常并重新抛出
      rethrow;
    }
  }

  /// 发送手机验证码
  /// @param phone 手机号码
  Future<bool> sendVerificationCode(String phone) async {
    /// 调用 ApiService 的发送验证码接口
    return await _apiService.sendVerificationCode(phone);
  }

  /// 退出登录
  Future<void> logout() async {
    /// 调用 ApiService 的登出接口
    await _apiService.logout();

    /// 移除本地存储的 token
    await _prefs.remove('auth_token');

    /// 通知监听器（Provider）状态已改变，触发 UI 更新（例如跳转到登录页）
    notifyListeners();
  }
}
