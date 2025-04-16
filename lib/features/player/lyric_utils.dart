import 'lyric_widget.dart'; // For LyricLine

/// Parses LRC format lyrics text into a list of LyricLine objects.
/// Returns an empty list if the input is null or empty.
List<LyricLine> parseLyrics(String? lyricsText) {
  if (lyricsText == null || lyricsText.trim().isEmpty) {
    return [];
  }

  final List<LyricLine> lines = [];
  // Regular expression to match LRC time tags like [mm:ss.xx] or [mm:ss]
  final RegExp timeExp = RegExp(r'\[(\d{2,}):(\d{2,})(?:\.(\d{2,3}))?\]');

  // Split the text into lines
  final textLines = lyricsText.split('\n');

  for (final line in textLines) {
    final cleanLine = line.trim();
    if (cleanLine.isEmpty) continue;

    // Find all time tags in the current line
    final matches = timeExp.allMatches(cleanLine);

    if (matches.isNotEmpty) {
      // Extract the lyric text (part after the last time tag)
      final lastMatchEnd = matches.last.end;
      final lyricText = cleanLine.substring(lastMatchEnd).trim();

      // If there's actual lyric text, process each time tag
      if (lyricText.isNotEmpty) {
        for (final match in matches) {
          final minutes = int.parse(match.group(1)!);
          final seconds = int.parse(match.group(2)!);
          // Handle milliseconds, default to 0 if not present
          final milliseconds = (match.group(3) != null)
              ? int.parse(match.group(3)!.padRight(3, '0')) // Pad to 3 digits if needed (e.g., .5 -> .500)
              : 0;

          final time = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          );
          lines.add(LyricLine(time, lyricText));
        }
      }
    }
  }

  // Sort lyrics by time
  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}


/// Finds the index of the lyric line that should be currently highlighted
/// based on the playback position.
/// Returns -1 if no suitable line is found (e.g., before the first lyric).
int getCurrentLyricIndex(List<LyricLine> lyrics, Duration position) {
  if (lyrics.isEmpty) {
    return -1;
  }

  // Find the index of the first lyric line whose time is greater than the current position
  int index = lyrics.indexWhere((line) => line.time > position);

  // If no line's time is greater, it means the last line is playing or passed
  if (index == -1) {
    // Check if position is actually after the last lyric time
    if (position >= lyrics.last.time) {
      return lyrics.length - 1;
    } else {
      // This case might occur if position is before the first lyric but lyrics is not empty
      // It should technically be handled by index == 0 case, but added for robustness.
      return -1; // Or 0 if we want to highlight the first line immediately
    }
  }

  // If the first line's time is greater (index is 0), it means we are before the first lyric starts
  if (index == 0) {
    return -1; // Or 0 if you prefer to highlight the first line before it starts
  }

  // Otherwise, the correct lyric line is the one *before* the one found by indexWhere
  return index - 1;
}
