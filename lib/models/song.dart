class Song {
  final String hash;
  final String audioId;
  final int size;
  final String name;
  final String albumId;
  final String cover;
  final String singerName;
  final String albumImage;

  // 从name中解析出歌手和歌曲名
  String get title => name.split(' - ').last;
  String get artists => name.split(' - ').first;

  Song({
    required this.hash,
    required this.audioId,
    required this.size,
    required this.name,
    required this.albumId,
    required this.cover,
    required this.singerName,
    required this.albumImage,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      hash: json['hash'] ?? '',
      audioId: json['audio_id']?.toString() ?? '',
      size: json['size'] is int
          ? json['size']
          : int.tryParse(json['size']?.toString() ?? '0') ?? 0,
      name: json['songname'] ?? json['name'] ?? '',
      albumId: json['album_id'] ?? '',
      cover: json['cover']?.toString() ?? '',
      singerName: json['singername'] ?? json['singer_name'] ?? '',
      albumImage: json['album_img'] ?? json['album_image'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hash': hash,
      'audio_id': audioId,
      'size': size,
      'name': name,
      'album_id': albumId,
      'cover': cover,
      'singer_name': singerName,
      'album_image': albumImage,
    };
  }
}
