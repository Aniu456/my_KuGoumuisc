import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../services/api_service.dart';
import '../widgets/loading_overlay.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _onPhoneLogin() {
    if (_phoneController.text.isEmpty || _codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入手机号和验证码')),
      );
      return;
    }

    // 更新手机号正则表达式，支持所有11位手机号
    final phoneRegExp = RegExp(r'^1\d{10}$');
    if (!phoneRegExp.hasMatch(_phoneController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的手机号')),
      );
      return;
    }

    print('正在尝试登录，手机号: ${_phoneController.text}');
    context.read<AuthBloc>().add(
          AuthPhoneLoginRequested(
            _phoneController.text,
            _codeController.text,
          ),
        );
  }

  void _onPasswordLogin() {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入用户名和密码')),
      );
      return;
    }

    context.read<AuthBloc>().add(
          AuthPasswordLoginRequested(
            _usernameController.text,
            _passwordController.text,
          ),
        );
  }

  Future<void> _sendVerificationCode() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入手机号')),
      );
      return;
    }

    // 更新手机号验证正则表达式，支持所有11位手机号
    final phoneRegExp = RegExp(r'^1\d{10}$');
    if (!phoneRegExp.hasMatch(_phoneController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的手机号')),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);
      print('正在发送验证码，手机号: ${_phoneController.text}');
      final apiService = context.read<ApiService>();
      final success =
          await apiService.sendVerificationCode(_phoneController.text);

      if (success) {
        // 开始倒计时
        setState(() {
          _cooldownSeconds = 60;
          _isLoading = false;
        });
        _startCooldownTimer();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('发送验证码失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送验证码失败: ${e.toString()}')),
        );
      }
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (mounted) {
          setState(() {
            if (_cooldownSeconds > 0) {
              _cooldownSeconds--;
            } else {
              _cooldownTimer?.cancel();
            }
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        print('收到新的认证状态: $state');
        if (state is AuthLoading) {
          setState(() => _isLoading = true);
        } else {
          setState(() => _isLoading = false);
        }

        if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }

        if (state is AuthAuthenticated) {
          // 使用 mounted 检查确保 widget 仍然在树中
          if (!mounted) return;

          print('登录成功处理：用户名: ${state.user.nickname}');

          // 确保在主线程中执行导航
          Future.microtask(() {
            // 显示登录成功提示
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('登录成功'),
                backgroundColor: Colors.green,
              ),
            );

            // 安全地弹出登录页面
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          });
        }
      },
      child: LoadingOverlay(
        isLoading: _isLoading,
        message: '请稍候...',
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              '登录',
              style: TextStyle(color: Colors.black),
            ),
          ),
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  // Logo
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 180,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 登录方式选项卡
                  TabBar(
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Theme.of(context).primaryColor,
                    controller: _tabController,
                    tabs: const [
                      Tab(text: '手机号登录'),
                      Tab(text: '账号密码登录'),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // 登录表单
                  SizedBox(
                    height: 320,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // 手机号登录表单
                        _buildPhoneLoginForm(),
                        // 账号密码登录表单
                        _buildPasswordLoginForm(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneLoginForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: '手机号',
              contentPadding: const EdgeInsets.all(16),
              labelStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: Icon(Icons.phone_android, color: Colors.grey[600]),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).primaryColor),
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '验证码',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon:
                        Icon(Icons.lock_outline, color: Colors.grey[600]),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Theme.of(context).primaryColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 120,
                child: ElevatedButton(
                  onPressed: (_isLoading || _cooldownSeconds > 0)
                      ? null
                      : _sendVerificationCode,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _cooldownSeconds > 0 ? '${_cooldownSeconds}s' : '获取验证码',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _onPhoneLogin,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('登录'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordLoginForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        children: [
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: '手机/邮箱/用户名/酷狗ID',
              labelStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: Icon(Icons.person_outline, color: Colors.grey[600]),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).primaryColor),
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: '密码',
              labelStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[600],
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).primaryColor),
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _onPasswordLogin,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('登录'),
            ),
          ),
        ],
      ),
    );
  }
}
