import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_service.dart';
import '../../core/providers/provider_manager.dart';

/// 用户信息加载状态
enum ProfileLoadState {
  /// 初始状态，尚未开始加载
  initial,

  /// 加载中状态
  loading,

  /// 加载成功状态
  loaded,

  /// 加载失败状态
  error,
}

/// 用户个人信息模型
class UserProfile {
  /// 用户ID
  final String userId;

  /// 用户昵称
  final String nickname;

  /// 用户头像URL，可能为空
  final String? pic;

  /// 用户个性昵称，可能为空
  final String? knickname;

  /// 用户性别，可能为空
  final String? gender;

  /// 是否是VIP用户，默认为false
  final bool isVip;

  /// VIP类型，可能为空
  final String? vipType;

  /// 构造函数，初始化用户信息
  UserProfile({
    required this.userId,
    required this.nickname,
    this.pic,
    this.knickname,
    this.gender,
    this.isVip = false,
    this.vipType,
  });

  /// 从 JSON 数据创建 UserProfile 实例
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      /// 从 JSON 中获取用户ID，如果为空则使用空字符串
      userId: json['userid']?.toString() ?? '',

      /// 从 JSON 中获取用户昵称，如果为空则使用 '未知用户'
      nickname: json['nickname'] ?? '未知用户',

      /// 从 JSON 中获取头像URL
      pic: json['pic'],

      /// 从 JSON 中获取个性昵称
      knickname: json['k_nickname'],

      /// 解析性别信息
      gender: _parseGender(json['gender']),

      /// 判断是否是VIP用户
      isVip: json['is_vip'] != null && json['is_vip'] == '1',

      /// 获取VIP类型
      vipType: json['vip_type']?.toString(),
    );
  }

  /// 解析性别字段
  static String? _parseGender(dynamic gender) {
    if (gender == null) return null;
    final genderStr = gender.toString();
    if (genderStr == '1') return '男';
    if (genderStr == '2') return '女';
    return null;
  }
}

/// 用户个人信息状态
class ProfileState {
  /// 用户信息加载状态
  final ProfileLoadState loadState;

  /// 用户个人信息，可能为空
  final UserProfile? userProfile;

  /// 错误消息，可能为空
  final String? errorMessage;

  /// 构造函数，初始化 ProfileState
  ProfileState({
    this.loadState = ProfileLoadState.initial,
    this.userProfile,
    this.errorMessage,
  });

  /// 复制当前状态并允许修改部分属性
  ProfileState copyWith({
    ProfileLoadState? loadState,
    UserProfile? userProfile,
    String? errorMessage,
  }) {
    return ProfileState(
      loadState: loadState ?? this.loadState,
      userProfile: userProfile ?? this.userProfile,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// 是否正在加载
  bool get isLoading => loadState == ProfileLoadState.loading;

  /// 是否发生错误
  bool get hasError => loadState == ProfileLoadState.error;

  /// 是否加载成功
  bool get isLoaded => loadState == ProfileLoadState.loaded;
}

/// 用户个人信息控制器
class ProfileController extends StateNotifier<ProfileState> {
  /// 注入 ApiService 实例，用于进行网络请求
  final ApiService _apiService;

  /// 构造函数，接收 ApiService 实例并初始化状态
  ProfileController(this._apiService) : super(ProfileState());

  /// 加载用户个人信息
  /// @param forceRefresh 是否强制刷新，默认为 false
  Future<void> loadUserProfile({bool forceRefresh = false}) async {
    try {
      /// 如果当前正在加载，则直接返回，防止重复加载
      if (state.isLoading) return;

      /// 设置加载状态为 loading
      state = state.copyWith(loadState: ProfileLoadState.loading);

      /// 调用 ApiService 获取用户详细信息
      final response = await _apiService.getUserDetail();

      /// 判断请求是否成功且返回数据不为空
      if (response['status'] == 1 && response['data'] != null) {
        /// 从返回的 JSON 数据创建 UserProfile 实例
        final userProfile = UserProfile.fromJson(response['data']);

        /// 更新状态为 loaded，并设置用户信息
        state = state.copyWith(
          loadState: ProfileLoadState.loaded,
          userProfile: userProfile,
        );
      } else {
        /// 如果请求失败或没有数据，抛出异常
        throw Exception(response['error_msg'] ?? '获取用户信息失败');
      }
    } catch (e) {
      /// 捕获异常，并更新状态为 error，设置错误信息
      state = state.copyWith(
        loadState: ProfileLoadState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// 刷新用户信息
  Future<void> refreshUserProfile() async {
    /// 调用 loadUserProfile 方法，并强制刷新
    await loadUserProfile(forceRefresh: true);
  }
}

/// 个人信息控制器提供者
@Deprecated('请使用ProviderManager.profileControllerProvider')
final profileControllerProvider =

    /// 创建一个 StateNotifierProvider，用于提供 ProfileController 实例
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
  /// 从容器中获取 ApiService 实例
  final apiService = ref.watch(ProviderManager.apiServiceProvider);

  /// 创建 ProfileController 实例并返回
  return ProfileController(apiService);
});
