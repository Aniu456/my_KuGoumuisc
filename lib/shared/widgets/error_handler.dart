import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/custom_snackbar.dart';
import '../../core/providers/provider_manager.dart';

/// 简化的错误处理组件
class ErrorHandler {
  /// 处理错误并返回相应的UI组件
  static Widget buildErrorWidget({
    required BuildContext context,
    required String errorMessage,
    VoidCallback? onRetry,
    WidgetRef? ref,
  }) {
    final bool isAuthError = errorMessage.contains('登录') ||
        errorMessage.contains('token') ||
        errorMessage.contains('认证');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              isAuthError ? '登录已失效，请重新登录' : errorMessage,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (onRetry != null && !isAuthError)
                ElevatedButton(onPressed: onRetry, child: const Text('重试')),
              if (onRetry != null && !isAuthError) const SizedBox(width: 16),
              if (isAuthError && ref != null)
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(ProviderManager.isLoggedInProvider);
                    context.go('/login');
                  },
                  child: const Text('去登录'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 处理认证错误
  static void handleAuthenticationError({
    required BuildContext context,
    required WidgetRef ref,
    required String errorMessage,
  }) {
    if (errorMessage.contains('登录') ||
        errorMessage.contains('token') ||
        errorMessage.contains('认证')) {
      ref.invalidate(ProviderManager.isLoggedInProvider);
    }
  }

  /// 处理异步操作
  static Future<void> handleAsyncOperation<T>({
    required BuildContext context,
    required Future<T> future,
    Function(T result)? onSuccess,
    String? loadingMessage,
    String? successMessage,
    String? errorMessage,
  }) async {
    if (loadingMessage != null) {
      AppSnackBar.showInfo(context: context, message: loadingMessage);
    }

    try {
      final result = await future;

      if (context.mounted && successMessage != null) {
        AppSnackBar.showSuccess(context: context, message: successMessage);
      }

      if (onSuccess != null) {
        onSuccess(result);
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(
          context: context,
          message: errorMessage ?? '操作失败: ${e.toString()}',
        );
      }
    }
  }
}
