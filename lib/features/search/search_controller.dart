import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart';
import '../../data/repositories/music_repository.dart';

/// 搜索状态枚举
enum SearchStatus {
  /// 初始状态，未开始搜索
  initial,

  /// 搜索中
  loading,

  /// 搜索成功
  success,

  /// 搜索失败
  error,
}

/// 搜索状态类
class SearchState {
  /// 当前搜索状态
  final SearchStatus status;

  /// 搜索关键词
  final String keyword;

  /// 搜索结果
  final SearchResponse? searchResponse;

  /// 错误信息
  final String? errorMessage;

  /// 当前页码
  final int page;

  /// 是否还有更多数据
  final bool hasMore;

  /// 是否正在加载更多
  final bool isLoadingMore;

  /// 构造函数
  SearchState({
    this.status = SearchStatus.initial,
    this.keyword = '',
    this.searchResponse,
    this.errorMessage,
    this.page = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  /// 复制当前状态并允许修改部分属性
  SearchState copyWith({
    SearchStatus? status,
    String? keyword,
    SearchResponse? searchResponse,
    String? errorMessage,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return SearchState(
      status: status ?? this.status,
      keyword: keyword ?? this.keyword,
      searchResponse: searchResponse ?? this.searchResponse,
      errorMessage: errorMessage ?? this.errorMessage,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  /// 辅助方法：是否需要显示空结果提示
  bool get showEmptyResult {
    return status == SearchStatus.success &&
        searchResponse != null &&
        searchResponse!.lists.isEmpty &&
        keyword.isNotEmpty;
  }

  /// 辅助方法：是否正在搜索
  bool get isSearching => status == SearchStatus.loading && !isLoadingMore;

  /// 辅助方法：是否搜索出错
  bool get hasError => status == SearchStatus.error;

  /// 辅助方法：获取搜索结果列表
  List<SearchSong> get songs => searchResponse?.lists ?? [];
}

/// 搜索控制器
class SearchController extends StateNotifier<SearchState> {
  /// 注入音乐仓库用于获取搜索数据
  final MusicRepository _musicRepository;

  /// 每页显示的数量
  static const int pageSize = 20;

  /// 构造函数
  SearchController(this._musicRepository) : super(SearchState());

  /// 执行搜索
  /// @param keyword 搜索关键词
  Future<void> search(String keyword) async {
    // 如果关键词为空，重置状态
    if (keyword.isEmpty) {
      state = SearchState();
      return;
    }

    // 如果关键词没变且不是初始状态，不重复搜索
    if (keyword == state.keyword && state.status != SearchStatus.initial) {
      return;
    }

    // 设置搜索中状态
    state = SearchState(
      status: SearchStatus.loading,
      keyword: keyword,
    );

    try {
      // 调用仓库执行搜索
      final searchResponse = await _musicRepository.searchSongs(
        keyword,
        page: 1,
        pageSize: pageSize,
      );

      // 更新状态为搜索成功
      state = state.copyWith(
        status: SearchStatus.success,
        searchResponse: searchResponse,
        page: 1,
        hasMore: searchResponse.lists.length >= pageSize,
      );
    } catch (e) {
      // 处理搜索错误
      state = state.copyWith(
        status: SearchStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// 加载更多搜索结果
  Future<void> loadMore() async {
    // 如果没有更多数据，或者正在加载，或者是错误状态，不执行加载
    if (!state.hasMore ||
        state.isLoadingMore ||
        state.status != SearchStatus.success) {
      return;
    }

    // 设置加载更多状态
    state = state.copyWith(isLoadingMore: true);

    try {
      // 计算下一页
      final nextPage = state.page + 1;

      // 调用仓库加载更多
      final moreResults = await _musicRepository.searchSongs(
        state.keyword,
        page: nextPage,
        pageSize: pageSize,
      );

      // 如果没有数据，表示没有更多结果
      if (moreResults.lists.isEmpty) {
        state = state.copyWith(
          hasMore: false,
          isLoadingMore: false,
        );
        return;
      }

      // 合并原有结果和新结果
      final currentSongs = state.searchResponse?.lists ?? [];
      final newSongs = [...currentSongs, ...moreResults.lists];

      // 创建合并后的搜索响应
      final mergedResponse = SearchResponse(
        lists: newSongs,
        indextotal: moreResults.indextotal,
        correctiontype: moreResults.correctiontype,
        algPath: moreResults.algPath,
      );

      // 更新状态
      state = state.copyWith(
        searchResponse: mergedResponse,
        page: nextPage,
        hasMore: moreResults.lists.length >= pageSize,
        isLoadingMore: false,
      );
    } catch (e) {
      // 处理加载更多错误
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 清空搜索状态
  void clear() {
    state = SearchState();
  }
}

/// 搜索控制器提供者
final searchControllerProvider =
    StateNotifierProvider<SearchController, SearchState>((ref) {
  final musicRepository = ref.watch(musicRepositoryProvider);
  return SearchController(musicRepository);
});
