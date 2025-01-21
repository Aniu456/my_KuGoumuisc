import 'package:flutter/material.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/routes.dart';

/// 手机号登录页面
/// 提供手机号+验证码的登录方式
/// 支持响应式布局，在移动端额外显示第三方登录选项
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  /// 手机号输入控制器
  final _phoneController = TextEditingController();

  /// 验证码输入控制器
  final _codeController = TextEditingController();

  /// 是否正在加载中（发送验证码或登录过程中）
  bool _isLoading = false;

  @override
  void dispose() {
    // 释放控制器资源
    _phoneController.dispose();
    _codeController.dispose();
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
                                '手机号登录',
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

                        // 手机号输入框
                        TextField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: '手机号',
                            prefixIcon: Icon(Icons.phone_android),
                            hintText: '请输入手机号',
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(
                            height: Responsive.getDynamicSize(context, 16)),

                        // 验证码输入框和获取按钮
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _codeController,
                                decoration: const InputDecoration(
                                  labelText: '验证码',
                                  prefixIcon: Icon(Icons.lock_outline),
                                  hintText: '请输入验证码',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            SizedBox(
                                width: Responsive.getDynamicSize(context, 16)),
                            ElevatedButton(
                              onPressed:
                                  _isLoading ? null : _getVerificationCode,
                              child: const Text('获取验证码'),
                            ),
                          ],
                        ),
                        SizedBox(
                            height: Responsive.getDynamicSize(context, 32)),

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

                        // 其他登录方式（仅在移动端显示）
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

  /// 构建社交登录按钮
  /// @param icon 按钮图标
  /// @param color 按钮颜色
  /// @return 返回一个带阴影效果的圆形按钮
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

  /// 获取验证码
  /// 验证手机号不为空后发送验证码请求
  Future<void> _getVerificationCode() async {
    if (_phoneController.text.isEmpty) {
      _showError('请输入手机号');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // TODO: 实现获取验证码逻辑
      await Future.delayed(const Duration(seconds: 1)); // 模拟网络请求
      _showSuccess('验证码已发送');
    } catch (e) {
      _showError('获取验证码失败');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 登录方法
  /// 验证输入后调用登录接口
  Future<void> _login() async {
    if (_phoneController.text.isEmpty || _codeController.text.isEmpty) {
      _showError('请输入手机号和验证码');
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

  /// 显示错误提示
  /// @param message 错误信息
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// 显示成功提示
  /// @param message 成功信息
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}
