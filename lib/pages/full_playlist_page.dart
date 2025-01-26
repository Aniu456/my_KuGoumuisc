import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/player_service.dart';
import '../models/song.dart';
import '../models/play_song_info.dart';

class FullPlaylistPage extends StatefulWidget {
  const FullPlaylistPage({super.key});

  @override
  State<FullPlaylistPage> createState() => _FullPlaylistPageState();
}

class _FullPlaylistPageState extends State<FullPlaylistPage> {
  List<PlaySongInfo> _filteredSongs = [];
  String _searchQuery = '';

  void _filterSongs(PlayerService playerService) {
    if (_searchQuery.isEmpty) {
      _filteredSongs = List.from(playerService.playlist);
    } else {
      _filteredSongs = playerService.playlist.where((song) {
        final name = song.title.toLowerCase();
        final singer = song.artist.toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || singer.contains(query);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('播放列表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate:
                    _PlaylistSearchDelegate(context.read<PlayerService>()),
              ).then((query) {
                if (query != null) {
                  setState(() {
                    _searchQuery = query;
                    _filterSongs(context.read<PlayerService>());
                  });
                }
              });
            },
          ),
        ],
      ),
      body: Consumer<PlayerService>(
        builder: (context, playerService, _) {
          // 初始化过滤后的歌曲列表
          if (_filteredSongs.isEmpty && _searchQuery.isEmpty) {
            _filteredSongs = List.from(playerService.playlist);
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _searchQuery = '';
                _filteredSongs = List.from(playerService.playlist);
              });
            },
            child: _filteredSongs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.queue_music,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? '播放列表为空' : '未找到相关歌曲',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: kToolbarHeight),
                    itemCount: _filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = _filteredSongs[index];
                      final isPlaying =
                          song.hash == playerService.currentSongInfo?.hash;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            try {
                              await playerService.play(song);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('播放失败: $e')),
                                );
                              }
                            }
                          },
                          child: Container(
                            color: isPlaying
                                ? Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.05)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              child: Row(
                                children: [
                                  // 序号或播放状态
                                  SizedBox(
                                    width: 32,
                                    child: isPlaying
                                        ? Icon(
                                            Icons.volume_up,
                                            color:
                                                Theme.of(context).primaryColor,
                                            size: 18,
                                          )
                                        : Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  // 歌曲信息
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: isPlaying
                                                ? Theme.of(context).primaryColor
                                                : null,
                                            fontWeight: isPlaying
                                                ? FontWeight.w500
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          song.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isPlaying
                                                ? Theme.of(context)
                                                    .primaryColor
                                                    .withOpacity(0.7)
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 更多按钮
                                  IconButton(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: Colors.grey[600],
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      // TODO: 显示更多操作菜单
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _PlaylistSearchDelegate extends SearchDelegate<String?> {
  final PlayerService _playerService;

  _PlaylistSearchDelegate(this._playerService);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return const Center(
        child: Text('输入歌曲名称或歌手名称搜索'),
      );
    }

    final results = _playerService.playlist.where((song) {
      final name = song.title.toLowerCase();
      final singer = song.artist.toLowerCase();
      final searchQuery = query.toLowerCase();
      return name.contains(searchQuery) || singer.contains(searchQuery);
    }).toList();

    if (results.isEmpty) {
      return const Center(
        child: Text('未找到相关歌曲'),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final song = results[index];
        return ListTile(
          title: Text(song.title),
          subtitle: Text(song.artist),
          onTap: () {
            close(context, query);
          },
        );
      },
    );
  }
}
