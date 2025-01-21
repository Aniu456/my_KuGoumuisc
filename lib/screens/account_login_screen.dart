import 'package:flutter/material.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/routes.dart';

class AccountLoginScreen extends StatefulWidget {
  const AccountLoginScreen({super.key});

  @override
  State<AccountLoginScreen> createState() => _AccountLoginScreenState();
}

class _AccountLoginScreenState extends State<AccountLoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundDecoration,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: Responsive.getResponsivePadding(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  child: Padding(
                    padding:
                        EdgeInsets.all(Responsive.getDynamicSize(context, 24)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 返回按钮和标题
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Expanded(
                              child: Text(
                                '账号密码登录',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 48), // 为了保持标题居中
                          ],
                        ),
                        SizedBox(
                            height: Responsive.getDynamicSize(context, 32)),

                        // 用户名输入框
                        TextField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: '用户名',
                            prefixIcon: Icon(Icons.person_outline),
                            hintText: '请输入用户名',
                          ),
                        ),
                        SizedBox(
                            height: Responsive.getDynamicSize(context, 16)),

                        // 密码输入框
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: '密码',
                            prefixIcon: const Icon(Icons.lock_outline),
                            hintText: '请输入密码',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          obscureText: _obscurePassword,
                        ),
                        SizedBox(height: Responsive.getDynamicSize(context, 8)),

                        // 忘记密码
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              // TODO: 实现忘记密码功能
                            },
                            child: const Text('忘记密码？'),
                          ),
                        ),
                        SizedBox(
                            height: Responsive.getDynamicSize(context, 24)),

                        // 登录按钮
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text('登录'),
                          ),
                        ),

                        // 其他登录方式
                        if (Responsive.isMobile(context)) ...[
                          SizedBox(
                              height: Responsive.getDynamicSize(context, 24)),
                          const Text(
                            '其他登录方式',
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(
                              height: Responsive.getDynamicSize(context, 16)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSocialLoginButton(
                                icon: Icons.wechat,
                                color: const Color(0xFF07C160),
                              ),
                              SizedBox(
                                  width:
                                      Responsive.getDynamicSize(context, 24)),
                              _buildSocialLoginButton(
                                icon: Icons.apple,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLoginButton({
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        color: color,
        onPressed: () {
          // TODO: 实现第三方登录
        },
      ),
    );
  }

  Future<void> _login() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('请输入用户名和密码');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // TODO: 实现登录逻辑
      await Future.delayed(const Duration(seconds: 1)); // 模拟网络请求
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } catch (e) {
      _showError('登录失败');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
