class RecentSong {
  final String hash;
  final String songname;
  final String singername;
  final String cover;

  RecentSong({
    required this.hash,
    required this.songname,
    required this.singername,
    required this.cover,
  });

  factory RecentSong.fromJson(Map<String, dynamic> json) {
    final info = json['info'] as Map<String, dynamic>;
    return RecentSong(
      hash: info['hash']?.toString() ?? '',
      songname: info['songname']?.toString() ?? '',
      singername: info['singername']?.toString() ?? '',
      cover: info['cover']?.toString() ?? '',
    );
  }
}

class RecentSongsResponse {
  final int cursor;
  final RecentSong? currentSong;
  final List<RecentSong> songs;

  RecentSongsResponse({
    required this.cursor,
    this.currentSong,
    required this.songs,
  });

  factory RecentSongsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;

    // 解析当前播放的歌曲
    RecentSong? currentSong;
    if (data['curr_song'] != null) {
      currentSong = RecentSong.fromJson(data['curr_song']);
    }

    // 解析最近播放列表
    final songsList = (data['songs'] as List?)
            ?.map((songJson) => RecentSong.fromJson(songJson))
            .toList() ??
        [];

    return RecentSongsResponse(
      cursor: data['cursor'] as int? ?? 0,
      currentSong: currentSong,
      songs: songsList,
    );
  }
}
