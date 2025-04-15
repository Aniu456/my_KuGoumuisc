import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/skeleton/shimmer_loading.dart';
import '../utils/image_utils.dart';
import '../shared/widgets/custom_dialog.dart';
import '../shared/widgets/error_handler.dart';
import '../core/providers/provider_manager.dart';

/// 歌单页面，用于展示用户的歌单列表
class PlaylistScreen extends ConsumerWidget {
  /// 构造函数
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的歌单'),
        elevation: 0,
        actions: [
          /// 创建歌单按钮
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              /// 弹出提示，创建歌单功能尚未实现
              AppDialog.showInfo(
                context: context,
                message: '创建歌单功能尚未实现',
              );
            },
          ),

          /// 刷新歌单列表按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              /// 强制刷新歌单列表
              ref
                  .read(ProviderManager.playlistProvider.notifier)
                  .loadUserPlaylists(forceRefresh: true);
            },
          ),
        ],
      ),

      /// 歌单内容区域
      body: const _PlaylistContent(),
    );
  }
}

/// 歌单内容组件，包含加载、错误和列表显示
class _PlaylistContent extends ConsumerStatefulWidget {
  /// 构造函数
  const _PlaylistContent();

  @override
  ConsumerState<_PlaylistContent> createState() => _PlaylistContentState();
}

class _PlaylistContentState extends ConsumerState<_PlaylistContent> {
  @override
  void initState() {
    super.initState();

    /// 在组件初始化时加载用户歌单数据
    Future.microtask(() {
      ref.read(ProviderManager.playlistProvider.notifier).loadUserPlaylists();
    });
  }

  @override
  Widget build(BuildContext context) {
    /// 监听歌单状态提供者
    final playlistState = ref.watch(ProviderManager.playlistProvider);

    /// 打印当前歌单状态，用于调试
    print(
        '歌单状态: isLoading=${playlistState.isLoading}, hasError=${playlistState.hasError}, '
        'playlistResponse=${playlistState.playlistResponse != null}, '
        'errorMessage=${playlistState.errorMessage}');

    /// 处理加载状态：当正在加载且没有现有数据时显示加载骨架屏
    if (playlistState.isLoading && playlistState.playlistResponse == null) {
      return _buildLoadingContent();
    }

    /// 处理错误状态：当加载发生错误时显示错误信息和重试按钮
    if (playlistState.hasError) {
      // 使用ErrorHandler处理认证错误
      ErrorHandler.handleAuthenticationError(
        context: context,
        ref: ref,
        errorMessage: playlistState.errorMessage ?? '加载失败',
      );

      // 返回统一的错误UI
      return ErrorHandler.buildErrorWidget(
        context: context,
        errorMessage: playlistState.errorMessage ?? '加载失败',
        ref: ref,
        onRetry: () => ref
            .read(ProviderManager.playlistProvider.notifier)
            .loadUserPlaylists(forceRefresh: true),
      );
    }

    /// 获取歌单响应数据
    final playlistResponse = playlistState.playlistResponse;

    /// 如果没有数据且不在加载，显示空状态提示
    if (playlistResponse == null) {
      return const Center(child: Text('没有歌单数据'));
    }

    /// 合并创建的歌单和收藏的歌单
    final allPlaylists = [
      ...playlistResponse.createdPlaylists,
      ...playlistResponse.collectedPlaylists
    ];

    /// 使用 RefreshIndicator 实现下拉刷新
    return RefreshIndicator(
      onRefresh: () => ref
          .read(ProviderManager.playlistProvider.notifier)
          .loadUserPlaylists(forceRefresh: true),
      child: Column(
        children: [
          /// 展开列表以占据剩余空间
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: allPlaylists.length,
              itemBuilder: (context, index) {
                final playlist = allPlaylists[index];
                return _PlaylistItem(
                  name: playlist.name,
                  songCount: playlist.songCount,
                  coverUrl: playlist.coverUrl,
                  onTap: () {
                    /// 打印出歌单信息，以便调试
                    print(
                        '跳转到歌单: ${playlist.name}, ID: ${playlist.id}，原始ID类型: ${playlist.id.runtimeType}');

                    /// 跳转到音乐列表页面，并传递歌单 ID 和名称
                    context.push(
                      '/music_list',
                      extra: {
                        'playlistId': playlist.id,
                        'playlistName': playlist.name,
                      },
                    );
                  },
                );
              },
            ),
          ),

          /// 底部留白，防止被底部导航栏遮挡
          const SizedBox(height: 70),
        ],
      ),
    );
  }

  /// 构建加载中的骨架屏内容
  Widget _buildLoadingContent() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: List.generate(
        8,
        (index) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 4.0),
          child: ShimmerLoading(
            isLoading: true,
            child: PlaylistItemSkeleton(),
          ),
        ),
      ),
    );
  }
}

/// 单个歌单列表项组件
class _PlaylistItem extends StatelessWidget {
  /// 歌单名称
  final String name;

  /// 歌曲数量
  final int songCount;

  /// 封面URL
  final String? coverUrl;

  /// 点击回调
  final VoidCallback onTap;

  /// 构造函数
  const _PlaylistItem({
    required this.name,
    required this.songCount,
    this.coverUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.grey[300],
        ),
        clipBehavior: Clip.antiAlias,
        child: coverUrl != null && coverUrl!.isNotEmpty
            ? ImageUtils.createCachedImage(
                ImageUtils.getMediumUrl(coverUrl!),
                fit: BoxFit.cover,
              )
            : const Icon(Icons.music_note, color: Colors.white),
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('$songCount 首'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// 歌单项骨架屏
class PlaylistItemSkeleton extends StatelessWidget {
  /// 构造函数
  const PlaylistItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
        ),
      ),
      title: Container(
        height: 16,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: Colors.white,
        ),
      ),
      subtitle: Container(
        height: 12,
        width: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: Colors.white,
        ),
      ),
    );
  }
}
