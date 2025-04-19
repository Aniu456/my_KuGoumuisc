import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/provider_manager.dart';
import '../data/models/models.dart';
import '../features/search/search_controller.dart';
import '../utils/image_utils.dart';

/// 搜索页面
class SearchScreen extends ConsumerStatefulWidget {
  /// 构造函数
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  // 控制器
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 热门标签
  final List<String> _tags = ['热门', '流行', '经典', '伤感', '轻音乐', '摇滚', '粤语', '日语'];

  @override
  void initState() {
    super.initState();
    // 监听滚动以实现加载更多
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // 滚动到底部时加载更多
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final searchState = ref.read(ProviderManager.searchControllerProvider);
      if (!searchState.isLoadingMore && searchState.hasMore) {
        ref.read(ProviderManager.searchControllerProvider.notifier).loadMore();
      }
    }
  }

  // 执行搜索
  void _performSearch() {
    final keyword = _searchController.text.trim();
    if (keyword.isNotEmpty) {
      ref
          .read(ProviderManager.searchControllerProvider.notifier)
          .search(keyword);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听搜索状态和播放服务
    final searchState = ref.watch(ProviderManager.searchControllerProvider);
    final playerService = ref.watch(ProviderManager.playerServiceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('搜索',
            style: TextStyle(color: Colors.black87, fontSize: 18)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black54),
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: _buildSearchBar(),
          ),

          // 内容区域
          Expanded(
            child: searchState.isSearching
                ? const Center(child: CircularProgressIndicator())
                : searchState.hasError
                    ? _buildErrorView(searchState.errorMessage)
                    : searchState.songs.isNotEmpty
                        ? _buildResultsList(searchState, playerService)
                        : _buildInitialView(),
          ),

          // 底部留白，根据是否有歌曲播放动态调整高度
          Consumer(builder: (context, ref, _) {
            final playerService =
                ref.watch(ProviderManager.playerServiceProvider);
            final hasSong = playerService.currentSongInfo != null;
            return SizedBox(height: hasSong ? 65.0 : 16.0);
          }),
        ],
      ),
    );
  }

  // 简化的搜索栏
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索歌曲、歌手、专辑',
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: () {
              _searchController.clear();
              ref
                  .read(ProviderManager.searchControllerProvider.notifier)
                  .clear();
            },
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _performSearch(),
      ),
    );
  }

  // 错误提示部分
  Widget _buildErrorView(String? errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            errorMessage ?? '搜索失败，请重试',
            style: const TextStyle(fontSize: 15),
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: _performSearch,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  // 搜索结果列表
  Widget _buildResultsList(SearchState searchState, playerService) {
    // 获取当前正在播放的歌曲的hash
    final currentPlayingSongHash = playerService.currentSongInfo?.hash;
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: searchState.songs.length + (searchState.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // 加载更多指示器
        if (index == searchState.songs.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        // 歌曲项
        final song = searchState.songs[index];

        // 解析歌曲名和歌手名
        // 服务器返回的格式是: "作者名-歌曲名" (例如: "夏小夏、峰峰疯了 - 天下 (顾不顾将相王侯)(超燃版)")
        String artistName = "";
        String titleName = "";

        if (song.fileName.contains(" - ")) {
          final parts = song.fileName.split(" - ");
          if (parts.length >= 2) {
            artistName = parts[0].trim();
            titleName = parts.sublist(1).join(" - ").trim();
          } else {
            artistName = song.singers.map((s) => s.name).join(', ');
            titleName = song.songName;
          }
        } else {
          artistName = song.singers.map((s) => s.name).join(', ');
          titleName = song.songName;
        }
        
        // 检查该歌曲是否正在播放
        final isPlaying = currentPlayingSongHash != null &&
            PlaySongInfo.fromSearchSong(song).hash == currentPlayingSongHash;

        return Container(
          decoration: BoxDecoration(
            color: isPlaying ? Colors.grey[100] : null,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            leading: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[200],
              ),
              clipBehavior: Clip.antiAlias,
              child: song.image.isNotEmpty
                  ? ImageUtils.createCachedImage(
                      ImageUtils.getThumbnailUrl(song.image),
                      fit: BoxFit.cover,
                    )
                  : const Icon(Icons.music_note, color: Colors.grey),
            ),
            title: Text(
              titleName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isPlaying ? Colors.pink : null,
                fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              artistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isPlaying ? Colors.pink.withOpacity(0.7) : Colors.grey[600],
                fontSize: 12.0,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPlaying)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.volume_up, color: Colors.pink, size: 16.0),
                        const SizedBox(width: 4.0),
                        Text(
                          '正在播放',
                          style: TextStyle(
                            color: Colors.pink,
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    Icons.play_circle_outline,
                    color: isPlaying ? Colors.pink : Colors.grey,
                  ),
                  onPressed: () => _playSong(song, index, searchState, playerService),
                ),
              ],
            ),
            onTap: () => _playSong(song, index, searchState, playerService),
          ),
        );
      },
    );
  }

  // 播放歌曲
  void _playSong(
      SearchSong song, int index, SearchState searchState, playerService) {
    try {
      // 将搜索结果转换为可播放的歌曲信息
      final playSong = PlaySongInfo.fromSearchSong(song);

      // 准备播放列表（包含所有搜索结果）
      final playlist =
          searchState.songs.map((s) => PlaySongInfo.fromSearchSong(s)).toList();
      playerService.preparePlaylist(playlist, index);

      // 播放歌曲
      playerService.play(playSong);

      // 不再导航到播放页面，直接在当前页面播放
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('播放失败: $e')),
      );
    }
  }

  // 初始视图：显示热门标签
  Widget _buildInitialView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '热门搜索',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) => _buildTagChip(tag)).toList(),
          ),
        ],
      ),
    );
  }

  // 标签组件
  Widget _buildTagChip(String tag) {
    return InkWell(
      onTap: () {
        _searchController.text = tag;
        _performSearch();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(tag),
      ),
    );
  }
}
