// import 'dart:async';

// import 'package:better_player_plus/better_player_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_volume_controller/flutter_volume_controller.dart';
// import 'package:npflix/controller/watch_time_controller.dart';
// // import 'package:npflix/utils/app_colors.dart';
// // import 'package:npflix/utils/helper_methods.dart';
// // import 'package:provider/provider.dart';
// import 'package:screen_brightness/screen_brightness.dart';
// import 'package:wakelock_plus/wakelock_plus.dart';
// // import '../../../sources/shared_preferences.dart';


// class VideoPlayerScreen extends StatefulWidget {
//   final Map map;
//   VideoPlayerScreen({Key? key, required this.map}) : super(key: key);

//   @override
//   State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
// }

// class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
//   BetterPlayerController? _betterPlayerController;
//   // late WatchTimeController _watchTimeController;
//   double _videoScale = 1.0;
//   double _baseScale = 1.0;
//   double _brightness = 0.5;
//   double _volume = 0.5;
//   bool _showControls = true;
//   Timer? _hideControlsTimer;

//   Future<void> _getCurrentBrightness() async {
//     try {
//       double brightness = await ScreenBrightness().current;
//       setState(() {
//         _brightness = brightness;
//       });
//     } catch (e) {
//       debugPrint("Error getting brightness: $e");
//     }
//   }

//   Future<void> _setBrightness(double value) async {
//     try {
//       await ScreenBrightness().setScreenBrightness(value);
//       setState(() {
//         _brightness = value;
//       });
//     } catch (e) {
//       debugPrint("Error setting brightness: $e");
//     }
//   }

//   Future<void> _getCurrentVolume() async {
//     try {
//       double? volume = await FlutterVolumeController.getVolume();
//       setState(() {
//         _volume = volume!;
//       });
//     } catch (e) {
//       debugPrint("Error getting volume: $e");
//     }
//   }

//   Future<void> _setVolume(double value) async {
//     try {
//       await FlutterVolumeController.setVolume(value);
//       setState(() {
//         _volume = value;
//       });
//     } catch (e) {
//       debugPrint("Error setting volume: $e");
//     }
//   }

//   void _toggleControls() {
//     print("Change visiblity");
//     setState(() {
//       _showControls = !_showControls;
//       print("Visibility controler $_showControls");
//     });
//     _betterPlayerController?.setControlsVisibility(_showControls);
//     if (_showControls) {
//       _resetHideControlsTimer();
//     }
//   }

//   void _resetHideControlsTimer() {
//     _hideControlsTimer?.cancel();
//     _hideControlsTimer = Timer(Duration(seconds: 3), () {
//       setState(() {
//         _showControls = false;
//       });
//     });
//   }

//   @override
//   void initState() {
//     super.initState();
//     WakelockPlus.enable();
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.landscapeLeft,
//       DeviceOrientation.landscapeRight,
//     ]);
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); // Hide system UI
//     _initializePlayer();
//     _getCurrentBrightness();
//     _getCurrentVolume();
//   }

//   @override
//   void dispose() {
//     _betterPlayerController?.pause();
//     WakelockPlus.disable();
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.portraitUp,
//     ]);
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values); // Show status & nav bars
//     _betterPlayerController?.videoPlayerController?.position.then((currentPosition) async {
//       if (currentPosition != null) {
//         await _watchTimeController.addWatchTime(
//           widget.map["uuId"],
//           widget.map["contentId"],
//           currentPosition.inSeconds,
//         );
//       }
//       _betterPlayerController?.dispose();
//       super.dispose();
//     });
//   }

//   void _initializePlayer() {
//     _watchTimeController = Provider.of<WatchTimeController>(context, listen: false);
//     var key = widget.map["keyPairId"];
//     var policy = widget.map["policy"];
//     var signature = widget.map["signature"];
//     final String cookies =
//         'CloudFront-Key-Pair-Id=$key; CloudFront-Policy=${policy}; CloudFront-Signature=${signature}';

//     try {
//       BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(
//         aspectRatio: 16 / 9,
//         fit: BoxFit.contain,
//         autoPlay: true,
//         autoDispose: true,
//         startAt: Duration(seconds: widget.map["watchedTime"]),
//         looping: true,
//         controlsConfiguration: BetterPlayerControlsConfiguration(

//           enableProgressBar: true,
//           enablePlayPause: false,
//           enableSubtitles: true,
//           enableOverflowMenu: true,
//           enableFullscreen: false, // Disable fullscreen button
//           showControls: _showControls,
//           enablePlaybackSpeed: false,
//           enableQualities: false
//         ),
//       );


//       BetterPlayerDataSource dataSource = BetterPlayerDataSource(
//         BetterPlayerDataSourceType.network,
//         widget.map["url"],
//         videoFormat: BetterPlayerVideoFormat.hls,
//         drmConfiguration: BetterPlayerDrmConfiguration(
//           drmType: BetterPlayerDrmType.token,
//           licenseUrl: "https://nplflix-content.bizalpha.ca/",
//         ),
//         headers: {'Cookie': cookies},
//         subtitles: [
//           for (int i = 0; i < widget.map["captions"].length; i++)
//             BetterPlayerSubtitlesSource(
//               type: BetterPlayerSubtitlesSourceType.network,
//               urls: [widget.map['captions'][i].captionFilePath],
//               name: widget.map['captions'][i].captionFileName,
//             ),
//         ],
//       );



//       _betterPlayerController = BetterPlayerController(betterPlayerConfiguration)
//         ..setupDataSource(dataSource)
//         ..addEventsListener((event){
//           if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
//              _setDefaultSubtitles();
//           }
//         });

//     } catch (e) {
//       debugPrint("Error initializing BetterPlayer: $e");
//     }
//     _resetHideControlsTimer();
//   }

//  // Auto-select English subtitles after the player is initialized
//   void _setDefaultSubtitles() {
//     var isEnglish = SharedPreferenceManager.sharedInstance.getString("language_code") == "en" ? "English" : "Nepali";
//     for (int i = 0; i < widget.map["captions"].length; i++){
//       if(widget.map['captions'][i].captionFileName.toString().contains(isEnglish)){
//         _betterPlayerController?.setupSubtitleSource(
//           BetterPlayerSubtitlesSource(
//             type: BetterPlayerSubtitlesSourceType.network,
//             urls: [widget.map['captions'][i].captionFilePath],
//             name: widget.map['captions'][i].captionFileName,
//           ),
//         );
//       }
//     }
//   }



//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.profileScreenBackground,
//       body: GestureDetector(
//         onScaleStart: (details) {
//           _baseScale = _videoScale;
//         },
//         onScaleUpdate: (ScaleUpdateDetails details) {
//           setState(() {
//             _videoScale = (_baseScale * details.scale).clamp(1.0, 1.07);
//           });
//         },
//         child: Stack(
//           children: [
//             Center(
//               child: Transform.scale(
//                 scale: _videoScale,
//                 child: AspectRatio(
//                   aspectRatio: 16 / 9,
//                   child: _betterPlayerController != null
//                       ? BetterPlayer(controller: _betterPlayerController!)
//                       : CircularProgressIndicator(),
//                 ),
//               ),
//             ),
//             GestureDetector(
//               onTap: _toggleControls,

//               child: Center(
//                 child: Visibility(
//                   visible: !_showControls,
//                   child: Container(
//                     height: Helper.dynamicHeight(context, 100),
//                     width: Helper.dynamicWidth(context, 100),
//                     color: Colors.transparent,
//                   ),
//                 ),
//               ),
//             ),

//             Visibility(
//               visible: _showControls,
//               child: Positioned(
//                 top: 0,
//                 right: 20,
//                 left: 20,
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     IconButton(
//                       icon: Icon(Icons.close, color: Colors.white, size: 30),
//                       onPressed: () async {
//                         await SystemChrome.setPreferredOrientations([
//                           DeviceOrientation.portraitUp, // Force portrait before exiting
//                         ]);
//                         Navigator.pop(context); // Close the screen
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//             // Vertical Brightness Slider on the Left
//             Visibility(
//               visible: _showControls,
//               child: Positioned(
//                 left: 20,
//                 top: MediaQuery.of(context).size.height * 0.2,
//                 bottom: MediaQuery.of(context).size.height * 0.1,
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.brightness_6, color: Colors.white, size: 20),
//                     RotatedBox(
//                       quarterTurns: 3,
//                       child: Slider(
//                         value: _brightness,
//                         min: 0.0,
//                         max: 1.0,
//                         onChanged: (value) {
//                           _setBrightness(value);
//                         },
//                         activeColor: Colors.white,
//                         inactiveColor: Colors.grey,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             // Volume Slider (Right Side)
//             Visibility(
//               visible: _showControls,
//               child: Positioned(
//                 right: 35,
//                 top: MediaQuery.of(context).size.height * 0.2,
//                 bottom: MediaQuery.of(context).size.height * 0.1,
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.volume_up, color: Colors.white, size: 20),
//                     RotatedBox(
//                       quarterTurns: 3,
//                       child: Slider(
//                         value: _volume,
//                         min: 0.0,
//                         max: 1.0,
//                         onChanged: (value) {
//                           _setVolume(value);
//                         },
//                         activeColor: Colors.white,
//                         inactiveColor: Colors.grey,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),



//           ],
//         ),
//       ),
//     );
//   }
// }
