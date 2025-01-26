import 'song.dart';

class PlaySongInfo {
  final String hash; // 获取URL必需
  final String title; // 显示用
  final String artist; // 显示用
  final String? albumId; // 可选参数
  final String? cover; // 封面，可选

  PlaySongInfo({
    required this.hash,
    required this.title,
    required this.artist,
    this.albumId,
    this.cover,
  });

  // 从 Song 模型转换
  factory PlaySongInfo.fromSong(Song song) {
    return PlaySongInfo(
      hash: song.hash,
      title: song.title,
      artist: song.artists,
      albumId: song.albumId,
      cover: song.cover,
    );
  }
}
