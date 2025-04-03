import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ImageUtils {
  // 内存缓存，用于存储已处理的URL
  static final Map<String, String> _urlCache = {};

  /// 获取指定尺寸的图片URL
  /// size: 图片尺寸，常用值：100, 240, 480
  static String getImageUrl(String? originalUrl, {int size = 240}) {
    if (originalUrl == null || originalUrl.isEmpty) {
      return '';
    }

    // 生成缓存key
    final cacheKey = '$originalUrl-$size';

    // 检查缓存
    if (_urlCache.containsKey(cacheKey)) {
      return _urlCache[cacheKey]!;
    }

    // 处理URL并缓存
    String processedUrl = originalUrl;
    if (originalUrl.contains('{size}')) {
      processedUrl = originalUrl.replaceAll('{size}', size.toString());
    }
    _urlCache[cacheKey] = processedUrl;

    return processedUrl;
  }

  /// 获取列表项缩略图URL（小图，用于列表显示）
  static String getThumbnailUrl(String? originalUrl) {
    return getImageUrl(originalUrl, size: 100);
  }

  /// 获取中等尺寸图片URL（用于播放页面等）
  static String getMediumUrl(String? originalUrl) {
    return getImageUrl(originalUrl, size: 240);
  }

  /// 获取大图URL（用于高清显示）
  static String getLargeUrl(String? originalUrl) {
    return getImageUrl(originalUrl, size: 480);
  }

  /// 获取大图URL（用于高清显示），与getLargeUrl功能相同
  static String getLargeImageUrl(String? originalUrl) {
    return getLargeUrl(originalUrl);
  }

  /// 创建缓存网络图片组件
  static Widget createCachedImage(
    String? url, {
    double? width,
    double? height,
    BoxFit? fit,
    Widget Function(BuildContext, String, dynamic)? errorBuilder,
    Widget? placeholder,
  }) {
    if (url == null || url.isEmpty) {
      return _buildErrorWidget(width, height);
    }

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      placeholder: (context, url) =>
          placeholder ?? _buildPlaceholder(width, height),
      errorWidget: errorBuilder ??
          (context, url, error) => _buildErrorWidget(width, height),
      // 添加缓存配置
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      maxWidthDiskCache: width?.toInt(),
      maxHeightDiskCache: height?.toInt(),
    );
  }

  static Widget _buildPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }

  static Widget _buildErrorWidget(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Icon(Icons.music_note, color: Colors.white),
    );
  }
}
