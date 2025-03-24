
// import 'package:video_player/video_player.dart';
// import 'package:flutter/material.dart';

// import '../../../utils/app_colors.dart';

// class HlsVideoPlayer extends StatefulWidget {
//   Map map;


//    HlsVideoPlayer({super.key, required this.map,});

//   @override
//   _HlsVideoPlayerState createState() => _HlsVideoPlayerState();
// }

// class _HlsVideoPlayerState extends State<HlsVideoPlayer> {
//   late VideoPlayerController _controller;

//   @override
//   void initState() {
//     super.initState();
//     _initializePlayer();
//   }

//   void _initializePlayer() {
//     // Generate Signed Cookies
//     var key = widget.map["keyPairId"];
//     var policy = widget.map["policy"];
//     var signature = widget.map["signature"];
//     final String cookies = 'CloudFront-Key-Pair-Id=${key}; CloudFront-Policy=${policy}; CloudFront-Signature=${signature}';


//     _controller = VideoPlayerController.networkUrl(
//       Uri.parse(widget.map['url']),
//       httpHeaders: {
//         'Cookie': cookies,
//         'Referer' : "https://nplflix-content-secure.bizalpha.ca"
//       },
//     )
//       ..initialize().then((_) {
//         setState(() {});
//         _controller.play();
//       })
//       ..addListener(() {
//         if (!_controller.value.isPlaying && _controller.value.isInitialized && _controller.value.position == _controller.value.duration) {
//           // Video finished playing
//         }
//       });
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.profileScreenBackground,
//       appBar: AppBar(
//         title: Text(  widget.map["name"],
//           style: TextStyle(
//               color: Colors.white
//           ),),
//         backgroundColor: AppColors.backgroundColor,
//         iconTheme: IconThemeData(color: Colors.white),
//       ),
//       body: Center(
//         child: _controller.value.isInitialized
//             ? AspectRatio(
//           aspectRatio: _controller.value.aspectRatio,
//           child: VideoPlayer(_controller),
//         )
//             : const CircularProgressIndicator(),
//       ),
//     );
//   }
// }
