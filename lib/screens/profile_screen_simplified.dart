import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/widgets/custom_dialog.dart';
import '../utils/image_utils.dart';
import '../services/api_service.dart';
import '../core/providers/provider_manager.dart';
import '../features/auth/profile_controller_simplified.dart';
import 'recent_plays_screen.dart';

/// 简化版个人中心页面
class ProfileScreenSimplified extends ConsumerStatefulWidget {
  const ProfileScreenSimplified({super.key});

  @override
  ConsumerState<ProfileScreenSimplified> createState() =>
      _ProfileScreenSimplifiedState();
}

class _ProfileScreenSimplifiedState
    extends ConsumerState<ProfileScreenSimplified> {
  bool _isLoading = false;
  String? _errorMessage;
  UserProfile? _userProfile;
  late final ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = ref.read(ProviderManager.apiServiceProvider);
    _loadUserProfile();
  }

  /// 直接从API服务加载用户信息 (合并基础信息和VIP信息)
  Future<void> _loadUserProfile() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _userProfile = null; // 重置用户信息，防止显示旧数据
    });

    try {
      // 使用 Future.wait 同时请求两个接口
      final results = await Future.wait([
        _apiService.getUserDetail(), // 获取基础信息
        _apiService.getUserVipDetail(), // 获取VIP详情
      ]);

      // 分别获取结果
      final userDetailData = results[0]; // 基础用户信息 Map
      final userVipData = results[1]; // VIP 详情 Map
      bool isVip = false; // 默认为 false
      if (userVipData.containsKey('is_vip') && userVipData['is_vip'] != null) {
        dynamic vipFlag = userVipData['is_vip'];
        if (vipFlag is int) {
          isVip = vipFlag == 1;
        } else if (vipFlag is String) {
          isVip = vipFlag == '1';
        }
      }

      // 使用两个接口的数据构造 UserProfile
      final userProfile = UserProfile(
        userId: userDetailData['userid']?.toString() ?? '',
        nickname: userDetailData['nickname'] ?? '未知用户',
        pic: userDetailData['pic'],
        gender: _parseGender(userDetailData['gender']), // 使用已有的 _parseGender 方法
        isVip: isVip, // 使用从 getUserVipDetail 获取的 VIP 状态
        vipType:
            userDetailData['vip_type']?.toString(), // 如果基础信息里有 vip_type，可以保留
      );

      // 更新 UI 状态
      if (mounted) {
        // 检查 Widget 是否还在 Widget 树中
        setState(() {
          _isLoading = false;
          _userProfile = userProfile;
          _errorMessage = null;
        });
      }
    } catch (e) {
      print('[PROFILE LOAD ERROR] $e'); // 打印详细错误信息
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              '加载用户信息失败: ${e.toString().replaceFirst('Exception: ', '')}';
          _userProfile = null; // 确保出错时用户信息为空
        });
      }
    }
  }

  /// 解析性别信息 (这个方法应该保持不变)
  String? _parseGender(dynamic gender) {
    if (gender == null) return null;
    final genderStr = gender.toString();
    if (genderStr == '1') return '男';
    if (genderStr == '2') return '女';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      // 明确设置背景色为白色
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('个人中心',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              // 根据白色背景调整 AppBar 标题颜色
              color: Colors.black87,
            )),
        elevation: 0,
        // AppBar 背景也设为白色或透明
        backgroundColor: Colors.white,
        // 调整 AppBar 图标颜色以适应白色背景
        iconTheme: IconThemeData(color: Colors.black54),
        actionsIconTheme: IconThemeData(color: Colors.black54),
        actions: [
          /// 退出登录按钮
          IconButton(
            // 图标颜色调整
            icon: Icon(Icons.exit_to_app, color: Colors.black54),
            tooltip: '退出登录',
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('确认退出'),
                      content: const Text('您确定要退出当前账号吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('确认'),
                        ),
                      ],
                    ),
                  ) ??
                  false;

              if (shouldLogout && context.mounted) {
                // 调用退出登录逻辑
                try {
                  await ref
                      .read(ProviderManager.authControllerProvider)
                      .logout();
                  ref.invalidate(ProviderManager.isLoggedInProvider);
                  // 可以在这里添加退出成功后的导航或其他操作，如果需要的话
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('退出登录成功')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('退出登录失败: $e')),
                  );
                }
              }
            },
          ),

          /// 刷新按钮
          IconButton(
            // 图标颜色调整
            icon: Icon(Icons.refresh, color: Colors.black54),
            tooltip: '刷新个人信息',
            onPressed: _isLoading ? null : _loadUserProfile,
          ),
        ],
      ),
      body: _buildProfileContent(),
    );
  }

  /// 构建个人中心内容
  Widget _buildProfileContent() {
    if (_isLoading && _userProfile == null) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              '加载失败: $_errorMessage',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserProfile,
              child: Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_userProfile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '无法获取用户信息',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserProfile,
              child: Text('重试'),
            ),
          ],
        ),
      );
    }

    // 显示用户信息
    return RefreshIndicator(
      onRefresh: () => _loadUserProfile(),
      child: ListView(
        // 调整 ListView padding
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildUserInfoSection(), // 修改为 Section
          const SizedBox(height: 24), // 增加间距
          _buildFunctionsList(), // 修改为 List
        ],
      ),
    );
  }

  /// 构建用户信息区域 (替代 Card)
  Widget _buildUserInfoSection() {
    final userProfile = _userProfile!;
    final avatarUrl = userProfile.pic != null && userProfile.pic!.isNotEmpty
        ? ImageUtils.getMediumUrl(userProfile.pic)
        : null;

    return Padding(
      // 使用 Padding 替代 Card margin
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // 用户头像 - 移除阴影
          Container(
            width: 70, // 稍微缩小头像尺寸
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200], // 浅灰色背景
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl != null
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.person,
                          size: 35, color: Colors.grey[600]);
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                          child: CircularProgressIndicator(strokeWidth: 2));
                    },
                  )
                : Icon(Icons.person, size: 35, color: Colors.grey[600]),
          ),
          const SizedBox(width: 16),
          // 用户信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userProfile.nickname,
                  style: TextStyle(
                    fontSize: 18, // 调整字体大小
                    fontWeight: FontWeight.w600, // 调整字重
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (userProfile.gender != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: userProfile.gender == '男'
                              ? Colors.blue[50]
                              : Colors.pink[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          userProfile.gender!,
                          style: TextStyle(
                            fontSize: 11,
                            color: userProfile.gender == '男'
                                ? Colors.blue[700]
                                : Colors.pink[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    // 使用标准的布尔判断
                    if (userProfile.gender != null && userProfile.isVip)
                      const SizedBox(width: 6),
                    // 使用标准的布尔判断
                    if (userProfile.isVip)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'VIP',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建功能列表 (替代 Functions Section Card)
  Widget _buildFunctionsList() {
    final listTilePadding = const EdgeInsets.symmetric(
        horizontal: 0, vertical: 4); // 调整 ListTile 内边距
    final iconColor = Colors.grey[700];
    final textColor = Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '常用功能',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600]),
          textAlign: TextAlign.left,
        ),
        const SizedBox(height: 8),
        // 使用 Column + ListTile 替代 Card
        ListTile(
          contentPadding: listTilePadding,
          leading: Icon(Icons.history, color: iconColor),
          title: Text('已缓存歌曲', style: TextStyle(color: textColor)),
          trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const RecentPlaysScreen(),
              ),
            );
          },
        ),
        Divider(height: 1, color: Colors.grey[200]),
        ListTile(
          contentPadding: listTilePadding,
          leading: Icon(Icons.download_outlined, color: iconColor),
          title: Text('我的下载', style: TextStyle(color: textColor)),
          trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
          onTap: () {
            AppDialog.showInfo(context: context, message: '功能待实现');
          },
        ),
        Divider(height: 1, color: Colors.grey[200]),
        ListTile(
          contentPadding: listTilePadding,
          leading: Icon(Icons.settings_outlined, color: iconColor),
          title: Text('设置', style: TextStyle(color: textColor)),
          trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
          onTap: () {
            AppDialog.showInfo(context: context, message: '功能待实现');
          },
        ),
      ],
    );
  }
}
