import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/custom_dialog.dart';
import '../features/skeleton/shimmer_loading.dart';
import '../utils/image_utils.dart';
import '../features/auth/profile_controller.dart';
import '../features/skeleton/profile_skeleton.dart';
import '../shared/widgets/error_handler.dart';
import '../core/providers/provider_manager.dart';

/// 个人中心页面，根据用户登录状态显示不同的内容
class ProfileScreen extends ConsumerWidget {
  /// 构造函数
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// 监听用户的登录状态
    final isLoggedIn = ref.watch(ProviderManager.isLoggedInProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        elevation: 0,
        actions: [
          /// 设置按钮
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              /// 弹出提示，设置功能尚未实现
              AppDialog.showInfo(context: context, message: '设置功能尚未实现');
            },
          ),

          /// 仅在用户登录后显示刷新按钮
          if (isLoggedIn)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                /// 刷新用户信息
                ref
                    .read(ProviderManager.profileControllerProvider.notifier)
                    .refreshUserProfile();
              },
            ),
        ],
      ),

      /// 根据登录状态显示不同的页面内容
      body: isLoggedIn ? const _ProfileContent() : const _LoginPrompt(),
    );
  }
}

/// 已登录用户的个人中心内容
class _ProfileContent extends ConsumerStatefulWidget {
  /// 构造函数
  const _ProfileContent();

  @override
  ConsumerState<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<_ProfileContent> {
  @override
  void initState() {
    super.initState();

    /// 在组件初始化时加载用户数据
    Future.microtask(() {
      ref
          .read(ProviderManager.profileControllerProvider.notifier)
          .loadUserProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    /// 监听用户个人信息状态
    final profileState = ref.watch(ProviderManager.profileControllerProvider);

    /// 处理加载状态：当正在加载且没有用户信息时显示骨架屏
    if (profileState.isLoading && profileState.userProfile == null) {
      return ShimmerLoading(
        isLoading: true,
        child: const ProfileSkeleton(),
      );
    }

    /// 处理错误状态
    if (profileState.hasError) {
      final errorMessage = profileState.errorMessage ?? '加载失败';

      // 使用通用错误处理组件处理错误
      ErrorHandler.handleAuthenticationError(
          context: context, ref: ref, errorMessage: errorMessage);

      return ErrorHandler.buildErrorWidget(
        context: context,
        errorMessage: errorMessage,
        ref: ref,
        onRetry: () => ref
            .read(ProviderManager.profileControllerProvider.notifier)
            .refreshUserProfile(),
      );
    }

    /// 获取用户信息
    final userProfile = profileState.userProfile;

    /// 如果没有用户信息且不在加载，显示提示
    if (userProfile == null) {
      return const Center(child: Text('无法加载用户信息'));
    }

    /// 使用 RefreshIndicator 实现下拉刷新用户信息
    return RefreshIndicator(
      onRefresh: () => ref
          .read(ProviderManager.profileControllerProvider.notifier)
          .refreshUserProfile(),
      child: ListView(
        children: [
          /// 用户信息卡片
          ShimmerLoading(
            isLoading: profileState.isLoading,
            child: _buildUserInfoCard(context, userProfile),
          ),

          /// 功能区块
          const SizedBox(height: 24),
          _buildFunctionsSection(context),

          /// 退出登录按钮
          const SizedBox(height: 36),
          _buildLogoutButton(context, ref),
        ],
      ),
    );
  }

  /// 构建用户信息卡片
  Widget _buildUserInfoCard(BuildContext context, UserProfile userProfile) {
    /// 处理用户头像 URL
    final avatarUrl =
        userProfile.avatar != null && userProfile.avatar!.isNotEmpty
            ? ImageUtils.getMediumUrl(userProfile.avatar)
            : null;

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            /// 头像容器
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
              ),
              clipBehavior: Clip.antiAlias,

              /// 显示用户头像，加载中显示 CircularProgressIndicator
              child: avatarUrl != null
                  ? ImageUtils.createCachedImage(
                      avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                  : const Icon(Icons.person, size: 40, color: Colors.white),
            ),
            const SizedBox(width: 20),

            /// 用户昵称和 VIP 标识
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userProfile.nickname,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  /// 显示 VIP 标识
                  if (userProfile.isVip)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'VIP${userProfile.vipType ?? ''}会员',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建功能列表区块
  Widget _buildFunctionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '我的功能',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            _buildFunctionItem(
              icon: Icons.history,
              title: '最近播放',
              onTap: () {
                AppDialog.showInfo(context: context, message: '最近播放功能尚未实现');
              },
            ),
            _buildFunctionItem(
              icon: Icons.cloud_download,
              title: '本地/下载',
              onTap: () {
                AppDialog.showInfo(context: context, message: '本地/下载功能尚未实现');
              },
            ),
            _buildFunctionItem(
              icon: Icons.star,
              title: '我的收藏',
              onTap: () {
                AppDialog.showInfo(context: context, message: '我的收藏功能尚未实现');
              },
            ),
            _buildFunctionItem(
              icon: Icons.library_music,
              title: '我的音乐云盘',
              onTap: () {
                AppDialog.showInfo(context: context, message: '我的音乐云盘功能尚未实现');
              },
            ),
          ],
        ),
      ],
    );
  }

  /// 构建单个功能列表项
  Widget _buildFunctionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  /// 构建退出登录按钮
  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            // 使用ErrorHandler处理退出登录操作
            ErrorHandler.handleAsyncOperation(
              context: context,
              loadingMessage: '正在退出登录...',
              successMessage: '退出登录成功',
              errorMessage: '退出登录失败',
              future: ref.read(ProviderManager.authControllerProvider).logout(),
              onSuccess: (_) {
                ref.invalidate(ProviderManager.isLoggedInProvider);
              },
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text('退出登录'),
        ),
      ),
    );
  }
}

/// 未登录时显示的提示
class _LoginPrompt extends StatelessWidget {
  /// 构造函数
  const _LoginPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          const Text(
            '登录后享受更多功能',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '个性化推荐、收藏歌单、同步播放记录',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            ),
            child: const Text('立即登录'),
          ),
        ],
      ),
    );
  }
}
