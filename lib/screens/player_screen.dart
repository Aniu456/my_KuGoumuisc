import 'package:flutter/material.dart';
import '../core/responsive.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Responsive.isPortrait(context)
            ? _buildPortraitLayout(context)
            : _buildLandscapeLayout(context),
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      children: [
        // 顶部操作栏
        _buildTopBar(context),

        // 专辑封面
        Expanded(
          flex: 5,
          child: _buildAlbumCover(context),
        ),

        // 歌曲信息
        Expanded(
          flex: 4,
          child: _buildSongInfo(context),
        ),

        // 播放控制
        Expanded(
          flex: 2,
          child: _buildPlayControls(context),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      children: [
        // 左侧专辑信息
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildTopBar(context),
              _buildAlbumCover(context),
              _buildSongInfo(context, isLandscape: true),
            ],
          ),
        ),
        // 右侧歌词和控制
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Expanded(
                child: _buildLyrics(context),
              ),
              _buildPlayControls(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.getDynamicWidth(context, 16),
        vertical: Responsive.getDynamicHeight(context, 8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            color: Colors.white,
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'I Hate Falling in Love',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            color: Colors.white,
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCover(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(Responsive.getDynamicSize(context, 16)),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          'https://example.com/album_cover.jpg', // 替换为实际的专辑封面URL
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[900],
              child: Icon(
                Icons.music_note,
                size: Responsive.getDynamicSize(context, 80),
                color: Colors.white24,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSongInfo(BuildContext context, {bool isLandscape = false}) {
    return Padding(
      padding: EdgeInsets.all(Responsive.getDynamicSize(context, 16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Stevie Hoang',
            style: TextStyle(
              color: Colors.white70,
              fontSize: Responsive.getResponsiveFontSize(
                context,
                isLandscape ? 14 : 16,
              ),
            ),
          ),
          SizedBox(height: Responsive.getDynamicSize(context, 8)),
          _buildProgressBar(context),
          SizedBox(height: Responsive.getDynamicSize(context, 8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0:04',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: Responsive.getResponsiveFontSize(context, 12),
                ),
              ),
              Text(
                '3:40',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: Responsive.getResponsiveFontSize(context, 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: Responsive.getDynamicSize(context, 2),
        thumbShape: RoundSliderThumbShape(
          enabledThumbRadius: Responsive.getDynamicSize(context, 6),
        ),
        overlayShape: RoundSliderOverlayShape(
          overlayRadius: Responsive.getDynamicSize(context, 16),
        ),
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
        overlayColor: Colors.white24,
      ),
      child: Slider(
        value: 0.1,
        onChanged: (value) {
          // TODO: 实现进度控制
        },
      ),
    );
  }

  Widget _buildPlayControls(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          color: Colors.white,
          iconSize: Responsive.getResponsiveIconSize(context, 32),
          onPressed: () {
            // TODO: 实现上一首
          },
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.play_arrow),
            color: Colors.white,
            iconSize: Responsive.getResponsiveIconSize(context, 48),
            onPressed: () {
              // TODO: 实现播放/暂停
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next),
          color: Colors.white,
          iconSize: Responsive.getResponsiveIconSize(context, 32),
          onPressed: () {
            // TODO: 实现下一首
          },
        ),
      ],
    );
  }

  Widget _buildLyrics(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Responsive.getDynamicSize(context, 16)),
      child: ListView(
        children: [
          Text(
            'Just when I thought I could changed\n就在我以为我可以改变的时候\n\n'
            'I end up falling again\n我再次沦陷\n\n'
            'It\'s something I just can\'t fight\n这是我无法抗拒的事情',
            style: TextStyle(
              color: Colors.white70,
              fontSize: Responsive.getResponsiveFontSize(context, 16),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
