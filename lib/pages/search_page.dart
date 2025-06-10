import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_music_app/utils/image_utils.dart';
import '../services/api_service.dart';
import '../services/player_service.dart';
import '../models/play_song_info.dart';
import '../models/search_response.dart';
import '../pages/player_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchSong> _searchResults = [];
  bool _isLoading = false;

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await context.read<ApiService>().searchSongs(keyword);
      if (!mounted) return;

      setState(() {
        _searchResults = response.lists;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('搜索失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerService = context.watch<PlayerService>();
    final currentSong = playerService.currentSongInfo;
    final isPlayingGlobal = playerService.isPlaying;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '搜索音乐、歌手、歌词....',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _search,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final song = _searchResults[index];
                final singerName =
                    song.singers.isNotEmpty ? song.singers[0].name : '';
                final isCurrentSong =
                    currentSong != null && song.fileHash == currentSong.hash;
                final isPlaying = isPlayingGlobal && isCurrentSong;

                // 定义与 music_list_screen.dart 中相似的颜色常量
                const Color backgroundColor = Color(0xFF4169E1);

                return Container(
                  decoration: BoxDecoration(
                    color: isCurrentSong
                        ? backgroundColor.withOpacity(0.05)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    leading: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 歌曲封面
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: (song.image.isNotEmpty)
                                ? Image.network(
                                    ImageUtils.getThumbnailUrl(song.image),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: Icon(
                                          Icons.music_note,
                                          color: Colors.grey[400],
                                          size: 24,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: Colors.grey[200],
                                    child: Icon(
                                      Icons.music_note,
                                      color: Colors.grey[400],
                                      size: 24,
                                    ),
                                  ),
                          ),
                        ),

                        // 正在播放的歌曲显示播放图标
                        if (isPlaying)
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      song.songName.isNotEmpty
                          ? song.songName
                          : song.fileName.isNotEmpty
                              ? song.fileName
                              : '歌曲名缺失',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrentSong ? backgroundColor : Colors.black87,
                        fontWeight:
                            isCurrentSong ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        singerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrentSong
                              ? backgroundColor.withOpacity(0.7)
                              : Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.grey[500],
                        size: 20,
                      ),
                      onPressed: () {
                        // TODO: Implement song options for search results
                      },
                    ),
                    onTap: () async {
                      try {
                        final playerService = context.read<PlayerService>();
                        final songInfo = PlaySongInfo.fromSearchSong(song);

                        // 导航到播放页面
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PlayerPage(),
                          ),
                        );

                        // 播放歌曲
                        await playerService.play(songInfo);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('播放失败: $e')),
                          );
                        }
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
