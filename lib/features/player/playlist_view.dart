import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/provider_manager.dart';
import '../../services/player_service.dart';
import '../../utils/image_utils.dart';

class PlaylistView extends ConsumerStatefulWidget {
  final Color accentColor;
  final VoidCallback onClose;

  const PlaylistView({
    super.key,
    required this.accentColor,
    required this.onClose,
  });

  @override
  ConsumerState<PlaylistView> createState() => _PlaylistViewState();
}

class _PlaylistViewState extends ConsumerState<PlaylistView> {
  // 用于跟踪当前播放的歌曲索引
  int? _currentPlayingIndex;

  @override
  Widget build(BuildContext context) {
    final playerService = ref.watch(ProviderManager.playerServiceProvider);
    final playlist = playerService.playlist;
    final currentIndex = playerService.currentIndex;

    // 如果当前索引变化，更新跟踪变量
    if (_currentPlayingIndex != currentIndex) {
      _currentPlayingIndex = currentIndex;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26), // 0.1 opacity (26/255)
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部标题栏
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '播放列表',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${playlist.length}首',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.accentColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // 清空播放列表按钮
                    if (playlist.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.clear_all),
                          onPressed: () {
                            _showClearPlaylistDialog(context, playerService);
                          },
                          color: Colors.red[400],
                          tooltip: '清空播放列表',
                        ),
                      ),
                    // 关闭按钮
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                      color: Colors.grey[700],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 播放列表
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
              minHeight: 100,
            ),
            child: playlist.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.queue_music_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '播放列表为空',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '请先添加歌曲到播放列表',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlist.length,
                    itemBuilder: (context, index) {
                      final song = playlist[index];
                      final isCurrentSong = index == currentIndex;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4.0),
                          child: song.cover != null && song.cover!.isNotEmpty
                              ? Image.network(
                                  ImageUtils.getThumbnailUrl(song.cover!),
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 40,
                                      height: 40,
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.music_note,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.music_note,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        title: Text(
                          song.title,
                          style: TextStyle(
                            color: isCurrentSong
                                ? widget.accentColor
                                : Colors.black87,
                            fontWeight: isCurrentSong
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          song.artist,
                          style: TextStyle(
                            color: isCurrentSong
                                ? widget.accentColor.withAlpha(200)
                                : Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isCurrentSong
                            ? Icon(
                                Icons.volume_up,
                                color: widget.accentColor,
                                size: 18,
                              )
                            : null,
                        onTap: () {
                          if (!isCurrentSong) {
                            // 更新播放列表中的当前索引
                            playerService.updateCurrentIndex(index);

                            // 播放新歌曲
                            playerService.play(song);

                            // 更新当前播放索引
                            setState(() {
                              _currentPlayingIndex = index;
                            });

                            // 关闭播放列表
                            widget.onClose();
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 显示清空播放列表对话框
  void _showClearPlaylistDialog(
      BuildContext context, PlayerService playerService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空播放列表'),
        content: const Text('确定要清空当前播放列表吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // 清空播放列表
              playerService.clearPlaylist();
              Navigator.pop(context); // 关闭对话框
              Navigator.pop(context); // 关闭播放列表弹窗
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}
