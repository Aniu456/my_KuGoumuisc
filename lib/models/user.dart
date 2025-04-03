/// 用户模型类
/// 用于存储和管理用户的所有相关信息
/// 包括基本信息、VIP信息、认证信息等
class User {
  /// 用户唯一标识ID
  final String userId;

  /// 用户名
  final String nickname;

  /// 用户头像URL
  final String? pic;

  /// 是否是VIP用户
  final bool isVip;

  /// VIP认证token
  final String? vipToken;

  /// VIP开始时间，可为空
  final String? vipBeginTime;

  /// VIP结束时间，可为空
  final String? vipEndTime;

  /// 用户认证token
  final String token;

  /// 服务器时间
  final DateTime serverTime;

  /// 额外信息
  final Map<String, dynamic>? extraInfo;

  /// 构造函数
  /// @param userId 用户ID
  /// @param nickname 用户名
  /// @param pic 用户头像URL
  /// @param isVip 是否VIP
  /// @param vipToken VIP认证token
  /// @param vipBeginTime VIP开始时间
  /// @param vipEndTime VIP结束时间
  /// @param token 认证token
  /// @param serverTime 服务器时间
  /// @param extraInfo 额外信息
  User({
    required this.userId,
    required this.nickname,
    this.pic,
    required this.isVip,
    this.vipToken,
    this.vipBeginTime,
    this.vipEndTime,
    required this.token,
    required this.serverTime,
    this.extraInfo,
  });

  /// 从JSON数据创建User对象
  /// @param json 包含用户数据的Map对象
  /// @return 返回User实例
  factory User.fromJson(Map<String, dynamic> json) {
    // 从 extraInfo 中获取 VIP 信息
    final extraInfo = json['extraInfo'] as Map<String, dynamic>?;
    final vipInfo = extraInfo?['vipInfo'] as Map<String, dynamic>?;

    // 获取VIP时间信息
    final vipBeginTime = vipInfo?['beginTime'] as String? ??
        json['vip_begin_time'] as String? ??
        json['su_vip_begin_time'] as String?;

    final vipEndTime = vipInfo?['endTime'] as String? ??
        json['vip_end_time'] as String? ??
        json['su_vip_end_time'] as String?;

    // 验证VIP状态
    bool isVip = false;
    if (vipBeginTime != null && vipEndTime != null) {
      try {
        final now = DateTime.now();
        final begin = DateTime.parse(vipBeginTime);
        final end = DateTime.parse(vipEndTime);
        isVip = now.isAfter(begin) && now.isBefore(end);
      } catch (e) {
        print('解析VIP时间出错: $e');
        isVip = false;
      }
    }

    // 如果时间验证失败，再尝试其他字段
    if (!isVip) {
      isVip = vipInfo?['isVip'] == true ||
          vipInfo?['isVip'] == 1 ||
          json['is_vip'] == 1 ||
          json['is_vip'] == true;
    }

    return User(
      userId: json['userid'] as String,
      nickname: json['nickname'] as String,
      pic: json['pic'] as String?,
      isVip: isVip,
      vipToken: json['vip_token'] as String?,
      vipBeginTime: vipBeginTime,
      vipEndTime: vipEndTime,
      token: json['token'] as String,
      serverTime: DateTime.parse(json['servertime'] as String),
      extraInfo: extraInfo,
    );
  }

  /// 将User对象转换为JSON格式
  /// @return 返回Map对象，包含所有用户数据
  Map<String, dynamic> toJson() {
    return {
      'userid': userId,
      'nickname': nickname,
      'pic': pic,
      'is_vip': isVip ? 1 : 0,
      'vip_token': vipToken,
      'vip_begin_time': vipBeginTime,
      'vip_end_time': vipEndTime,
      'token': token,
      'servertime': serverTime.toIso8601String(),
      'extraInfo': extraInfo,
    };
  }

  /// 创建当前对象的副本，并可选择更新某些字段
  /// @return 返回一个新的User对象
  User copyWith({
    String? userId,
    String? nickname,
    String? pic,
    bool? isVip,
    String? vipToken,
    String? vipBeginTime,
    String? vipEndTime,
    String? token,
    DateTime? serverTime,
    Map<String, dynamic>? extraInfo,
  }) {
    return User(
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      pic: pic ?? this.pic,
      isVip: isVip ?? this.isVip,
      vipToken: vipToken ?? this.vipToken,
      vipBeginTime: vipBeginTime ?? this.vipBeginTime,
      vipEndTime: vipEndTime ?? this.vipEndTime,
      token: token ?? this.token,
      serverTime: serverTime ?? this.serverTime,
      extraInfo: extraInfo ?? this.extraInfo,
    );
  }

  bool get isVipValid {
    if (!isVip) return false;
    if (vipBeginTime == null || vipEndTime == null) return false;

    try {
      final now = DateTime.now();
      final begin = DateTime.parse(vipBeginTime!);
      final end = DateTime.parse(vipEndTime!);

      // 检查VIP是否在有效期内
      final isValid = now.isAfter(begin) && now.isBefore(end);

      return isValid;
    } catch (e) {
      print('验证VIP状态时出错: $e');
      return false;
    }
  }

  /// 获取VIP剩余天数
  int? get vipRemainingDays {
    if (!isVipValid || vipEndTime == null) return null;
    try {
      final now = DateTime.now();
      final end = DateTime.parse(vipEndTime!);
      return end.difference(now).inDays;
    } catch (e) {
      return null;
    }
  }
}
