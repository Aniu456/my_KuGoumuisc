import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/music_repository.dart';
import '../data/models/models.dart';

/// 搜索状态枚举
enum SearchState {
  initial, // 初始状态，显示搜索提示
  searching, // 搜索中，显示加载指示器
  results, // 搜索到结果，显示结果列表
  noResults, // 没有搜索到结果，显示无结果提示
  error, // 搜索过程中发生错误，显示错误提示
}

/// 提供搜索关键词的状态
final searchQueryProvider = StateProvider<String>((ref) => '');

/// 提供搜索状态的状态
final searchStateProvider =
    StateProvider<SearchState>((ref) => SearchState.initial);

/// 提供搜索结果的 FutureProvider
final searchResultsProvider =
    FutureProvider.autoDispose<SearchResponse>((ref) async {
  final query = ref.watch(searchQueryProvider);

  /// 如果搜索关键词为空，将状态设置为初始状态并抛出异常
  if (query.isEmpty) {
    ref.read(searchStateProvider.notifier).state = SearchState.initial;
    throw Exception('搜索关键词不能为空');
  }

  /// 设置搜索状态为搜索中
  ref.read(searchStateProvider.notifier).state = SearchState.searching;

  try {
    /// 从 Riverpod 中读取 MusicRepository
    final repository = ref.read(musicRepositoryProvider);

    /// 调用 repository 的搜索歌曲方法
    final results = await repository.searchSongs(query);

    /// 根据搜索结果是否为空更新搜索状态
    ref.read(searchStateProvider.notifier).state =
        results.lists.isEmpty ? SearchState.noResults : SearchState.results;

    /// 返回搜索结果
    return results;
  } catch (e) {
    /// 搜索失败，设置搜索状态为错误
    ref.read(searchStateProvider.notifier).state = SearchState.error;
    throw Exception('搜索失败: $e');
  }
});

/// 搜索页面
class SearchScreen extends ConsumerWidget {
  /// 构造函数
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// 监听搜索状态
    final searchState = ref.watch(searchStateProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: _SearchBar(), // 搜索栏组件
      ),

      /// 使用 IndexedStack 根据不同的搜索状态显示不同的内容
      body: IndexedStack(
        index: searchState.index, // 使用搜索状态的 index 来控制显示哪个子 Widget
        children: const [
          _InitialContent(), // 初始内容，显示搜索提示
          _LoadingContent(), // 加载中内容，显示加载指示器
          _ResultsContent(), // 搜索结果内容，显示搜索到的歌曲列表
          _NoResultsContent(), // 无结果内容，显示未找到相关内容提示
          _ErrorContent(), // 错误内容，显示搜索失败提示
        ],
      ),
    );
  }
}

/// 搜索栏组件
class _SearchBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// 获取当前的搜索关键词
    final currentQuery = ref.watch(searchQueryProvider);

    /// 创建 TextEditingController 并设置初始文本为当前的搜索关键词
    final controller = TextEditingController(text: currentQuery);

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: '搜索歌曲、歌手、专辑',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        prefixIcon: const Icon(Icons.search),

        /// 清除搜索框内容的按钮
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            controller.clear();

            /// 清空搜索关键词
            ref.read(searchQueryProvider.notifier).state = '';
          },
        ),
      ),
      textInputAction: TextInputAction.search,

      /// 用户提交搜索关键词时的回调
      onSubmitted: (value) {
        /// 更新搜索关键词
        ref.read(searchQueryProvider.notifier).state = value;
      },
    );
  }
}

/// 初始搜索提示内容
class _InitialContent extends StatelessWidget {
  /// 构造函数
  const _InitialContent();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '搜索你喜欢的音乐',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// 搜索加载中内容
class _LoadingContent extends ConsumerWidget {
  /// 构造函数
  const _LoadingContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

/// 搜索结果内容
class _ResultsContent extends ConsumerWidget {
  /// 构造函数
  const _ResultsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// 监听搜索结果 FutureProvider
    final results = ref.watch(searchResultsProvider);

    return results.when(
      data: (data) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: data.lists.length,
          itemBuilder: (context, index) {
            final song = data.lists[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.music_note, color: Colors.white),
              ),
              title: Text(song.songName),
              subtitle: Text(
                song.singers.isNotEmpty ? song.singers.first.name : '未知歌手',
              ),
              trailing: const Icon(Icons.more_vert),
              onTap: () {
                // TODO: 处理歌曲点击播放
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('搜索失败，请重试')),
    );
  }
}

/// 无搜索结果内容
class _NoResultsContent extends ConsumerWidget {
  /// 构造函数
  const _NoResultsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// 获取当前的搜索关键词
    final query = ref.watch(searchQueryProvider);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '未找到"$query"相关内容',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// 搜索错误内容
class _ErrorContent extends ConsumerWidget {
  /// 构造函数
  const _ErrorContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          const Text(
            '搜索过程中出现错误',
            style: TextStyle(
              fontSize: 16,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // TODO: 实现重试搜索功能
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
