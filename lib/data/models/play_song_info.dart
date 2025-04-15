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

  // 从JSON Map转换
  factory PlaySongInfo.fromJson(Map<String, dynamic> json) {
    try {
      // 尝试从多种可能的字段名中获取数据
      final String hash =
          json['hash'] ?? json['fileHash'] ?? json['file_hash'] ?? '';

      final String title = json['title'] ??
          json['songName'] ??
          json['song_name'] ??
          json['name'] ??
          '未知歌曲';

      String artist = '';

      // 尝试获取艺术家信息的多种可能格式
      if (json['artist'] != null) {
        artist = json['artist'].toString();
      } else if (json['singerName'] != null) {
        artist = json['singerName'].toString();
      } else if (json['singer_name'] != null) {
        artist = json['singer_name'].toString();
      } else if (json['singers'] != null && json['singers'] is List) {
        artist = (json['singers'] as List)
            .map((s) {
              if (s is Map && s['name'] != null) {
                return s['name'].toString();
              } else if (s is String) {
                return s;
              }
              return '';
            })
            .where((name) => name.isNotEmpty)
            .join(', ');
      } else if (json['author_name'] != null) {
        artist = json['author_name'].toString();
      } else {
        // 尝试从name中解析（如果包含 - 分隔符）
        final String name = json['name']?.toString() ?? '';
        if (name.contains(' - ')) {
          artist = name.split(' - ').first;
        } else {
          artist = '未知艺术家';
        }
      }

      // 获取封面URL的多种可能格式
      final String? cover =
          json['cover'] ?? json['image'] ?? json['img'] ?? json['albumImg'];

      // 获取专辑ID
      String? albumId;
      if (json['albumId'] != null) {
        albumId = json['albumId'].toString();
      } else if (json['album_id'] != null) {
        albumId = json['album_id'].toString();
      } else if (json['aid'] != null) {
        albumId = json['aid'].toString();
      }

      // 获取mixsongid
      String? mixsongid;
      if (json['mixsongid'] != null) {
        mixsongid = json['mixsongid'].toString();
      } else if (json['mixSongId'] != null) {
        mixsongid = json['mixSongId'].toString();
      } else if (json['mix_song_id'] != null) {
        mixsongid = json['mix_song_id'].toString();
      } else if (json['add_mixsongid'] != null) {
        mixsongid = json['add_mixsongid'].toString();
      }

      // 获取持续时间
      int? duration;
      if (json['duration'] != null) {
        if (json['duration'] is int) {
          duration = json['duration'];
        } else if (json['duration'] is String) {
          duration = int.tryParse(json['duration']);
        }
      } else if (json['timelength'] != null) {
        if (json['timelength'] is int) {
          duration = json['timelength'];
        } else if (json['timelength'] is String) {
          duration = int.tryParse(json['timelength']);
        } else {
          duration = (json['timelength'] as num?)?.toInt();
        }
      } else if (json['timelen'] != null) {
        final timelen = json['timelen'];
        if (timelen is int) {
          duration = timelen;
        } else if (timelen is String) {
          duration = int.tryParse(timelen);
        } else {
          duration = (timelen as num?)?.toInt();
        }
      }

      print('解析成功: 歌曲名=$title, 歌手=$artist, hash=$hash');
      return PlaySongInfo(
        hash: hash,
        title: title,
        artist: artist,
        albumId: albumId,
        cover: cover,
        mixsongid: mixsongid,
        duration: duration,
      );
    } catch (e) {
      print('从JSON解析PlaySongInfo失败: $e, 源数据: $json');
      // 返回一个带有基本信息的对象，避免崩溃
      String title = '解析错误的歌曲';
      String artist = '未知艺术家';

      // 尝试从name中获取基本信息
      if (json['name'] != null) {
        final String name = json['name'].toString();
        if (name.contains(' - ')) {
          final parts = name.split(' - ');
          artist = parts[0];
          title = parts.length > 1 ? parts[1] : name;
        } else {
          title = name;
        }
      }

      return PlaySongInfo(
        hash: json['hash']?.toString() ?? '',
        title: title,
        artist: artist,
      );
    }
  }
}
