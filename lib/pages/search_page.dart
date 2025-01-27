import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/api_service.dart';
import '../services/player_service.dart';
import '../models/play_song_info.dart';
import '../models/search_response.dart';
import '../pages/player_page.dart';
import '../utils/image_utils.dart';

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
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '搜索音乐、歌手、歌词',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[400]),
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

                return ListTile(
                  title: Text(
                    song.songName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15),
                  ),
                  subtitle: Text(
                    singerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
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
                );
              },
            ),
    );
  }
}
