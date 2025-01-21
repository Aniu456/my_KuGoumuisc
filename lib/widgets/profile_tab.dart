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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchUserInfo();
    });
  }

  Future<void> _fetchUserInfo() async {
    final state = context.read<AuthBloc>().state;
    if (state is AuthAuthenticated) {
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
                                              if (isAuthenticated &&
                                                  user!.isVip) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors.amber[700]!,
                                                        Colors.amber[400]!,
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.workspace_premium,
                                                        color: Colors.white,
                                                        size: 14,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'VIP',
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

                        if (isAuthenticated) ...[
                          const SizedBox(height: 24),
                          // 听歌时光机卡片
                          Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              height: 100,
                              padding: const EdgeInsets.all(16),
                              child: const Center(
                                child: Text(
                                  '我的听歌排行',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        '我创建的歌单',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '13',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
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
