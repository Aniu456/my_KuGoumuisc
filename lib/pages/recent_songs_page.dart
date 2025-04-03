import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recent_song.dart';
import '../services/api_service.dart';
import '../models/song.dart';
import '../widgets/song_list_item.dart';

class RecentSongsPage extends StatefulWidget {
  const RecentSongsPage({super.key});

  @override
  State<RecentSongsPage> createState() => _RecentSongsPageState();
}

class _RecentSongsPageState extends State<RecentSongsPage> {
  bool _isLoading = false;
  List<RecentSong> _recentSongs = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSongs();
  }

  Future<void> _loadRecentSongs() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.getRecentSongs();

      setState(() {
        _recentSongs = response.songs;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载最近播放失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('最近播放'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recentSongs.isEmpty
              ? const Center(child: Text('暂无播放记录'))
              : ListView.builder(
                  itemCount: _recentSongs.length,
                  itemBuilder: (context, index) {
                    final recentSong = _recentSongs[index];
                    final song = Song(
                      hash: recentSong.hash,
                      name: '${recentSong.singername} - ${recentSong.name}',
                      cover: recentSong.cover,
                      albumId: '',
                      audioId: '',
                      size: 0,
                      singerName: recentSong.singername,
                      albumImage: recentSong.cover,
                    );

                    return SongListItem(
                      song: song,
                      playlist: [song],
                      index: 0,
                    );
                  },
                ),
    );
  }
}
