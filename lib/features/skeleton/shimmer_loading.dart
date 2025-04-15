import 'package:flutter/material.dart';

/// 骨架屏加载效果组件，用于在内容加载时提供视觉反馈。
class ShimmerLoading extends StatefulWidget {
  /// 需要应用 Shimmer 效果的子 Widget。
  final Widget child;

  /// 控制 Shimmer 效果是否激活。
  final bool isLoading;

  /// Shimmer 效果的基准颜色，通常是较浅的灰色。
  final Color baseColor;

  /// Shimmer 效果的高亮颜色，通常是比基准色更亮的颜色。
  final Color highlightColor;

  const ShimmerLoading({
    super.key,
    required this.child,
    required this.isLoading,
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  /// 用于控制 Shimmer 动画的 AnimationController。
  late AnimationController _controller;

  /// 控制 Shimmer 渐变位置的 Animation。
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    /// 创建 AnimationController，持续 1.5 秒并重复播放。
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    /// 创建一个 Tween 动画，从 -2 到 2，并使用 easeInOutSine 曲线。
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    /// 释放 AnimationController 资源。
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /// 如果 isLoading 为 false，则直接返回子 Widget，不应用 Shimmer 效果。
    if (!widget.isLoading) {
      return widget.child;
    }

    /// 使用 AnimatedBuilder 来根据 _animation 的值动态构建 Shimmer 效果。
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        /// 使用 ShaderMask 来应用线性渐变作为遮罩，实现 Shimmer 效果。
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],

              /// 根据 _animation 的值动态调整渐变的起始和结束位置，实现流动效果。
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// 简单的骨架屏容器，用于创建具有固定宽高和圆角矩形的占位符。
class ShimmerContainer extends StatelessWidget {
  /// 容器的宽度。
  final double width;

  /// 容器的高度。
  final double height;

  /// 容器的圆角半径。
  final double borderRadius;

  const ShimmerContainer({
    super.key,
    this.width = 100,
    this.height = 100,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white, // 使用白色作为 ShimmerLoading 的子 Widget，会被渐变遮罩
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// 骨架屏歌单条目，用于在加载歌单列表时显示占位符。
class PlaylistItemSkeleton extends StatelessWidget {
  const PlaylistItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          /// 封面图占位符
          const ShimmerContainer(width: 50, height: 50),
          const SizedBox(width: 12),

          /// 标题和副标题占位符
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerContainer(width: double.infinity, height: 16),
                const SizedBox(height: 8),
                ShimmerContainer(
                  width: MediaQuery.of(context).size.width * 0.3,
                  height: 12,
                ),
              ],
            ),
          ),

          /// 尾部图标占位符
          const ShimmerContainer(width: 16, height: 16),
        ],
      ),
    );
  }
}
