import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/provider_manager.dart';
import '../../data/models/models.dart';
import '../../services/api_service.dart';

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
  final ApiService _apiService;
  static const int pageSize = 20;
  SearchController(this._apiService) : super(SearchState());

  /// 执行搜索
  /// @param keyword 搜索关键词
  Future<void> search(String keyword) async {
    if (keyword.isEmpty) {
      state = SearchState();
      return;
    }
    // 避免重复搜索
    if (keyword == state.keyword && state.status != SearchStatus.initial)
      return;
    await _doSearch(keyword, 1, isLoadMore: false);
  }

  Future<void> loadMore() async {
    if (!state.hasMore ||
        state.isLoadingMore ||
        state.status != SearchStatus.success) return;
    await _doSearch(state.keyword, state.page + 1, isLoadMore: true);
  }

  Future<void> _doSearch(String keyword, int page,
      {required bool isLoadMore}) async {
    if (isLoadMore) {
      state = state.copyWith(isLoadingMore: true);
    } else {
      state = SearchState(status: SearchStatus.loading, keyword: keyword);
    }
    try {
      final res = await _apiService.searchSongs(keyword,
          page: page, pageSize: pageSize);
      final List<SearchSong> newSongs = isLoadMore
          ? [...(state.searchResponse?.lists ?? []), ...res.lists]
          : res.lists;
      final merged = SearchResponse(
        lists: newSongs,
        indextotal: res.indextotal,
        correctiontype: res.correctiontype,
        algPath: res.algPath,
      );
      state = state.copyWith(
        status: SearchStatus.success,
        searchResponse: merged,
        page: page,
        hasMore: res.lists.length >= pageSize,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        status: isLoadMore ? state.status : SearchStatus.error,
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
  final apiService = ref.watch(ProviderManager.apiServiceProvider);
  return SearchController(apiService);
});
