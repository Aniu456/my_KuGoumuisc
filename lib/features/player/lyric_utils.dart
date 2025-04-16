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
              ? int.parse(match.group(3)!.padRight(
                  3, '0')) // Pad to 3 digits if needed (e.g., .5 -> .500)
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

  // 如果播放位置在第一行歌词之前
  if (position < lyrics.first.time) {
    // 如果距离第一行歌词不到800毫秒，则提前显示
    if (lyrics.first.time.inMilliseconds - position.inMilliseconds < 800) {
      return 0; // 提前显示第一行歌词
    }
    return -1;
  }

  // 如果播放位置在最后一行歌词之后
  if (position >= lyrics.last.time) {
    return lyrics.length - 1; // 显示最后一行歌词
  }

  // 优化的查找算法，使用二分查找来提高效率
  int low = 0;
  int high = lyrics.length - 1;

  while (low <= high) {
    int mid = (low + high) ~/ 2;

    // 如果是最后一行，直接返回
    if (mid == lyrics.length - 1) {
      return mid;
    }

    // 如果当前位置在当前行和下一行之间，则找到了目标
    if (position >= lyrics[mid].time && position < lyrics[mid + 1].time) {
      return mid;
    }

    // 如果当前位置在当前行之前，则在左半部分查找
    if (position < lyrics[mid].time) {
      high = mid - 1;
    } else {
      // 否则在右半部分查找
      low = mid + 1;
    }
  }

  // 如果没有找到匹配的行（这种情况理论上不应该发生），返回最接近的行
  int closestIndex = 0;
  int minDifference =
      (position.inMilliseconds - lyrics[0].time.inMilliseconds).abs();

  for (int i = 1; i < lyrics.length; i++) {
    int difference =
        (position.inMilliseconds - lyrics[i].time.inMilliseconds).abs();
    if (difference < minDifference) {
      minDifference = difference;
      closestIndex = i;
    }
  }

  return closestIndex;
}

// 歌词行数据类
class LyricLine {
  final Duration time;
  final String text;

  LyricLine(this.time, this.text);
}
