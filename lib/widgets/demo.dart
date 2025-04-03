// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'dart:ui';
// import '../services/player_service.dart';
// import 'package:marquee/marquee.dart';
// import '../utils/image_utils.dart';

// class PlayerPage extends StatelessWidget {
//   const PlayerPage({super.key});

//   IconData _getPlayModeIcon(PlayMode mode) {
//     switch (mode) {
//       case PlayMode.loop:
//         return Icons.repeat;
//       case PlayMode.single:
//         return Icons.repeat_one;
//       case PlayMode.sequence:
//         return Icons.sync;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final playerService = context.watch<PlayerService>();
//     final currentSong = playerService.currentSong;
//     final screenWidth = MediaQuery.of(context).size.width;

//     return Scaffold(
//       body: Stack(
//         children: [
//           // 背景图片层
//           if (currentSong?.cover != null) ...[
//             Positioned.fill(
//               child: ImageUtils.createCachedImage(
//                 ImageUtils.getLargeUrl(currentSong!.cover),
//                 fit: BoxFit.cover,
//               ),
//             ),
//             // 模糊效果层
//             Positioned.fill(
//               child: BackdropFilter(
//                 filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
//                 child: Container(
//                   color: Colors.black.withOpacity(0.2),
//                 ),
//               ),
//             ),
//             // 渐变遮罩层
//             Positioned.fill(
//               child: Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                     colors: [
//                       Colors.black.withOpacity(0.3),
//                       Colors.black.withOpacity(0.5),
//                       Colors.black.withOpacity(0.7),
//                       Colors.black.withOpacity(0.9),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],

//           // 内容层
//           SafeArea(
//             child: Column(
//               children: [
//                 // 顶部栏
//                 Padding(
//                   padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       IconButton(
//                         icon: const Icon(
//                           Icons.keyboard_arrow_down,
//                           color: Colors.white,
//                           size: 32,
//                         ),
//                         onPressed: () => Navigator.pop(context),
//                       ),
//                       IconButton(
//                         icon: const Icon(
//                           Icons.more_horiz,
//                           color: Colors.white,
//                           size: 32,
//                         ),
//                         onPressed: () {
//                           // TODO: 显示更多选项
//                         },
//                       ),
//                     ],
//                   ),
//                 ),

//                 // 歌曲信息
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 32),
//                   child: Column(
//                     children: [
//                       SizedBox(
//                         height: 32,
//                         child: currentSong != null
//                             ? LayoutBuilder(
//                                 builder: (context, constraints) {
//                                   // 测量文本宽度
//                                   final textSpan = TextSpan(
//                                     text: currentSong.title,
//                                     style: const TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 24,
//                                       fontWeight: FontWeight.w600,
//                                     ),
//                                   );
//                                   final textPainter = TextPainter(
//                                     text: textSpan,
//                                     textDirection: TextDirection.ltr,
//                                   )..layout(maxWidth: double.infinity);

//                                   // 如果文本宽度超过容器宽度，使用跑马灯效果
//                                   return textPainter.width >
//                                           constraints.maxWidth
//                                       ? Marquee(
//                                           text: currentSong.title,
//                                           style: const TextStyle(
//                                             color: Colors.white,
//                                             fontSize: 24,
//                                             fontWeight: FontWeight.w600,
//                                           ),
//                                           scrollAxis: Axis.horizontal,
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           blankSpace: 80.0,
//                                           velocity: 30.0,
//                                           pauseAfterRound:
//                                               const Duration(seconds: 2),
//                                           startPadding: 10.0,
//                                           accelerationDuration:
//                                               const Duration(seconds: 1),
//                                           accelerationCurve: Curves.linear,
//                                           decelerationDuration:
//                                               const Duration(milliseconds: 500),
//                                           decelerationCurve: Curves.easeOut,
//                                         )
//                                       : Text(
//                                           currentSong.title,
//                                           style: const TextStyle(
//                                             color: Colors.white,
//                                             fontSize: 24,
//                                             fontWeight: FontWeight.w600,
//                                           ),
//                                         );
//                                 },
//                               )
//                             : const SizedBox(),
//                       ),
//                       const SizedBox(height: 8),
//                       SizedBox(
//                         height: 24,
//                         child: currentSong != null
//                             ? LayoutBuilder(
//                                 builder: (context, constraints) {
//                                   final textSpan = TextSpan(
//                                     text: currentSong.artists,
//                                     style: const TextStyle(
//                                       color: Colors.white70,
//                                       fontSize: 18,
//                                     ),
//                                   );
//                                   final textPainter = TextPainter(
//                                     text: textSpan,
//                                     textDirection: TextDirection.ltr,
//                                   )..layout(maxWidth: double.infinity);

//                                   return textPainter.width >
//                                           constraints.maxWidth
//                                       ? Marquee(
//                                           text: currentSong.artists,
//                                           style: const TextStyle(
//                                             color: Colors.white70,
//                                             fontSize: 18,
//                                           ),
//                                           scrollAxis: Axis.horizontal,
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           blankSpace: 80.0,
//                                           velocity: 30.0,
//                                           pauseAfterRound:
//                                               const Duration(seconds: 2),
//                                           startPadding: 10.0,
//                                           accelerationDuration:
//                                               const Duration(seconds: 1),
//                                           accelerationCurve: Curves.linear,
//                                           decelerationDuration:
//                                               const Duration(milliseconds: 500),
//                                           decelerationCurve: Curves.easeOut,
//                                         )
//                                       : Text(
//                                           currentSong.artists,
//                                           style: const TextStyle(
//                                             color: Colors.white70,
//                                             fontSize: 18,
//                                           ),
//                                         );
//                                 },
//                               )
//                             : const SizedBox(),
//                       ),
//                     ],
//                   ),
//                 ),

//                 // 专辑封面
//                 Expanded(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Container(
//                         width: screenWidth - 64,
//                         height: screenWidth - 64,
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(screenWidth / 20),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.15),
//                               blurRadius: 30,
//                               offset: const Offset(0, 15),
//                             ),
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.1),
//                               blurRadius: 10,
//                               offset: const Offset(0, 5),
//                             ),
//                           ],
//                         ),
//                         child: ClipRRect(
//                           borderRadius: BorderRadius.circular(screenWidth / 20),
//                           child: ImageUtils.createCachedImage(
//                             ImageUtils.getLargeUrl(currentSong?.cover ?? ''),
//                             width: screenWidth - 64,
//                             height: screenWidth - 64,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//                 // 底部控制区
//                 Container(
//                   padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
//                   child: Column(
//                     children: [
//                       // 功能按钮
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                         children: [
//                           IconButton(
//                             icon: Icon(
//                               playerService.isShuffleMode
//                                   ? Icons.shuffle
//                                   : Icons.shuffle_outlined,
//                               color: playerService.isShuffleMode
//                                   ? Colors.blue
//                                   : Colors.white,
//                               size: 28,
//                             ),
//                             onPressed: playerService.toggleShuffleMode,
//                           ),
//                           IconButton(
//                             icon: const Icon(
//                               Icons.skip_previous,
//                               color: Colors.white,
//                               size: 44,
//                             ),
//                             onPressed: playerService.canPlayPrevious
//                                 ? playerService.playPrevious
//                                 : null,
//                           ),
//                           IconButton(
//                             icon: Icon(
//                               playerService.isPlaying
//                                   ? Icons.pause_circle_filled
//                                   : Icons.play_circle_fill,
//                               color: Colors.white,
//                               size: 80,
//                             ),
//                             onPressed: playerService.togglePlay,
//                           ),
//                           IconButton(
//                             icon: const Icon(
//                               Icons.skip_next,
//                               color: Colors.white,
//                               size: 44,
//                             ),
//                             onPressed: playerService.canPlayNext
//                                 ? playerService.playNext
//                                 : null,
//                           ),
//                           IconButton(
//                             icon: Icon(
//                               _getPlayModeIcon(playerService.playMode),
//                               color: playerService.playMode == PlayMode.single
//                                   ? Colors.blue
//                                   : Colors.white,
//                               size: 28,
//                             ),
//                             onPressed: playerService.togglePlayMode,
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
