import 'package:flutter/material.dart';
import 'shimmer_loading.dart';

/// 个人中心页面骨架屏
class ProfileSkeleton extends StatelessWidget {
  /// 构造函数
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    /// 使用 ListView 构建可滚动的骨架屏内容
    return ListView(
      children: [
        /// 用户信息卡片骨架
        _buildUserInfoCardSkeleton(context),

        /// 功能区骨架之间的间距
        const SizedBox(height: 24),

        /// 功能区列表骨架
        _buildFunctionsSkeleton(context),
      ],
    );
  }

  /// 用户信息卡片骨架
  Widget _buildUserInfoCardSkeleton(BuildContext context) {
    /// 使用 Card 组件包裹，提供圆角和阴影效果
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,

      /// 内边距
      child: Padding(
        padding: const EdgeInsets.all(16),

        /// 使用 Row 水平排列头像和用户信息骨架
        child: Row(
          children: [
            /// 头像占位骨架，圆形
            ShimmerContainer(
              width: 80,
              height: 80,
              borderRadius: 40,
            ),

            /// 头像和用户信息之间的间距
            const SizedBox(width: 20),

            /// 用户信息垂直排列的骨架
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 用户昵称占位骨架
                  const ShimmerContainer(
                    width: 120,
                    height: 24,
                  ),

                  /// 昵称和额外信息之间的间距
                  const SizedBox(height: 8),

                  /// 额外信息占位骨架
                  ShimmerContainer(
                    width: 80,
                    height: 18,
                  ),

                  /// 额外信息和按钮之间的间距
                  const SizedBox(height: 12),

                  /// 操作按钮占位骨架，圆角矩形
                  ShimmerContainer(
                    width: 100,
                    height: 32,
                    borderRadius: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 功能区骨架
  Widget _buildFunctionsSkeleton(BuildContext context) {
    /// 使用 Column 垂直排列功能区标题和功能项骨架
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// 功能区标题占位骨架
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const ShimmerContainer(
            width: 80,
            height: 24,
          ),
        ),

        /// 标题和功能项列表之间的间距
        const SizedBox(height: 12),

        /// 使用 Column 垂直排列多个功能项骨架
        Column(
          children: List.generate(
            4,
            (index) => _buildFunctionItemSkeleton(),
          ),
        ),
      ],
    );
  }

  /// 功能项骨架
  Widget _buildFunctionItemSkeleton() {
    /// 使用 Padding 提供上下和左右的间距
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),

      /// 使用 Row 水平排列功能项的图标、文字和箭头骨架
      child: Row(
        children: [
          /// 图标占位骨架，圆形
          const ShimmerContainer(
            width: 24,
            height: 24,
            borderRadius: 12,
          ),

          /// 图标和文字之间的间距
          const SizedBox(width: 16),

          /// 文字占位骨架，占据剩余空间
          Expanded(
            child: const ShimmerContainer(
              height: 16,
            ),
          ),

          /// 文字和箭头之间的间距
          const SizedBox(width: 16),

          /// 箭头占位骨架
          const ShimmerContainer(
            width: 16,
            height: 16,
          ),
        ],
      ),
    );
  }
}
