class ImageUtils {
  /// 获取指定尺寸的图片URL
  /// size: 图片尺寸，常用值：100, 240, 480
  static String getImageUrl(String? originalUrl, {int size = 240}) {
    if (originalUrl == null || originalUrl.isEmpty) {
      return ''; // 返回空字符串或默认图片URL
    }

    // 如果URL包含{size}，替换为指定尺寸
    if (originalUrl.contains('{size}')) {
      print('originalUrl: $originalUrl');
      return originalUrl.replaceAll('{size}', size.toString());
    }

    return originalUrl; // 如果不包含{size}，返回原始URL
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
}
