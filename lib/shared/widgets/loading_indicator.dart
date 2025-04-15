import 'package:flutter/material.dart';

/// 全屏加载指示器
/// 显示一个半透明背景和加载动画
class LoadingIndicator extends StatelessWidget {
  final Color? backgroundColor;
  final Color? indicatorColor;
  final String? message;

  const LoadingIndicator({
    super.key,
    this.backgroundColor,
    this.indicatorColor,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: backgroundColor ?? Colors.black.withOpacity(0.3),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                indicatorColor ?? theme.colorScheme.primary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
