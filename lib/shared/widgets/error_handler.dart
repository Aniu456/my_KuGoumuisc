import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/custom_snackbar.dart';
import '../../core/providers/provider_manager.dart';

/// 通用错误处理组件，用于统一处理应用中的各种错误
class ErrorHandler {
  /// 处理错误并返回相应的UI组件
  /// @param context 当前上下文
  /// @param errorMessage 错误消息
  /// @param onRetry 重试回调
  /// @param ref Riverpod引用，用于状态管理
  static Widget buildErrorWidget({
    required BuildContext context,
    required String errorMessage,
    VoidCallback? onRetry,
    WidgetRef? ref,
  }) {
    /// 检查错误信息是否包含认证相关的关键词
    final bool isAuthError = _isAuthenticationError(errorMessage);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
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
              /// 如果有重试回调且不是认证错误，显示重试按钮
              if (onRetry != null && !isAuthError)
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('重试'),
                ),
              if (onRetry != null && !isAuthError) const SizedBox(width: 16),

              /// 如果是认证错误且提供了ref，显示去登录按钮
              if (isAuthError && ref != null)
                ElevatedButton(
                  onPressed: () => _handleAuthError(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: const Text('去登录'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 处理API错误，根据错误类型显示适当的提示
  /// @param context 当前上下文
  /// @param error 捕获的异常
  /// @param fallbackMessage 默认错误消息
  static void handleApiError({
    required BuildContext context,
    required dynamic error,
    String fallbackMessage = '操作失败',
  }) {
    final errorMessage = error.toString();

    if (_isNetworkError(errorMessage)) {
      AppSnackBar.showWarning(
        context: context,
        message: '网络连接错误，请检查网络后重试',
      );
    } else if (_isAuthenticationError(errorMessage)) {
      AppSnackBar.showError(
        context: context,
        message: '登录已失效，请重新登录',
      );
    } else if (_isServerError(errorMessage)) {
      AppSnackBar.showError(
        context: context,
        message: '服务器错误，请稍后重试',
      );
    } else {
      AppSnackBar.showError(
        context: context,
        message: fallbackMessage +
            (errorMessage.isNotEmpty ? ': $errorMessage' : ''),
      );
    }
  }

  /// 处理异步操作中的API错误
  /// @param context 当前上下文
  /// @param future 异步操作
  /// @param onSuccess 成功回调
  /// @param loadingMessage 加载提示
  /// @param successMessage 成功提示
  /// @param errorMessage 错误提示
  static Future<void> handleAsyncOperation<T>({
    required BuildContext context,
    required Future<T> future,
    Function(T result)? onSuccess,
    String? loadingMessage,
    String? successMessage,
    String? errorMessage,
  }) async {
    try {
      if (loadingMessage != null) {
        AppSnackBar.showInfo(
          context: context,
          message: loadingMessage,
        );
      }

      final result = await future;

      if (successMessage != null) {
        AppSnackBar.showSuccess(
          context: context,
          message: successMessage,
        );
      }

      if (onSuccess != null) {
        onSuccess(result);
      }
    } catch (e) {
      handleApiError(
        context: context,
        error: e,
        fallbackMessage: errorMessage ?? '操作失败',
      );
    }
  }

  /// 自动处理登录过期的情况
  /// @param context 当前上下文
  /// @param ref Riverpod引用
  /// @param errorMessage 错误消息
  static void handleAuthenticationError({
    required BuildContext context,
    required WidgetRef ref,
    required String errorMessage,
  }) {
    if (_isAuthenticationError(errorMessage)) {
      Future.microtask(() async {
        try {
          final authController =
              ref.read(ProviderManager.authControllerProvider);
          await authController.logout();
          ref.invalidate(ProviderManager.isLoggedInProvider);

          if (context.mounted) {
            AppSnackBar.showInfo(
              context: context,
              message: '登录状态已过期，请重新登录',
            );
            context.go('/login');
          }
        } catch (e) {
          if (context.mounted) {
            AppSnackBar.showError(
              context: context,
              message: '自动登出失败，请手动退出重新登录',
            );
          }
        }
      });
    }
  }

  /// 私有方法：处理认证错误
  static Future<void> _handleAuthError(
      BuildContext context, WidgetRef ref) async {
    try {
      final authController = ref.read(ProviderManager.authControllerProvider);
      await authController.logout();
      ref.invalidate(ProviderManager.isLoggedInProvider);

      if (context.mounted) {
        AppSnackBar.showInfo(
          context: context,
          message: '请重新登录',
        );
        context.go('/login');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(
          context: context,
          message: '操作失败，请手动退出重新登录',
        );
      }
    }
  }

  /// 私有方法：检查是否是认证错误
  static bool _isAuthenticationError(String errorMessage) {
    return errorMessage.contains('认证') ||
        errorMessage.contains('登录') ||
        errorMessage.contains('401') ||
        errorMessage.contains('token') ||
        errorMessage.contains('授权') ||
        errorMessage.contains('未登录');
  }

  /// 私有方法：检查是否是网络错误
  static bool _isNetworkError(String errorMessage) {
    return errorMessage.contains('网络') ||
        errorMessage.contains('连接') ||
        errorMessage.contains('超时') ||
        errorMessage.contains('network') ||
        errorMessage.contains('connect') ||
        errorMessage.contains('timeout');
  }

  /// 私有方法：检查是否是服务器错误
  static bool _isServerError(String errorMessage) {
    return errorMessage.contains('500') ||
        errorMessage.contains('502') ||
        errorMessage.contains('503') ||
        errorMessage.contains('504') ||
        errorMessage.contains('服务器');
  }
}
