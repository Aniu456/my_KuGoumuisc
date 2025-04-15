import 'package:flutter/material.dart';

/// 全局对话框工具类
/// 提供静态方法用于显示各种类型的对话框
class AppDialog {
  /// 显示一个简单的提示对话框
  static Future<void> showInfo({
    required BuildContext context,
    required String message,
    String title = '提示',
    String confirmText = '知道了',
    VoidCallback? onConfirm,
    bool autoClose = true,
  }) async {
    // 创建对话框并显示
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (onConfirm != null) {
                  onConfirm();
                }
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  /// 显示一个确认对话框
  static Future<bool> showConfirm({
    required BuildContext context,
    required String message,
    String title = '确认',
    String confirmText = '确定',
    String cancelText = '取消',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
                if (onCancel != null) {
                  onCancel();
                }
              },
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                if (onConfirm != null) {
                  onConfirm();
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// 显示一个自定义对话框
  static Future<T?> showCustom<T>({
    required BuildContext context,
    required Widget content,
    String? title,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) async {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return AlertDialog(
          title: title != null ? Text(title) : null,
          content: content,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: actions,
        );
      },
    );
  }
}
