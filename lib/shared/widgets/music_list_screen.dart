import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/play_song_info.dart';
import '../../core/providers/provider_manager.dart';
import '../../utils/image_utils.dart';
import 'package:go_router/go_router.dart';
import 'player_page.dart';

/// 音乐列表页面，用于显示歌单中的歌曲
class MusicListScreen extends ConsumerStatefulWidget {
  /// 歌单标题
  final String title;

  /// 歌单ID，用于从网络获取歌曲列表
  final String? playlistId;

  /// 直接传入的歌曲列表，当不需要从网络获取时使用
  final List<PlaySongInfo>? playlist;

  /// 构造函数，playlistId 和 playlist 必须提供一个
  const MusicListScreen({
    super.key,
    required this.title,
    this.playlistId,
    this.playlist,
  }) : assert(
            playlistId != null || playlist != null, '必须提供playlistId或playlist');

  @override
  ConsumerState<MusicListScreen> createState() => _MusicListScreenState();
}

class _MusicListScreenState extends ConsumerState<MusicListScreen> {
  /// 用于存储歌曲列表的 Future
  late Future<List<PlaySongInfo>> _songsFuture;

  @override
  void initState() {
    super.initState();

    print(
        'MusicListScreen初始化，歌单ID: ${widget.playlistId}, 歌单名称: ${widget.title}');

    /// 根据是否提供了 playlistId 来决定如何加载歌曲
    if (widget.playlistId != null) {
      /// 如果提供了 playlistId，则从 API 获取歌单歌曲
      _songsFuture = _loadSongsFromPlaylist();
    } else {
      /// 如果直接提供了 playlist，则使用传入的列表
      _songsFuture = Future.value(widget.playlist!);
    }
  }

  /// 从API加载歌单歌曲的方法
  Future<List<PlaySongInfo>> _loadSongsFromPlaylist() async {
    try {
      print('开始加载歌单: ${widget.title}, ID: ${widget.playlistId}');

      if (widget.playlistId == null || widget.playlistId!.isEmpty) {
        print('歌单ID为空');
        throw Exception('歌单ID无效');
      }

      // 获取歌曲数据
      final tracks = await ref
          .read(ProviderManager.apiServiceProvider)
          .getPlaylistTracks(widget.playlistId!);

      print('获取到${tracks.length}首歌曲');

      if (tracks.isEmpty) {
        return [];
      }

      // 将每个歌曲数据转换为PlaySongInfo对象
      return tracks.map((map) {
        try {
          return PlaySongInfo.fromJson(map);
        } catch (e) {
          print('解析歌曲数据失败: $e, 数据: $map');
          // 返回一个带有错误信息的占位对象
          return PlaySongInfo(
            hash: map['hash'] ?? '',
            title: map['title'] ?? map['songName'] ?? '未知歌曲',
            artist: map['artist'] ?? map['singerName'] ?? '未知艺术家',
          );
        }
      }).toList();
    } catch (e) {
      print('加载歌单歌曲失败: $e');
      // 在这里捕获异常并返回空列表，让UI显示没有歌曲
      throw Exception('获取歌单歌曲失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    /// 监听播放器服务
    final playerService = ref.watch(ProviderManager.playerServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),

      /// 使用 FutureBuilder 来处理异步加载的歌曲列表
      body: FutureBuilder<List<PlaySongInfo>>(
        future: _songsFuture,
        builder: (context, snapshot) {
          /// 加载中显示 CircularProgressIndicator
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          /// 加载失败显示错误信息
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    '加载失败: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        if (widget.playlistId != null) {
                          _songsFuture = _loadSongsFromPlaylist();
                        }
                      });
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          /// 加载成功获取歌曲列表
          final songs = snapshot.data ?? [];

          if (songs.isEmpty) {
            return const Center(child: Text('暂无歌曲'));
          }

          /// 使用 ListView.builder 显示歌曲列表
          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                title: Text(song.title),
                subtitle: Text(song.artist),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: song.cover != null && song.cover!.isNotEmpty
                      ? ImageUtils.createCachedImage(
                          ImageUtils.getThumbnailUrl(song.cover),
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.music_note, color: Colors.white),
                ),

                /// 点击歌曲播放
                onTap: () async {
                  try {
                    // 准备播放列表
                    playerService.preparePlaylist(songs, index);
                    // 播放当前歌曲
                    await playerService.play(song);
                    // 导航到播放器页面
                    if (mounted) {
                      // 使用更简单的导航方法，避免复杂的条件
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const PlayerPage(),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('播放失败: $e')),
                      );
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
