import 'dart:async';
import 'api_service.dart';

class SmsService {
  static const int _cooldownDuration = 60;
  final ApiService _apiService;

  SmsService(this._apiService);

  Future<bool> sendVerificationCode(String phoneNumber) async {
    if (!isValidPhoneNumber(phoneNumber)) {
      throw Exception('无效的手机号码');
    }
    return _apiService.sendVerificationCode(phoneNumber);
  }

  bool isValidPhoneNumber(String phoneNumber) {
    // 简单的手机号格式验证
    final RegExp phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    return phoneRegex.hasMatch(phoneNumber);
  }
}
