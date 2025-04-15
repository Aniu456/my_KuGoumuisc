import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 图片服务类
/// 提供统一的图片加载和缓存接口
class ImageService {
  /// 单例模式实例
  static final ImageService _instance = ImageService._internal();

  /// 自定义缓存管理器
  final BaseCacheManager _cacheManager = DefaultCacheManager();

  /// 工厂构造函数
  factory ImageService() {
    return _instance;
  }

  /// 私有构造函数
  ImageService._internal();

  /// 创建带缓存的网络图片
  /// @param url 图片URL
  /// @param width 宽度
  /// @param height 高度
  /// @param fit 填充方式
  /// @param placeholder 占位组件
  /// @param errorWidget 错误组件
  /// @param borderRadius 圆角半径
  Widget createCachedImage({
    required String url,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
  }) {
    if (url.isEmpty) {
      return _buildErrorPlaceholder(width, height, borderRadius);
    }

    final image = CachedNetworkImage(
      cacheManager: _cacheManager,
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ??
          Center(
            child: SizedBox(
              width: width != null ? width / 3 : 24,
              height: height != null ? height / 3 : 24,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ?? _buildErrorPlaceholder(width, height, null),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: image,
      );
    }

    return image;
  }

  /// 创建专辑封面图片
  /// @param url 图片URL
  /// @param size 尺寸
  /// @param borderRadius 圆角半径
  Widget createAlbumCover({
    required String url,
    double size = 60,
    BorderRadius? borderRadius,
  }) {
    return createCachedImage(
      url: getMediumUrl(url),
      width: size,
      height: size,
      fit: BoxFit.cover,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      errorWidget: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.music_note,
          size: size / 2,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  /// 创建艺术家头像
  /// @param url 图片URL
  /// @param size 尺寸
  Widget createArtistAvatar({
    required String url,
    double size = 40,
  }) {
    return createCachedImage(
      url: url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(size / 2),
      errorWidget: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person,
          size: size / 2,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  /// 创建用户头像
  /// @param url 图片URL
  /// @param size 尺寸
  Widget createUserAvatar({
    required String? url,
    double size = 40,
  }) {
    if (url == null || url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person,
          size: size / 2,
          color: Colors.grey[500],
        ),
      );
    }

    return createCachedImage(
      url: url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(size / 2),
    );
  }

  /// 清除图片缓存
  Future<void> clearCache() async {
    await _cacheManager.emptyCache();
  }

  /// 预加载图片
  /// @param urls 图片URL列表
  Future<void> preloadImages(List<String> urls) async {
    for (var url in urls) {
      if (url.isNotEmpty) {
        try {
          await _cacheManager.getSingleFile(url);
        } catch (e) {
          // 忽略预加载错误
        }
      }
    }
  }

  /// 处理图片URL，获取高清图片
  /// @param url 原始URL
  /// @return 处理后的URL
  String getHighQualityUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    // 将小图替换为大图
    if (url.contains('_120.') || url.contains('_60.')) {
      return url.replaceFirst(RegExp(r'_120\.|_60\.'), '_500.');
    }

    // 其他图片直接返回原链接
    return url;
  }

  /// 处理图片URL，获取中等质量图片
  /// @param url 原始URL
  /// @return 处理后的URL
  String getMediumUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    // 将小图替换为中等图片
    if (url.contains('_60.')) {
      return url.replaceFirst(RegExp(r'_60\.'), '_120.');
    }

    // 如果已经是大图，降级为中等图片
    if (url.contains('_500.')) {
      return url.replaceFirst(RegExp(r'_500\.'), '_120.');
    }

    // 其他图片直接返回原链接
    return url;
  }

  /// 创建错误占位符
  /// @param width 宽度
  /// @param height 高度
  /// @param borderRadius 圆角半径
  Widget _buildErrorPlaceholder(
      double? width, double? height, BorderRadius? borderRadius) {
    final placeholder = Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          Icons.broken_image,
          size: (width ?? 40) / 2,
          color: Colors.grey[500],
        ),
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: placeholder,
      );
    }

    return placeholder;
  }
}
