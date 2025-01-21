import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../services/api_service.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 只在第一次加载时获取用户信息
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) return;

    setState(() => _isLoading = true);
    try {
      final apiService = context.read<ApiService>();
      final userDetail = await apiService.getUserDetail();
      final vipInfo = await apiService.getUserVipInfo();

      if (userDetail['status'] == 1 && mounted) {
        context.read<AuthBloc>().add(
              AuthUpdateUserInfo(
                userDetail: userDetail,
                vipInfo: vipInfo,
              ),
            );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取用户信息失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleLoginTap() {
    Navigator.of(context).pushNamed('/login').then((_) {
      // 从登录页面返回后，检查是否需要刷新用户信息
      final state = context.read<AuthBloc>().state;
      if (state is AuthAuthenticated) {
        _fetchUserInfo();
      }
    });
  }

  void _handleLogout() {
    if (context.read<AuthBloc>().state is! AuthAuthenticated) {
      _handleLoginTap();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('您确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final bool isAuthenticated = state is AuthAuthenticated;
        final user = isAuthenticated ? (state).user : null;

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _fetchUserInfo,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue[300]!,
                    Colors.blue[100]!,
                  ],
                ),
              ),
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    title: Row(
                      children: [
                        const Text(
                          '我的',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '搜索音乐、歌手、歌词',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      if (isAuthenticated)
                        IconButton(
                          icon: const Icon(
                            Icons.logout,
                            color: Colors.white,
                          ),
                          onPressed: _handleLogout,
                        ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        // 用户信息卡片
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isAuthenticated ? null : _handleLoginTap,
                            borderRadius: BorderRadius.circular(16),
                            child: Card(
                              margin: const EdgeInsets.all(16),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage: user?.pic != null
                                          ? NetworkImage(user!.pic!)
                                          : null,
                                      child: user?.pic == null
                                          ? const Icon(Icons.person,
                                              color: Colors.grey, size: 42)
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                isAuthenticated
                                                    ? user!.nickname
                                                    : '立即登录',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (isAuthenticated) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient: user!.isVip
                                                        ? LinearGradient(
                                                            colors: [
                                                              Colors
                                                                  .amber[700]!,
                                                              Colors
                                                                  .amber[400]!,
                                                            ],
                                                          )
                                                        : null,
                                                    color: user.isVip
                                                        ? null
                                                        : Colors.grey[300],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.workspace_premium,
                                                        color: user.isVip
                                                            ? Colors.white
                                                            : Colors.grey[600],
                                                        size: 14,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'VIP',
                                                        style: TextStyle(
                                                          color: user.isVip
                                                              ? Colors.white
                                                              : Colors
                                                                  .grey[600],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      if (user.isVip)
                                                        Text(
                                                          '还剩${DateTime.parse(user.vipEndTime!).difference(DateTime.now()).inDays}天',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (isAuthenticated) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'ID: ${user!.userId}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 功能区域卡片
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildFeatureItem(
                                  icon: Icons.favorite_border,
                                  label: '收藏',
                                  count: isAuthenticated ? '992' : '0',
                                ),
                                _buildFeatureItem(
                                  icon: Icons.access_time,
                                  label: '最近',
                                  count: isAuthenticated ? '115' : '0',
                                ),
                                _buildFeatureItem(
                                  icon: Icons.download_outlined,
                                  label: '本地',
                                  count: '0',
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        // 听歌时光机卡片
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child:
                                  Icon(Icons.history, color: Colors.blue[600]),
                            ),
                            title: const Text('我的听歌排行'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              // TODO: 实现听歌排行功能
                            },
                          ),
                        ),

                        const SizedBox(height: 24),
                        // 创建的歌单卡片
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                title: Row(
                                  children: [
                                    const Text('我创建的歌单'),
                                    const SizedBox(width: 8),
                                    Text(
                                      isAuthenticated ? '2' : '0',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.add),
                                onTap: isAuthenticated
                                    ? () {
                                        // TODO: 添加歌单功能
                                      }
                                    : () => _handleLoginTap(),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.pink[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.favorite,
                                      color: Colors.pink[300]),
                                ),
                                title: const Text('我喜欢'),
                                subtitle: Text(isAuthenticated ? '992首' : '0首'),
                                onTap: isAuthenticated
                                    ? () {
                                        // TODO: 跳转到喜欢的音乐列表
                                      }
                                    : () => _handleLoginTap(),
                              ),
                              ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.star,
                                      color: Colors.orange[300]),
                                ),
                                title: const Text('默认收藏'),
                                subtitle: Text(isAuthenticated ? '115首' : '0首'),
                                onTap: isAuthenticated
                                    ? () {
                                        // TODO: 跳转到收藏列表
                                      }
                                    : () => _handleLoginTap(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        // 已购音乐卡片
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                title: const Text('已购音乐'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: isAuthenticated
                                    ? () {
                                        // TODO: 跳转到已购音乐页面
                                      }
                                    : () => _handleLoginTap(),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.purple[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.album,
                                      color: Colors.purple[300]),
                                ),
                                title: const Text('数字专辑'),
                                subtitle: const Text('0张'),
                                onTap: isAuthenticated
                                    ? () {
                                        // TODO: 跳转到数字专辑列表
                                      }
                                    : () => _handleLoginTap(),
                              ),
                              ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.music_note,
                                      color: Colors.green[300]),
                                ),
                                title: const Text('付费单曲'),
                                subtitle: const Text('0首'),
                                onTap: isAuthenticated
                                    ? () {
                                        // TODO: 跳转到付费单曲列表
                                      }
                                    : () => _handleLoginTap(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 30,
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required String count,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.blue[600]),
        ),
        const SizedBox(height: 4),
        Text(label),
        Text(
          count,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _CategoryTab extends StatelessWidget {
  final bool isSelected;
  final String text;

  const _CategoryTab({
    required this.isSelected,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.blue : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 20,
          height: 2,
          color: isSelected ? Colors.blue : Colors.transparent,
        ),
      ],
    );
  }
}
