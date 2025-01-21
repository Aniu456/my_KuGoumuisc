library;

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/auth_service.dart' as service;
import '../../models/user.dart';

/// 认证事件基类
abstract class AuthEvent {
  const AuthEvent();
}

/// 检查认证状态事件
class AuthCheckRequested extends AuthEvent {}

/// 登出请求事件
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// 更新用户信息事件
class AuthUpdateUserInfo extends AuthEvent {
  final Map<String, dynamic> userDetail;
  final Map<String, dynamic> vipInfo;

  const AuthUpdateUserInfo({
    required this.userDetail,
    required this.vipInfo,
  });
}

/// 手机号登录请求事件
class AuthPhoneLoginRequested extends AuthEvent {
  /// 手机号
  final String phone;

  /// 验证码
  final String code;

  /// 构造函数
  AuthPhoneLoginRequested(this.phone, this.code);
}

/// 账号密码登录请求事件
class AuthPasswordLoginRequested extends AuthEvent {
  /// 用户名
  final String username;

  /// 密码
  final String password;

  /// 构造函数
  AuthPasswordLoginRequested(this.username, this.password);
}

/// 认证状态基类
abstract class AuthState {}

/// 初始状态
class AuthInitial extends AuthState {}

/// 已认证状态
class AuthAuthenticated extends AuthState {
  /// 当前登录用户
  final User user;

  /// 构造函数
  AuthAuthenticated(this.user);
}

/// 未认证状态
class AuthUnauthenticated extends AuthState {}

/// 加载中状态
class AuthLoading extends AuthState {}

/// 认证失败状态
class AuthFailure extends AuthState {
  /// 错误信息
  final String message;

  /// 构造函数
  AuthFailure(this.message);
}

/// 认证Bloc类
/// 负责处理所有认证相关的状态管理
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  /// 认证服务实例
  final service.AuthService _authService;

  /// 认证状态变化订阅
  late final StreamSubscription<service.AuthState> _authStateSubscription;

  /// 构造函数
  /// @param authService 认证服务实例
  AuthBloc({
    required service.AuthService authService,
  })  : _authService = authService,
        super(AuthInitial()) {
    // 注册事件处理器
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthPhoneLoginRequested>(_onAuthPhoneLoginRequested);
    on<AuthPasswordLoginRequested>(_onAuthPasswordLoginRequested);
    on<AuthUpdateUserInfo>(_onAuthUpdateUserInfo);

    // 监听AuthService的状态变化
    _authStateSubscription = _authService.authStateChanges.listen(
      (authState) {
        if (authState == service.AuthState.authenticated &&
            _authService.currentUser != null) {
          add(AuthCheckRequested());
        } else if (authState == service.AuthState.unauthenticated) {
          emit(AuthUnauthenticated());
        }
      },
    );
  }

  /// 处理检查认证状态事件
  /// @param event 检查认证状态事件
  /// @param emit 状态发射器
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final user = _authService.currentUser;
    if (user != null) {
      emit(AuthAuthenticated(user));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  /// 处理登出请求事件
  /// @param event 登出请求事件
  /// @param emit 状态发射器
  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());
      await _authService.logout();
      emit(AuthUnauthenticated());
    } catch (e) {
      print('登出失败: $e');
      // 即使登出失败，也要清除本地状态
      emit(AuthUnauthenticated());
    }
  }

  /// 处理手机号登录请求事件
  /// @param event 手机号登录请求事件
  /// @param emit 状态发射器
  Future<void> _onAuthPhoneLoginRequested(
    AuthPhoneLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      // 发射加载状态,表示正在登录中
      emit(AuthLoading());

      // 调用 authService 的手机号登录方法
      await _authService.loginWithPhone(event.phone, event.code);

      // 获取登录后的用户信息
      final user = _authService.currentUser;

      // 判断用户信息是否存在
      if (user != null) {
        // 用户存在,发射认证成功状态
        emit(AuthAuthenticated(user));
      } else {
        // 用户不存在,发射失败状态
        emit(AuthFailure('登录失败'));
      }
    } catch (e) {
      // 捕获异常,发射失败状态并携带错误信息
      emit(AuthFailure(e.toString()));
    }
  }

  /// 处理账号密码登录请求事件
  /// @param event 账号密码登录请求事件
  /// @param emit 状态发射器
  Future<void> _onAuthPasswordLoginRequested(
    AuthPasswordLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());
      await _authService.loginWithPassword(event.username, event.password);
      final user = _authService.currentUser;
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthFailure('登录失败'));
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  /// 处理更新用户信息事件
  /// @param event 更新用户信息事件
  /// @param emit 状态发射器
  Future<void> _onAuthUpdateUserInfo(
    AuthUpdateUserInfo event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      final currentUser = (state as AuthAuthenticated).user;
      final updatedUser = currentUser.copyWith(
        extraInfo: {
          ...?currentUser.extraInfo,
          'userDetail': event.userDetail['data'] ?? event.userDetail,
          'vipInfo': event.vipInfo['data'] ?? event.vipInfo,
        },
      );
      emit(AuthAuthenticated(updatedUser));
    }
  }

  /// 关闭Bloc
  /// 取消认证状态变化订阅
  @override
  Future<void> close() {
    _authStateSubscription.cancel();
    return super.close();
  }
}
