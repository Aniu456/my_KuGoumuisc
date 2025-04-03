import 'song.dart';
import 'search_response.dart';

class PlaySongInfo {
  final String hash; // 获取URL必需
  final String title; // 显示用
  final String artist; // 显示用
  final String? albumId; // 可选参数
  final String? cover; // 封面，可选
  final String? mixsongid; // 添加到歌单必需
  final int? duration; // 歌曲时长（秒）

  PlaySongInfo({
    required this.hash,
    required this.title,
    required this.artist,
    this.albumId,
    this.cover,
    this.mixsongid,
    this.duration,
  });

  // 添加songName getter
  String get songName => title;

  // 添加singerName getter
  String get singerName => artist;

  // 从 Song 模型转换
  factory PlaySongInfo.fromSong(Song song) {
    return PlaySongInfo(
      hash: song.hash,
      title: song.title,
      artist: song.artists,
      albumId: song.albumId,
      cover: song.cover,
      mixsongid: song.mixsongid,
      duration: song.duration,
    );
  }

  // 从 SearchSong 模型转换
  factory PlaySongInfo.fromSearchSong(SearchSong song) {
    return PlaySongInfo(
      hash: song.fileHash,
      title: song.songName,
      artist: song.singers.map((s) => s.name).join(', '),
      cover: song.image,
      mixsongid: song.mixSongId,
      duration: song.duration,
    );
  }
}
