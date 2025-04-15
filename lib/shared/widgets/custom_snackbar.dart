import 'package:flutter/material.dart';

/// 自定义Snackbar类，用于在应用中显示统一风格的Snackbar消息
class AppSnackBar {
  /// 显示信息类型的Snackbar
  /// @param context 当前上下文
  /// @param message 显示的消息内容
  /// @param duration 显示时长，默认2秒
  static void showInfo({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(
      context: context,
      message: message,
      backgroundColor: Theme.of(context).colorScheme.primary,
      icon: Icons.info_outline,
      duration: duration,
    );
  }

  /// 显示成功类型的Snackbar
  /// @param context 当前上下文
  /// @param message 显示的消息内容
  /// @param duration 显示时长，默认2秒
  static void showSuccess({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(
      context: context,
      message: message,
      backgroundColor: Colors.green,
      icon: Icons.check_circle_outline,
      duration: duration,
    );
  }

  /// 显示错误类型的Snackbar
  /// @param context 当前上下文
  /// @param message 显示的消息内容
  /// @param duration 显示时长，默认3秒
  static void showError({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context: context,
      message: message,
      backgroundColor: Colors.red,
      icon: Icons.error_outline,
      duration: duration,
    );
  }

  /// 显示警告类型的Snackbar
  /// @param context 当前上下文
  /// @param message 显示的消息内容
  /// @param duration 显示时长，默认3秒
  static void showWarning({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context: context,
      message: message,
      backgroundColor: Colors.orange,
      icon: Icons.warning_amber_outlined,
      duration: duration,
    );
  }

  /// 内部方法，用于显示Snackbar
  /// @param context 当前上下文
  /// @param message 显示的消息内容
  /// @param backgroundColor 背景颜色
  /// @param icon 图标
  /// @param duration 显示时长
  static void _show({
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    required IconData icon,
    required Duration duration,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      duration: duration,
      action: SnackBarAction(
        label: '关闭',
        textColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
