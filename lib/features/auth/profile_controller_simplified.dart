import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_service.dart';
import '../../core/providers/provider_manager.dart';

/// 用户个人信息模型
class UserProfile {
  final String userId;
  final String nickname;
  final String? pic;
  final String? knickname;
  final String? gender;
  final bool isVip;
  final String? vipType;

  UserProfile({
    required this.userId,
    required this.nickname,
    this.pic,
    this.knickname,
    this.gender,
    this.isVip = false,
    this.vipType,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // 确保 userId 和 nickname 有值
    String userId = '';
    if (json['userid'] != null) {
      userId = json['userid'].toString();
    } else if (json['user_id'] != null) {
      userId = json['user_id'].toString();
    }

    String nickname = '未知用户';
    if (json['nickname'] != null) {
      nickname = json['nickname'].toString();
    } else if (json['name'] != null) {
      nickname = json['name'].toString();
    }

    // 处理 isVip (现在是 bool)
    bool isVip = false;
    if (json['is_vip'] != null) {
      if (json['is_vip'] is int) {
        isVip = json['is_vip'] == 1;
      } else {
        // 尝试将字符串 '1' 转为 true
        isVip = json['is_vip'].toString() == '1';
      }
    } else if (json['vip'] != null) {
      // 兼容旧的 'vip' 字段 (假设也是 '1' 代表 VIP)
      isVip = json['vip'].toString() == '1';
    }

    return UserProfile(
      userId: userId,
      nickname: nickname,
      pic: json['pic'],
      knickname: json['k_nickname'],
      gender: _parseGender(json['gender']),
      isVip: isVip,
      vipType: json['vip_type']?.toString(),
    );
  }

  static String? _parseGender(dynamic gender) {
    if (gender == null) return null;
    final genderStr = gender.toString();
    if (genderStr == '1') return '男';
    if (genderStr == '2') return '女';
    return null;
  }
}

/// 简化的用户信息状态类
class ProfileState {
  final bool isLoading;
  final UserProfile? userProfile;
  final String? errorMessage;

  ProfileState({
    this.isLoading = false,
    this.userProfile,
    this.errorMessage,
  });

  ProfileState copyWith({
    bool? isLoading,
    UserProfile? userProfile,
    String? errorMessage,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      userProfile: userProfile ?? this.userProfile,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get hasError => errorMessage != null;
  bool get isLoaded => userProfile != null && !isLoading && !hasError;
}

/// 简化的用户信息控制器
class ProfileController extends StateNotifier<ProfileState> {
  final ApiService _apiService;

  ProfileController(this._apiService) : super(ProfileState());

  /// 加载用户个人信息
  Future<void> loadUserProfile({bool forceRefresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _apiService.getUserDetail();

      if (response['status'] == 1 && response['data'] != null) {
        try {
          final userProfile = UserProfile.fromJson(response['data']);
          state = state.copyWith(
            isLoading: false,
            userProfile: userProfile,
          );
        } catch (parseError) {
          // 尝试使用控制台输出的数据构造用户信息
          final userData = response['data'] as Map<String, dynamic>;

          bool isVipCatch = false;
          if (userData['is_vip'] != null) {
            if (userData['is_vip'] is int) {
              isVipCatch = userData['is_vip'] == 1;
            } else {
              isVipCatch = userData['is_vip']?.toString() == '1';
            }
          }

          final userProfile = UserProfile(
            userId: userData['userid']?.toString() ?? '',
            nickname: userData['nickname'] ?? '未知用户',
            pic: userData['pic'],
            gender: userData['gender']?.toString() == '1'
                ? '男'
                : (userData['gender']?.toString() == '2' ? '女' : null),
            isVip: isVipCatch,
          );

          state = state.copyWith(
            isLoading: false,
            userProfile: userProfile,
          );
        }
      } else {
        throw Exception(response['error_msg'] ?? '获取用户信息失败');
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 刷新用户信息
  Future<void> refreshUserProfile() async {
    await loadUserProfile(forceRefresh: true);
  }
}

/// 个人信息控制器提供者
@Deprecated('请使用ProviderManager.profileControllerProvider')
final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
  final apiService = ref.watch(ProviderManager.apiServiceProvider);
  return ProfileController(apiService);
});
