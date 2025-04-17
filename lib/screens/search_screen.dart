import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/provider_manager.dart';
import '../data/models/models.dart';
import '../features/search/search_controller.dart';
import '../features/player/player_page.dart';
import '../utils/image_utils.dart';

// 注意：我们不再需要定义这些Provider，因为我们将使用ProviderManager中的searchControllerProvider

/// 搜索页面
class SearchScreen extends ConsumerStatefulWidget {
  /// 构造函数
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  // 控制器
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 热门标签
  final List<String> _tags = ['热门', '流行', '经典', '伤感', '轻音乐', '摇滚', '粤语', '日语'];

  // 演示用的默认搜索结果，当没有搜索时显示
  final List<Map<String, String>> _results = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final searchState = ref.read(ProviderManager.searchControllerProvider);
      if (!searchState.isLoadingMore && searchState.hasMore) {
        ref.read(ProviderManager.searchControllerProvider.notifier).loadMore();
      }
    }
  }

  void _performSearch() {
    final keyword = _controller.text.trim();
    if (keyword.isNotEmpty) {
      ref
          .read(ProviderManager.searchControllerProvider.notifier)
          .search(keyword);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听搜索状态
    final searchState = ref.watch(ProviderManager.searchControllerProvider);
    final playerService = ref.watch(ProviderManager.playerServiceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('搜索', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 搜索栏
            _buildSearchBar(),
            const SizedBox(height: 16),

            // 根据搜索状态显示不同内容
            Expanded(
              child: _buildContentBySearchState(searchState, playerService),
            ),
          ],
        ),
      ),
    );
  }

  // 根据搜索状态构建不同的内容
  Widget _buildContentBySearchState(SearchState searchState, playerService) {
    // 搜索中状态
    if (searchState.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    // 搜索错误状态
    if (searchState.hasError) {
      return _buildErrorSection(searchState.errorMessage);
    }

    // 搜索结果为空状态
    if (searchState.showEmptyResult) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTagsSection(),
          const SizedBox(height: 20),
          const Center(child: Text('没有找到相关歌曲')),
        ],
      );
    }

    // 搜索成功且有结果状态
    if (searchState.status == SearchStatus.success &&
        searchState.songs.isNotEmpty) {
      return _buildSearchResultsList(searchState, playerService);
    }

    // 初始状态 - 显示标签和推荐列表
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTagsSection(),
      ],
    );
  }

  // 搜索栏组件
  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: '搜索歌曲、歌手、专辑',
                border: InputBorder.none,
                icon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _performSearch,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('搜索'),
        ),
      ],
    );
  }

  // 标签部分
  Widget _buildTagsSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tags
          .map((tag) => GestureDetector(
                onTap: () {
                  _controller.text = tag;
                  _performSearch();
                },
                child: Chip(
                  label: Text(tag),
                  backgroundColor: Colors.grey[100],
                ),
              ))
          .toList(),
    );
  }

  // 错误提示部分
  Widget _buildErrorSection(String? errorMessage) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('搜索失败: ${errorMessage ?? "未知错误"}',
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _performSearch,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  // 搜索结果列表
  Widget _buildSearchResultsList(SearchState searchState, playerService) {
    // 调试输出服务器返回的数据
    print('\n======= 搜索结果数据 ======');
    print('搜索关键词: ${searchState.keyword}');
    print('搜索结果数量: ${searchState.songs.length}');
    print('当前页码: ${searchState.page}');
    print('是否还有更多数据: ${searchState.hasMore}');

    // 输出第一首歌曲的详细信息（如果有的话）
    if (searchState.songs.isNotEmpty) {
      final firstSong = searchState.songs.first;
      print('\n第一首歌曲详情:');
      print(firstSong);
      print('歌曲名: ${firstSong.songName}');
      print('歌手: ${firstSong.singers.map((s) => s.name).join(", ")}');
      print('文件哈希: ${firstSong.fileHash}');
      print('图片URL: ${firstSong.image}');
      print('文件大小: ${firstSong.fileSize}');
      print('MixSongID: ${firstSong.mixSongId}');
      print('时长: ${firstSong.duration} 秒');
      print('==============================\n');
    }
    return ListView.separated(
      controller: _scrollController,
      itemCount: searchState.songs.length + (searchState.isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: Colors.grey[200]),
      itemBuilder: (context, index) {
        // 显示加载更多指示器
        if (index == searchState.songs.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
          );
        }

        final song = searchState.songs[index];
        final singerNames = song.singers.map((s) => s.name).join(', ');

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              color: Colors.grey[300],
              width: 48,
              height: 48,
              child: song.image.isNotEmpty
                  ? ImageUtils.createCachedImage(
                      ImageUtils.getThumbnailUrl(song.image),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.music_note,
                          color: Colors.white70, size: 32),
                    )
                  : const Icon(Icons.music_note,
                      color: Colors.white70, size: 32),
            ),
          ),
          title: Text(
            song.songName,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            singerNames,
            style: const TextStyle(color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.play_circle_outline, color: Colors.pink),
            onPressed: () => _playSong(song, index, searchState, playerService),
          ),
          onTap: () => _playSong(song, index, searchState, playerService),
        );
      },
    );
  }

  // 播放歌曲
  Future<void> _playSong(SearchSong song, int index, SearchState searchState,
      playerService) async {
    try {
      // 将搜索结果转换为可播放的歌曲信息
      final playSong = PlaySongInfo.fromSearchSong(song);

      // 准备播放列表（包含所有搜索结果）
      final playlist =
          searchState.songs.map((s) => PlaySongInfo.fromSearchSong(s)).toList();
      playerService.preparePlaylist(playlist, index);

      // 播放歌曲
      await playerService.play(playSong);

      // 导航到播放页面
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const PlayerPage(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
  }
}
