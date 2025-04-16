import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lyric_utils.dart'; // Import utility functions
import 'lyric_widget.dart'; // Import LyricLine
import '../../data/models/play_song_info.dart';

/// Album bottom lyrics display widget showing three lines of lyrics
/// Each line can display up to two lines of text with ellipsis for overflow
class MiniLyricWidget extends ConsumerWidget {
  final List<LyricLine> lyrics;
  final Duration position;
  final PlaySongInfo currentSong;
  final Color accentColor;
  final Function() onTap;

  const MiniLyricWidget({
    super.key,
    required this.lyrics,
    required this.position,
    required this.currentSong,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = getCurrentLyricIndex(lyrics, position);

    String currentLyric = '';
    String nextLyric = '';

    if (lyrics.isNotEmpty) {
      if (currentIndex >= 0 && currentIndex < lyrics.length) {
        currentLyric = lyrics[currentIndex].text;
      }
      if (currentIndex + 1 < lyrics.length) {
        nextLyric = lyrics[currentIndex + 1].text;
      }
    }

    // If no lyrics are available or parsed, display default text
    if (lyrics.isEmpty || currentLyric.isEmpty && nextLyric.isEmpty) {
      currentLyric = 'No lyrics available';
      nextLyric = currentSong.title; // Show song title as fallback
    }

    return GestureDetector(
      onTap: onTap, // Allow tapping to potentially open full lyrics
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
        constraints: const BoxConstraints(
            minHeight:
                100), // Ensure minimum height for three lines with 2 lines each
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Take minimum vertical space
          children: [
            Text(
              currentLyric,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
                color: accentColor, // Highlight color
                shadows: const [
                  Shadow(
                    offset: Offset(0.5, 0.5),
                    blurRadius: 1.0,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6.0), // Increased spacing between lines
            // Next lyric line (dimmed)
            Text(
              nextLyric,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.0,
                color: Colors.white.withAlpha(179), // 0.7 opacity (179/255)
                shadows: const [
                  Shadow(
                    offset: Offset(0.5, 0.5),
                    blurRadius: 1.0,
                    color: Colors.black45,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
