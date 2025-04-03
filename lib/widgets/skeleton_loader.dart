import 'package:flutter/material.dart';

/// 通用骨架屏加载组件
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final bool isCircle;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius,
    this.isCircle = false,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.isCircle
                ? BorderRadius.circular(widget.height / 2)
                : widget.borderRadius ?? BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.1, 0.5, 0.9],
              colors: [
                Colors.grey[300]!,
                Colors.grey[200]!,
                Colors.grey[300]!,
              ],
              transform: GradientRotation(_animation.value),
            ),
          ),
        );
      },
    );
  }
}

/// 个人中心页面骨架屏
class ProfileTabSkeleton extends StatelessWidget {
  const ProfileTabSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用户信息区域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // 头像
                const SkeletonLoader(
                  width: 60,
                  height: 60,
                  isCircle: true,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 用户名
                      const SkeletonLoader(
                        width: 120,
                        height: 18,
                      ),
                      const SizedBox(height: 8),
                      // 用户ID
                      SkeletonLoader(
                        width: 80,
                        height: 14,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 功能区域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFeatureSkeleton(),
                _buildFeatureSkeleton(),
                _buildFeatureSkeleton(),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 最近播放区域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Row(
                  children: [
                    const SkeletonLoader(
                      width: 80,
                      height: 18,
                    ),
                    const Spacer(),
                    SkeletonLoader(
                      width: 20,
                      height: 20,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 歌曲列表
                for (int i = 0; i < 3; i++) ...[
                  _buildSongItemSkeleton(),
                  const SizedBox(height: 12),
                ]
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 歌单区域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Row(
                  children: [
                    const SkeletonLoader(
                      width: 80,
                      height: 18,
                    ),
                    const Spacer(),
                    SkeletonLoader(
                      width: 20,
                      height: 20,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 歌单列表
                for (int i = 0; i < 2; i++) ...[
                  _buildPlaylistItemSkeleton(),
                  const SizedBox(height: 12),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureSkeleton() {
    return Column(
      children: [
        SkeletonLoader(
          width: 40,
          height: 40,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 8),
        const SkeletonLoader(
          width: 50,
          height: 12,
        ),
      ],
    );
  }

  Widget _buildSongItemSkeleton() {
    return Row(
      children: [
        SkeletonLoader(
          width: 50,
          height: 50,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonLoader(
                width: double.infinity,
                height: 16,
              ),
              const SizedBox(height: 8),
              SkeletonLoader(
                width: 100,
                height: 12,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildPlaylistItemSkeleton() {
    return Row(
      children: [
        SkeletonLoader(
          width: 50,
          height: 50,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonLoader(
                width: double.infinity,
                height: 16,
              ),
              const SizedBox(height: 8),
              SkeletonLoader(
                width: 60,
                height: 12,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          ),
        )
      ],
    );
  }
}
