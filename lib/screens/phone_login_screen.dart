import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/loading_indicator.dart';
import '../core/providers/provider_manager.dart';

/// 手机号登录页面，使用 ConsumerStatefulWidget 以便监听 Riverpod 的状态
class PhoneLoginScreen extends ConsumerStatefulWidget {
  /// 构造函数
  const PhoneLoginScreen({super.key});

  @override

  /// 创建 PhoneLoginScreen 的状态
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

/// PhoneLoginScreen 的状态类
class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  /// 用于管理表单状态的 Key
  final _formKey = GlobalKey<FormState>();

  /// 手机号输入框的控制器
  final _phoneController = TextEditingController();

  /// 验证码输入框的控制器
  final _codeController = TextEditingController();

  /// 控制加载状态的布尔值
  bool _isLoading = false;

  /// 存储错误消息的状态
  String? _errorMessage;

  /// 验证码倒计时秒数
  int _countdown = 60;

  /// 用于倒计时的 Timer
  Timer? _timer;

  @override

  /// 释放资源时调用
  void dispose() {
    /// 释放手机号输入框控制器
    _phoneController.dispose();

    /// 释放验证码输入框控制器
    _codeController.dispose();

    /// 取消倒计时 Timer
    _timer?.cancel();
    super.dispose();
  }

  /// 发送验证码
  Future<void> _sendVerificationCode() async {
    /// 校验手机号格式
    if (_phoneController.text.length != 11) {
      setState(() {
        _errorMessage = '请输入正确的手机号';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      /// 从 Riverpod 中读取 AuthController
      final authController = ref.read(ProviderManager.authControllerProvider);

      /// 调用发送验证码接口
      final success =
          await authController.sendVerificationCode(_phoneController.text);

      /// 如果发送成功，开始倒计时并显示成功消息
      if (success) {
        setState(() {
          _startCountdown();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('验证码已发送')),
        );
      }
    } catch (e) {
      /// 发送失败，显示错误消息
      setState(() {
        _errorMessage = '发送验证码失败: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 开始倒计时
  void _startCountdown() {
    _countdown = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          /// 倒计时结束，取消 Timer
          _timer?.cancel();
        }
      });
    });
  }

  /// 登录
  Future<void> _login() async {
    /// 校验表单
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      /// 从 Riverpod 中读取 AuthController
      final authController = ref.read(ProviderManager.authControllerProvider);

      /// 调用手机号登录接口
      final success = await authController.loginWithPhone(
        _phoneController.text,
        _codeController.text,
      );

      /// 如果登录成功，跳转到主页
      if (success && mounted) {
        print("登录成功，准备跳转");

        /// 使 isLoggedInProvider 失效，强制重新获取登录状态，触发路由重定向
        ref.invalidate(ProviderManager.isLoggedInProvider);
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          print("准备导航到/home");
          context.go('/home');
        } else {
          print("组件已卸载，无法导航");
        }
      } else {
        print("登录失败或组件已卸载: success=$success, mounted=$mounted");
      }
    } catch (e) {
      /// 登录失败，显示错误消息
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override

  /// 构建手机号登录页面 UI
  Widget build(BuildContext context) {
    /// 获取当前主题
    final theme = Theme.of(context);

    /// 返回 Scaffold 作为页面的基本结构
    return Scaffold(
      appBar: AppBar(
        title: const Text('手机号登录'),
        elevation: 0,
      ),

      /// 使用 Stack 组件实现加载指示器覆盖
      body: Stack(
        children: [
          /// 主要内容区域，使用 SafeArea 避免被系统 UI 遮挡
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),

              /// 使用 Form 组件管理表单状态
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    /// 手机号输入框
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: '手机号',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.phone_android),
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 11,

                      /// 只允许输入数字
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],

                      /// 手机号校验
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入手机号';
                        }
                        if (value.length != 11) {
                          return '请输入正确的手机号';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    /// 验证码输入框和发送按钮
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _codeController,
                            decoration: InputDecoration(
                              labelText: '验证码',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.security),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 6,

                            /// 只允许输入数字
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],

                            /// 验证码校验
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入验证码';
                              }
                              if (value.length < 4) {
                                return '验证码格式错误';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: (_countdown < 60 && _countdown > 0) ||
                                    _isLoading
                                ? null
                                : _sendVerificationCode,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _countdown < 60 && _countdown > 0
                                  ? '重新发送($_countdown)'
                                  : '发送验证码',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    /// 显示错误信息
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: theme.colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    /// 登录按钮
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '登录',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    /// 服务条款提示
                    const SizedBox(height: 24),
                    Text(
                      '登录代表您已同意《用户协议》《隐私政策》',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    /// 返回密码登录
                    const SizedBox(height: 36),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('返回密码登录'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          /// 加载指示器
          if (_isLoading) const LoadingIndicator(),
        ],
      ),
    );
  }
}
