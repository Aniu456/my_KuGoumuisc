// 从完整标题中获取歌曲名和艺术家名
// library;

// 导出公共函数
// export 'getTitle_ArtistName.dart' show getSongTitle, getArtistName;

/// 从完整标题中获取歌曲名
String getSongTitle(String fullTitle) {
  List<String> parts = fullTitle.split('-');
  return parts.length > 1 ? parts[1].trim() : fullTitle;
}

/// 从完整标题中获取艺术家名
String getArtistName(String fullTitle) {
  List<String> parts = fullTitle.split('-');
  return parts.isNotEmpty ? parts[0].trim() : '';
}
