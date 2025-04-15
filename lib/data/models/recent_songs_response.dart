class RecentSongsResponse {
  final bool success;
  final String? message;
  final List<RecentSongItem> songs;
  final int? total;
  final String? nextBq; // 下一页分页参数

  RecentSongsResponse({
    required this.success,
    this.message,
    required this.songs,
    this.total,
    this.nextBq,
  });

  factory RecentSongsResponse.fromJson(Map<String, dynamic> json) {
    final bool success = json['status'] == 1;
    final songsData = json['data']?['info'] as List<dynamic>?;

    return RecentSongsResponse(
      success: success,
      message: json['error_msg'],
      songs: songsData != null
          ? songsData.map((item) => RecentSongItem.fromJson(item)).toList()
          : [],
      total: json['data']?['total'],
      nextBq: json['data']?['next_bq'],
    );
  }
}

class RecentSongItem {
  final String hash;
  final String name;
  final String singer;
  final String? imgUrl;
  final String? albumId;
  final String? mixsongid;
  final int? playedTime; // 播放时间戳

  RecentSongItem({
    required this.hash,
    required this.name,
    required this.singer,
    this.imgUrl,
    this.albumId,
    this.mixsongid,
    this.playedTime,
  });

  factory RecentSongItem.fromJson(Map<String, dynamic> json) {
    return RecentSongItem(
      hash: json['hash'] ?? '',
      name: json['songname'] ?? json['song_name'] ?? '',
      singer: json['singername'] ?? json['singer_name'] ?? '',
      imgUrl: json['img'] ?? json['album_img'],
      albumId: json['album_id']?.toString(),
      mixsongid: json['mixsongid']?.toString(),
      playedTime: json['played_time'],
    );
  }
}
