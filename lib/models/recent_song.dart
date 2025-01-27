class RecentSong {
  final String hash;
  final String name;
  final String singername;
  final String cover;
  final String albumId;
  final String audioId;

  RecentSong({
    required this.hash,
    required this.name,
    required this.singername,
    required this.cover,
    required this.albumId,
    required this.audioId,
  });

  factory RecentSong.fromJson(Map<String, dynamic> json) {
    final info = json['info'] as Map<String, dynamic>;
    return RecentSong(
      hash: info['hash']?.toString() ?? '',
      name: info['name']?.toString() ?? '',
      singername: info['singername']?.toString() ?? '',
      cover: info['cover']?.toString() ?? '',
      albumId: info['album_id']?.toString() ?? '',
      audioId: info['audio_id']?.toString() ?? '',
    );
  }
}

class RecentSongsResponse {
  final String bp;
  final List<RecentSong> songs;

  RecentSongsResponse({
    required this.bp,
    required this.songs,
  });

  factory RecentSongsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return RecentSongsResponse(
      bp: data['bp']?.toString() ?? '',
      songs: (data['songs'] as List? ?? [])
          .map((songData) => RecentSong.fromJson(songData))
          .toList(),
    );
  }
}
