import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/loading_indicator.dart';
import '../shared/widgets/error_handler.dart';
import '../core/providers/provider_manager.dart';

/// 登录页面，使用 ConsumerStatefulWidget 以便监听 Riverpod 的状态
class LoginScreen extends ConsumerStatefulWidget {
  /// 构造函数
  const LoginScreen({super.key});

  @override

  /// 创建 LoginScreen 的状态
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

/// LoginScreen 的状态类
class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// 用于管理表单状态的 Key
  final _formKey = GlobalKey<FormState>();

  /// 用户名输入框的控制器
  final _usernameController = TextEditingController();

  /// 密码输入框的控制器
  final _passwordController = TextEditingController();

  /// 控制密码可见性的状态
  bool _isPasswordVisible = false;

  /// 控制加载状态的布尔值
  final bool _isLoading = false;

  @override

  /// 释放资源时调用
  void dispose() {
    /// 释放用户名输入框控制器
    _usernameController.dispose();

    /// 释放密码输入框控制器
    _passwordController.dispose();
    super.dispose();
  }

  /// 切换密码可见性
  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  /// 处理登录流程
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    // 使用ErrorHandler处理登录操作
    ErrorHandler.handleAsyncOperation<bool>(
      context: context,
      loadingMessage: '正在登录...',
      successMessage: '登录成功！',
      errorMessage: '登录失败',
      future:
          ref.read(ProviderManager.authControllerProvider).loginWithPassword(
                _usernameController.text,
                _passwordController.text,
              ),
      onSuccess: (success) {
        if (success) {
          context.go('/home');
        }
      },
    );
  }

  @override

  /// 构建登录页面的 UI
  Widget build(BuildContext context) {
    /// 获取当前主题
    final theme = Theme.of(context);

    /// 返回 Scaffold 作为页面的基本结构
    return Scaffold(
      /// 使用 Stack 组件实现背景和内容的分层显示
      body: Stack(
        children: [
          /// 背景容器，使用渐变色
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.8),
                  theme.colorScheme.primary.withOpacity(0.6),
                ],
              ),
            ),
          ),

          /// 主要内容区域，使用 SafeArea 避免被系统状态栏等遮挡
          SafeArea(
            child: Center(
              /// 使用 SingleChildScrollView 使内容在键盘弹出时可以滚动
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),

                /// 垂直排列的子组件
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    /// 应用 Logo
                    const Icon(
                      Icons.music_note,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),

                    /// 应用名称
                    Text(
                      '音乐播放器',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 48),

                    /// 登录表单
                    _buildLoginForm(theme),

                    const SizedBox(height: 24),

                    /// 第三方登录选项
                    _buildSocialLoginOptions(theme),

                    const SizedBox(height: 24),

                    /// 注册提示
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '还没有账号？',
                          style: TextStyle(color: Colors.white70),
                        ),
                        TextButton(
                          onPressed: () {
                            // 导航到注册页面
                          },
                          child: const Text('立即注册'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          /// 加载指示器，当 _isLoading 为 true 时显示
          if (_isLoading) const LoadingIndicator(),
        ],
      ),
    );
  }

  /// 构建登录表单
  Widget _buildLoginForm(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),

      /// 使用 Form 组件管理表单状态
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            /// 用户名输入框
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: '用户名/手机号',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              /// 校验用户名是否为空
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入用户名或手机号';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            /// 密码输入框
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: '密码',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: _togglePasswordVisibility,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              /// 校验密码是否为空
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入密码';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            /// 登录按钮
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _login,
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

            /// 忘记密码按钮
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // 导航到忘记密码页面
                },
                child: const Text('忘记密码？'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建第三方登录选项
  Widget _buildSocialLoginOptions(ThemeData theme) {
    return Column(
      children: [
        const Text(
          '或者使用以下方式登录',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// 手机号登录按钮
            _socialLoginButton(
              icon: Icons.phone_android,
              label: '手机号',
              onTap: () {
                /// 导航到手机号登录页面
                context.go('/phone-login');
              },
            ),
            const SizedBox(width: 24),

            /// 微信登录按钮
            _socialLoginButton(
              icon: Icons.wechat,
              label: '微信',
              onTap: () {
                // 微信登录逻辑
              },
            ),
            const SizedBox(width: 24),

            /// 扫码登录按钮
            _socialLoginButton(
              icon: Icons.qr_code_scanner,
              label: '扫码',
              onTap: () {
                // 扫码登录逻辑
              },
            ),
          ],
        ),
      ],
    );
  }

  /// 构建单个第三方登录按钮
  Widget _socialLoginButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          /// 社交平台图标容器
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 8),

          /// 社交平台标签
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
