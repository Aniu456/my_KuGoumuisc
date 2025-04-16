import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../data/models/play_song_info.dart';
import 'lyric_utils.dart';

//歌词页面歌词
class LyricWidget extends ConsumerStatefulWidget {
  final List<LyricLine> lyrics;
  final int currentIndex;
  final PlaySongInfo currentSong;
  final Color accentColor;
  final Function onClose;
  final Duration position;

  const LyricWidget({
    super.key,
    required this.lyrics,
    required this.currentIndex,
    required this.currentSong,
    required this.accentColor,
    required this.onClose,
    required this.position,
  });

  @override
  ConsumerState<LyricWidget> createState() => _LyricWidgetState();
}

class _LyricWidgetState extends ConsumerState<LyricWidget>
    with TickerProviderStateMixin {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  int _lastScrolledIndex = -1;
  bool _userScrolling = false;
  Timer? _scrollResumeTimer;
  String? _lastSongId;

  static const double _scrollAlignment = 0.4;

  @override
  void initState() {
    super.initState();
    _lastSongId = widget.currentSong.hash;

    _itemPositionsListener.itemPositions.addListener(_onScrollChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.currentIndex >= 0) {
        _scrollToCurrentLyric(immediate: true);
      }
    });
  }

  @override
  void didUpdateWidget(LyricWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.currentSong.hash != _lastSongId) {
      _lastSongId = widget.currentSong.hash;
      _lastScrolledIndex = -1;
      _userScrolling = false;
      _scrollResumeTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _itemScrollController.jumpTo(index: 0, alignment: 0);
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted && widget.currentIndex >= 0) {
              _scrollToCurrentLyric(immediate: true);
            }
          });
        }
      });
      return;
    }

    if (widget.currentIndex != oldWidget.currentIndex && !_userScrolling) {
      if (widget.currentIndex >= 0 &&
          widget.currentIndex != _lastScrolledIndex) {
        _scrollToCurrentLyric();
      }
    }
  }

  @override
  void dispose() {
    _scrollResumeTimer?.cancel();
    _itemPositionsListener.itemPositions.removeListener(_onScrollChanged);
    super.dispose();
  }

  void _onScrollChanged() {
    if (_scrollResumeTimer == null || !_scrollResumeTimer!.isActive) {
      if (!_userScrolling) {
        setState(() {
          _userScrolling = true;
        });
      }
      _scrollResumeTimer?.cancel();
      _scrollResumeTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _userScrolling = false;
          });
          _scrollToCurrentLyric();
        }
      });
    } else {
      if (_userScrolling) {
        setState(() {
          _userScrolling = false;
        });
      }
    }
  }

  void _scrollToCurrentLyric({bool immediate = false}) {
    if (!mounted || !_itemScrollController.isAttached) return;

    int targetIndex = widget.currentIndex;
    if (targetIndex < 0 || targetIndex >= widget.lyrics.length) {
      return;
    }

    _lastScrolledIndex = targetIndex;

    if (immediate) {
      _itemScrollController.jumpTo(
        index: targetIndex,
        alignment: _scrollAlignment,
      );
    } else {
      _itemScrollController.scrollTo(
        index: targetIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        alignment: _scrollAlignment,
      );
    }
  }

  Widget _buildLyricLine(int index) {
    final line = widget.lyrics[index];
    final bool isCurrent = index == widget.currentIndex;

    final TextStyle currentStyle = TextStyle(
      color: widget.accentColor,
      fontSize: 19.0,
      fontWeight: FontWeight.bold,
      height: 1.8,
    );
    final TextStyle normalStyle = TextStyle(
      color: Colors.black.withOpacity(0.65),
      fontSize: 17.0,
      fontWeight: FontWeight.normal,
      height: 1.8,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      alignment: Alignment.center,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 300),
        style: isCurrent ? currentStyle : normalStyle,
        textAlign: TextAlign.center,
        child: Text(line.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics.isEmpty) {
      return Center(
        child: Text(
          '纯音乐，请欣赏',
          style: TextStyle(
            color: Colors.black.withOpacity(0.6),
            fontSize: 16.0,
          ),
        ),
      );
    }

    return Listener(
      onPointerDown: (_) {
        if (!_userScrolling) {
          setState(() {
            _userScrolling = true;
          });
        }
        _scrollResumeTimer?.cancel();
      },
      onPointerUp: (_) {
        _scrollResumeTimer?.cancel();
        _scrollResumeTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _userScrolling = false;
            });
            _scrollToCurrentLyric();
          }
        });
      },
      child: ScrollablePositionedList.builder(
        itemCount: widget.lyrics.length,
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositionsListener,
        padding: EdgeInsets.symmetric(
          vertical: MediaQuery.of(context).size.height * 0.3,
          horizontal: 20.0,
        ),
        itemBuilder: (context, index) {
          return _buildLyricLine(index);
        },
      ),
    );
  }
}
