import 'package:equatable/equatable.dart';

/// 认证事件基类
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// 登录请求事件
class AuthLoginRequested extends AuthEvent {
  final Map<String, dynamic> userData;

  const AuthLoginRequested(this.userData);

  @override
  List<Object?> get props => [userData];
}

/// 登出请求事件
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// 更新用户VIP信息事件
class AuthUpdateVipInfo extends AuthEvent {
  final Map<String, dynamic> vipInfo;

  const AuthUpdateVipInfo(this.vipInfo);

  @override
  List<Object?> get props => [vipInfo];
}
