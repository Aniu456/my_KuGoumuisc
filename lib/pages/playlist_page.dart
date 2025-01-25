import 'package:flutter/material.dart';
import '../models/song.dart';
import '../widgets/song_list_item.dart';

class PlaylistPage extends StatelessWidget {
  final String title;
  final List<Song> songs;

  const PlaylistPage({
    super.key,
    required this.title,
    required this.songs,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          return SongListItem(
            song: songs[index],
            playlist: songs,
            index: index,
          );
        },
      ),
    );
  }
}
