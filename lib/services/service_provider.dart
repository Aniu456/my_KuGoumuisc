import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'sms_service.dart';

class ServiceProvider {
  late final SharedPreferences _prefs;
  late final ApiService _apiService;
  late final AuthService _authService;
  late final SmsService _smsService;

  // 获取服务实例
  ApiService get apiService => _apiService;
  AuthService get authService => _authService;
  SmsService get smsService => _smsService;

  // 初始化所有服务
  Future<void> initialize() async {
    // 初始化SharedPreferences
    _prefs = await SharedPreferences.getInstance();

    // 初始化API服务
    _apiService = ApiService(_prefs);

    // 初始化认证服务
    _authService = AuthService(_prefs, _apiService);

    // 初始化短信服务
    _smsService = SmsService(_apiService);
  }

  // 释放资源
  void dispose() {
    _authService.dispose();
  }
}
