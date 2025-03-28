import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:http/http.dart' as http;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  bool _isScreenLocked = false;
  bool _isMaterialControlles = false;
  Timer? _materialControllesTimer;
  double _brightness = 0.5;
  double _volume = 0.5;
  double _scale = 1.0;
  double _initialScale = 1.0;

  Timer? _volumeSliderTimer;
  Timer? _brightnessSliderTimer;

  // Variables
  List<Caption> _captions = [];
  Caption? _selectedCaption;
  List<Subtitle> _subtitles = [];
  Subtitle? _currentSubtitle;
  bool _subtitlesEnabled = true;

  // Ad-related variables
  bool _isAdPlaying = false;
  bool _isLoadingAd = false;
  final List<int> _adTimePoints = [1, 60]; // Ad trigger points in seconds
  final List<String> _adVideoUrls = [
    'https://static.videezy.com/system/resources/previews/000/048/091/original/Countdown8.mp4', // Video ad for 1-second mark
    'https://static.videezy.com/system/resources/previews/000/048/091/original/Countdown8.mp4' // Video ad for 30-second mark
  ];
  VideoPlayerController? _adVideoController;
  int? _lastAdPlayedAtSecond;
  Timer? _adCheckTimer;

// Add these variables to your state class
  String _adRemainingTime = "00:00";
  Timer? _adCountdownTimer;

  // Add these variables to track seeking
  bool _isSeeking = false;
  DateTime? _lastSeekTime;
  // Add a flag to ensure first ad plays correctly
bool _hasPlayedFirstAd = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _initializeVolume();
    _initializeBrightness();
    setupCaptions(); // Load subtitles
    _initializeAdCheck(); // Initialize ad check timer

     // Add this to ensure the first ad plays correctly
  _scheduleFirstAd();
  

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky); // Hide system UI
    // Keep screen on during video playback
    WakelockPlus.enable();
  }

  // Function to ensure the first ad plays
void _scheduleFirstAd() {
  // Schedule first ad to play once the video starts
  Future.delayed(const Duration(milliseconds: 1500), () {
    if (!_hasPlayedFirstAd && mounted && _videoPlayerController.value.isInitialized) {
      _hasPlayedFirstAd = true;
      _lastAdPlayedAtSecond = 1;
      _showVideoAd(0); // Show first ad (index 0)
    }
  });
}

  // Initialize periodic ad check
  void _initializeAdCheck() {
    _adCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkAndShowAds();
    });
  }

// Update your checkAndShowAds method with better position tracking
void _checkAndShowAds() {
  if (_isAdPlaying || !_videoPlayerController.value.isInitialized || !_videoPlayerController.value.isPlaying) {
    return; // Don't check if ad is playing or video is not playing
  }

  // Skip if we're seeking
  if (_isSeeking) return;

  final currentPositionInSeconds = _videoPlayerController.value.position.inSeconds;
  
  // Check for each ad trigger point
  for (int i = 0; i < _adTimePoints.length; i++) {
    // Use a range check instead of exact position for more reliable triggering
    bool isNearTriggerPoint = (currentPositionInSeconds >= _adTimePoints[i] && 
                              currentPositionInSeconds < _adTimePoints[i] + 1);
                              
    if (isNearTriggerPoint && _lastAdPlayedAtSecond != _adTimePoints[i]) {
      print("Triggering ad at position: $currentPositionInSeconds seconds");
      _lastAdPlayedAtSecond = _adTimePoints[i];
      _showVideoAd(i);
      break;
    }
  }
}

Future<void> _showVideoAd(int adIndex) async {
  // Pause the main video
  _videoPlayerController.pause();
  setState(() {
    _isAdPlaying = true;
    _isLoadingAd = true;
  });

  // Show loading immediately
  BuildContext? dialogContext;
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black,
    transitionDuration: Duration.zero,
    pageBuilder: (context, animation1, animation2) {
      dialogContext = context;
      return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 20),
                Text("Loading advertisement...", style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      );
    },
  );

  try {
    // Clean up any existing controller
    if (_adVideoController != null) {
      await _adVideoController!.dispose();
      _adVideoController = null;
    }
    
    // Simply use the URL from your list
    _adVideoController = VideoPlayerController.network(_adVideoUrls[adIndex]);
    
    // Initialize with timeout
    try {
      await _adVideoController!.initialize().timeout(Duration(seconds: 10));
    } catch (timeoutError) {
      print("Ad initialization timed out");
      throw Exception("Failed to initialize ad video");
    }
    
    // Get ad duration
    final int adDurationSeconds = _adVideoController!.value.duration.inSeconds;
    print("Ad duration: $adDurationSeconds seconds");
    
    // Close the loading dialog
    if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
      Navigator.of(dialogContext!).pop();
    }
    
    // Show the ad
    final ValueNotifier<String> remainingTimeNotifier = ValueNotifier<String>("00:00");
    
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      transitionDuration: Duration.zero,
      pageBuilder: (newContext, animation1, animation2) {
        dialogContext = newContext;
        return WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                // Video player
                Positioned.fill(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _adVideoController!.value.aspectRatio,
                      child: VideoPlayer(_adVideoController!),
                    ),
                  ),
                ),
                
                // Timer
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Ad: ",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ValueListenableBuilder<String>(
                          valueListenable: remainingTimeNotifier,
                          builder: (context, value, child) {
                            return Text(
                              value,
                              style: TextStyle(color: Colors.white),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    
    // Play the ad
    await _adVideoController!.play();
    
    // Use the actual ad duration for countdown
    for (int i = adDurationSeconds; i >= 0; i--) {
      if (!_isAdPlaying) break;
      
      // Format remaining time as MM:SS
      int minutes = i ~/ 60;
      int seconds = i % 60;
      remainingTimeNotifier.value = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      
      await Future.delayed(Duration(seconds: 1));
    }
    
    // Wait a bit to ensure ad completes
    await Future.delayed(Duration(seconds: 1));
    
    // Close the ad dialog
    if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
      Navigator.of(dialogContext!).pop();
    }
    
    _cleanupAdController();
    _resumeAfterAd();
    
  } catch (e) {
    print("Error in ad playback: $e");
    
    // Close the loading dialog if it's still open
    if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
      Navigator.of(dialogContext!).pop();
    }
    
    _cleanupAdController();
    _resumeAfterAd();
  }
}

  // Future<void> _showVideoAd(int adIndex) async {
  //   // Pause the main video
  //   _videoPlayerController.pause();
  //   setState(() {
  //     _isAdPlaying = true;
  //     _isLoadingAd = true; // Show loader while ad is loading
  //   });

  //   // Show loading dialog immediately
  //   showGeneralDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     barrierColor: Colors.black,
  //     transitionDuration: Duration.zero,
  //     pageBuilder: (context, animation1, animation2) {
  //       // ignore: deprecated_member_use
  //       return WillPopScope(
  //         // Intercept back button press
  //         onWillPop: () async {
  //           // Return false to prevent dialog from closing on back button
  //           return false;
  //         },
  //         child: Scaffold(
  //           body: Container(
  //             width: MediaQuery.of(context).size.width,
  //             height: MediaQuery.of(context).size.height,
  //             color: Colors.black,
  //             child: const Center(
  //               child: CircularProgressIndicator(),
  //             ),
  //           ),
  //         ),
  //       );
  //     },
  //   );

  //   // Initialize ad video controller
  //   // ignore: deprecated_member_use
  //   _adVideoController = VideoPlayerController.network(
  //     _adVideoUrls[adIndex],
  //     // formatHint: VideoFormat.hls,
  //   );

  //   try {
  //     // Initialize and prepare the ad video
  //     await _adVideoController!.initialize();

  //     // Close the loading dialog
  //     Navigator.of(context).pop();

  //     // Calculate total ad duration and format it
  //     int totalSeconds = _adVideoController!.value.duration.inSeconds;
  //     _formatAdRemainingTime(totalSeconds);

  //     // Reset loading state
  //     setState(() {
  //       _isLoadingAd = false;
  //     });

  //     // Create a separate state controller for the dialog
  //     final ValueNotifier<String> remainingTimeNotifier =
  //         ValueNotifier<String>(_adRemainingTime);

  //     // Show the actual ad video with countdown timer
  //     showGeneralDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       barrierColor: Colors.black,
  //       transitionDuration: Duration.zero,
  //       pageBuilder: (context, animation1, animation2) {
  //         // ignore: deprecated_member_use
  //         return WillPopScope(
  //           // Intercept back button press
  //           onWillPop: () async {
  //             // Return false to prevent dialog from closing on back button
  //             return false;
  //           },
  //           child: Scaffold(
  //             body: SafeArea(
  //               child: Stack(
  //                 children: [
  //                   // Ad video
  //                   Container(
  //                     width: MediaQuery.of(context).size.width,
  //                     height: MediaQuery.of(context).size.height,
  //                     color: Colors.black,
  //                     child: Center(
  //                       child: AspectRatio(
  //                         aspectRatio: _adVideoController!.value.aspectRatio,
  //                         child: VideoPlayer(_adVideoController!),
  //                       ),
  //                     ),
  //                   ),

  //                   // Ad countdown timer in top-right corner
  //                   Positioned(
  //                     top: 20,
  //                     right: 20,
  //                     child: Container(
  //                       padding: const EdgeInsets.symmetric(
  //                           horizontal: 12, vertical: 6),
  //                       decoration: BoxDecoration(
  //                         color: Colors.black.withOpacity(0.7),
  //                         borderRadius: BorderRadius.circular(4),
  //                       ),
  //                       child: Row(
  //                         children: [
  //                           const Text(
  //                             "Ad: ",
  //                             style: TextStyle(
  //                               color: Colors.white,
  //                               fontSize: 14,
  //                             ),
  //                           ),
  //                           ValueListenableBuilder<String>(
  //                             valueListenable: remainingTimeNotifier,
  //                             builder: (context, value, child) {
  //                               return Text(
  //                                 value,
  //                                 style: const TextStyle(
  //                                   color: Colors.white,
  //                                   fontSize: 14,
  //                                 ),
  //                               );
  //                             },
  //                           ),
  //                         ],
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         );
  //       },
  //     );

  //     // Start playing after showing the dialog
  //     _adVideoController!.play();

  //     // Start the countdown timer
  //     int remainingSeconds = totalSeconds;
  //     _adCountdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
  //       if (remainingSeconds > 0) {
  //         remainingSeconds--;
  //         _formatAdRemainingTime(remainingSeconds);
  //         remainingTimeNotifier.value = _adRemainingTime;
  //       } else {
  //         timer.cancel();
  //       }
  //     });

  //     // Listen for when the ad finishes playing
  //     _adVideoController!.addListener(() {
  //       if (_adVideoController!.value.position >=
  //           _adVideoController!.value.duration) {
  //         // Video finished playing naturally
  //         if (_isAdPlaying) {
  //           Navigator.of(context).pop();
  //           _cleanupAdController();
  //           _resumeAfterAd();
  //         }
  //       }
  //     });

  //     // Fallback timer in case the video doesn't finish correctly
  //     Timer(const Duration(seconds: 30), () {
  //       if (_isAdPlaying) {
  //         Navigator.of(context).pop();
  //         _cleanupAdController();
  //         _resumeAfterAd();
  //       }
  //     });
  //   } catch (e) {
  //     // Handle initialization errors
  //     print('Error initializing ad video: $e');
  //     // Close the loading dialog if it's still showing
  //     if (_isLoadingAd) {
  //       Navigator.of(context).pop();
  //     }
  //     _cleanupAdController();
  //     _resumeAfterAd();
  //   }
  // }

// Format seconds into MM:SS format
  void _formatAdRemainingTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    _adRemainingTime =
        '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _cleanupAdController() {
    // Cancel the countdown timer
    _adCountdownTimer?.cancel();
    _adCountdownTimer = null;

    if (_adVideoController != null) {
      _adVideoController!.removeListener(() {});
      _adVideoController!.pause();
      _adVideoController!.dispose();
      _adVideoController = null;
    }

    setState(() {
      _isAdPlaying = false;
      _isLoadingAd = false;
      _adRemainingTime = "00:00";
    });
  }

  void _resumeAfterAd() {
    setState(() {
      _isAdPlaying = false;
    });
    _videoPlayerController.play();
  }

  Future<void> _initializeVolume() async {
    // Get current system volume
    final volume = await FlutterVolumeController.getVolume() ?? 0.5;
    setState(() {
      _volume = volume;
    });
  }

  Future<void> _initializeBrightness() async {
    // Get current screen brightness
    final brightness = await ScreenBrightness().system;
    setState(() {
      _brightness = brightness;
    });
  }

  Future<void> _initializePlayer() async {
    var key = "APKAZ3MGNFNZBDODWL67";
    var policy =
        "eyJTdGF0ZW1lbnQiOiBbeyJSZXNvdXJjZSI6Imh0dHBzOi8vbnBsZmxpeC1jb250ZW50LXNlY3VyZS5iaXphbHBoYS5jYS9kODAzN2YzOC1hMWUzLTQ5NWMtOTVjMS05ZjgxNWNhZTcyYmIvdmlkZW9zL2Z1bGwvNzIwKiIsIkNvbmRpdGlvbiI6eyJEYXRlTGVzc1RoYW4iOnsiQVdTOkVwb2NoVGltZSI6MTc3MTA4MTYzMH0sIkRhdGVHcmVhdGVyVGhhbiI6eyJBV1M6RXBvY2hUaW1lIjoxNzM5NDU5MjMwfX19XX0_";
    var signature =
        '1TSM7vFhA40mB8v6U8N447Glk4wDZcuhOiAxXE2Bw5ucRGuC3GZ0a-RUNIGyXKctK8hgOQ3PyCA-z~DAnYHOcJwSjwNtaa8kiF9lWU6-mYFDpx27dKKMSGWsvc5gzMeUeKVqp1RXUNM9wCwp8VGyepQnjPKKQse2f1gRHCm9zAsyHUY5IoAU4iHSYGAUrrbrseYslnOsljPS36Gg9ifsJPe6PG~3-VDyry-SwU--4ZYvnFgRxvEabJP8Hf650mcbJXM9SQoNXvu58UrQI7QxyD3GFd1ZVfvgIJdisGqyjcf-U7PQFcZXY315z1VEIgC82hCXUYpnVvXMFC-7eXCs2A__';
    final String cookies =
        'CloudFront-Key-Pair-Id=$key; CloudFront-Policy=$policy; CloudFront-Signature=$signature';

    // Replace with your video URL or asset
    _videoPlayerController = VideoPlayerController.networkUrl(
      formatHint: VideoFormat.hls,
      httpHeaders: {'Cookie': cookies},
      Uri.parse(
        'https://nplflix-content-secure.bizalpha.ca/d8037f38-a1e3-495c-95c1-9f815cae72bb/videos/full/720.m3u8',
      ),
    );

    await _videoPlayerController.initialize();

    // Add listener for subtitle sync
    _videoPlayerController.addListener(_subtitleSync);

    // Add this position listener to update the UI when video position changes
    _videoPlayerController.addListener(_updatePosition);

    // Add listener for seek operations
    _videoPlayerController.addListener(_detectSeek);

    _createChewieController();

    setState(() {});
  }

  // Previous position to detect seeking
  Duration _previousPosition = Duration.zero;

// Detect when the user is seeking
  void _detectSeek() {
    if (!_videoPlayerController.value.isInitialized) return;

    // Calculate the difference between current and previous position
    final currentPosition = _videoPlayerController.value.position;
    final difference =
        (currentPosition - _previousPosition).inMilliseconds.abs();

    // If the position changed by more than 1 second and not by normal playback,
    // consider it a seek operation
    if (difference > 1000 && !_videoPlayerController.value.isBuffering) {
      // Mark that we're seeking and track the time
      _isSeeking = true;
      _lastSeekTime = DateTime.now();

      // Reset seeking flag after a short delay
      Future.delayed(Duration(milliseconds: 500), () {
        _isSeeking = false;
      });
    }

    // Update previous position
    _previousPosition = currentPosition;
  }

  void _updatePosition() {
    // Only update UI if the position actually changed to avoid unnecessary rebuilds
    if (mounted && _videoPlayerController.value.isPlaying) {
      setState(() {
        // Just triggering a rebuild so the time display updates
      });
    }
  }

  // Called in initState or whenever receiving the captions
  void setupCaptions() {
    // Normally you would get this from your API
    final captionsJson = [
      {
        "isTrailler": false,
        "languageId": 1,
        "captionFileName": "English",
        "captionFilePath":
            "https://nplflix-content-secure.bizalpha.ca/d8037f38-a1e3-495c-95c1-9f815cae72bb/videos/full/captions/en.vtt?Expires=1774366843&Signature=jVLAthgl~BCXImSi3kQblSqiBDhdjzlxrxqwmllr-~lJuKa6kiVezLER7ivEA~gVLAPwJj5fdwAG9E0hD8sKKHSkzSOHNLY0TgNLldL011Q3A6UcdHvc4jrRj98uGA6ogLjLye0d-NQLGOe8fN6qZ3StfvwQRXPE~N6eHtYCfovAOmxTq8Jcrq4t888OfD-LEhlFPYLUecRtMQthvnjwR2U6u5a1TZ7A4AL24~i2t1b2ETXy9GONvbI~Fu6evY-z-wea98A68BbU5j9YnCXYC84pjrr~CIB9wxf9FMJwV3lEFuGzYLTc50wsmeIPjyfPZREymtBrxT92lOnnnV-CKQ__&Key-Pair-Id=APKAZ3MGNFNZBDODWL67",
        "captionUuid": "83d12f69-7192-4021-8c18-312eaaaa8013"
      },
      {
        "isTrailler": false,
        "languageId": 2,
        "captionFileName": "Nepali",
        "captionFilePath":
            "https://nplflix-content-secure.bizalpha.ca/d8037f38-a1e3-495c-95c1-9f815cae72bb/videos/full/captions/np.vtt?Expires=1774366843&Signature=WrT3fHZOiN05Q5-NHu5bh8dz~VXWk-yxLLYYHWFbm-uMeNWPirwAMHrDY2skx-lGuXCY-yfyKMHxepxif6a5zbjnoApxUI86mR14PLnFeYn4emi1fYCYSjbJEFp27gAO9uOGrsK3sGBSc3X~wj8-Zpq7gEBBV49ZLlq89jGumOI5VCu90AvrTUsZzh3EGHLieHgqB86PGDwHtpbJeLr7Z-VxPgjxXyBfrkeBN0iKlBrQG76zf5gZTLexcH2dQsd70UXa2H7iC852oOULYIdQJav9GgyJyDEoYo4A53dQb0lNgkm90G-smgcWC-8dfZQcG8MEqakRMjTVnnkyZ8NDzg__&Key-Pair-Id=APKAZ3MGNFNZBDODWL67",
        "captionUuid": "7ffbf156-856c-446d-971e-52c10766a9d4"
      }
    ];

    _captions = captionsJson.map((json) => Caption.fromJson(json)).toList();

    // Default to first caption (usually English)
    if (_captions.isNotEmpty) {
      _selectedCaption = _captions.first;
      _loadSubtitleFile(_selectedCaption!.captionFilePath);
    }
  }

  // Load VTT file content
  Future<void> _loadSubtitleFile(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        _parseVttSubtitles(response.body);
      } else {
        debugPrint('Failed to load subtitles: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading subtitles: $e');
    }
  }

// Parse VTT format
  void _parseVttSubtitles(String vttContent) {
    final List<Subtitle> subtitles = [];
    final lines = vttContent.split('\n');
    int i = 0;

    // Skip WebVTT header
    while (i < lines.length && !lines[i].contains('-->')) {
      i++;
    }

    // Parse cues
    while (i < lines.length) {
      if (lines[i].contains('-->')) {
        final timeLine = lines[i].trim();
        final timeComponents = timeLine.split(' --> ');

        if (timeComponents.length == 2) {
          final startTime = _parseVttTime(timeComponents[0]);
          final endTime = _parseVttTime(timeComponents[1]);

          i++;
          String text = '';
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            if (text.isNotEmpty) text += '\n';
            text += lines[i].trim();
            i++;
          }

          if (text.isNotEmpty) {
            subtitles.add(Subtitle(
              start: startTime,
              end: endTime,
              text: text,
            ));
          }
        }
      }
      i++;
    }

    setState(() {
      _subtitles = subtitles;
    });
  }

// Parse VTT time format (00:00:00.000)
  Duration _parseVttTime(String timeString) {
    final cleaned = timeString.trim();
    final parts = cleaned.split(':');

    int hours = 0;
    int minutes = 0;
    double seconds = 0;

    if (parts.length == 3) {
      hours = int.parse(parts[0]);
      minutes = int.parse(parts[1]);
      seconds = double.parse(parts[2]);
    } else if (parts.length == 2) {
      minutes = int.parse(parts[0]);
      seconds = double.parse(parts[1]);
    }

    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds.floor(),
      milliseconds: ((seconds - seconds.floor()) * 1000).round(),
    );
  }

// Sync subtitles with video - add this to video player listener
  void _subtitleSync() {
    if (!_subtitlesEnabled || _subtitles.isEmpty) {
      _currentSubtitle = null;
      return;
    }

    final position = _videoPlayerController.value.position;

    Subtitle? subtitle;
    for (var sub in _subtitles) {
      if (position >= sub.start && position <= sub.end) {
        subtitle = sub;
        break;
      }
    }

    if (subtitle != _currentSubtitle) {
      setState(() {
        _currentSubtitle = subtitle;
      });
    }
  }

// Add this method to switch between subtitle languages
  void switchSubtitleLanguage(Caption newCaption) {
    setState(() {
      _selectedCaption = newCaption;
      _subtitles = []; // Clear current subtitles
      _currentSubtitle = null; // Reset current subtitle
    });

    // Load the new subtitle file
    _loadSubtitleFile(newCaption.captionFilePath);
  }

  void _showSubtitleMenu(BuildContext context) {
    // Add "None" option at the beginning of the list
    final List<PopupMenuEntry<String>> menuItems = [
      const PopupMenuItem<String>(
        value: 'none',
        child: Text('None'),
      ),
      const PopupMenuDivider(),
    ];

    // Add all caption languages
    for (var caption in _captions) {
      menuItems.add(
        PopupMenuItem<String>(
          value: caption.captionFilePath,
          child: Text(caption.captionFileName),
        ),
      );
    }

    // Show the popup menu
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(
          100, 80, 0, 100), // Adjust position as needed
      items: menuItems,
    ).then((value) {
      if (value == null) return;

      if (value == 'none') {
        // Disable subtitles
        setState(() {
          _subtitlesEnabled = false;
          _currentSubtitle = null;
        });
      } else {
        // Find the selected caption
        for (var caption in _captions) {
          if (caption.captionFilePath == value) {
            setState(() {
              _subtitlesEnabled = true;
              _selectedCaption = caption;
              _subtitles = [];
              _currentSubtitle = null;
            });

            // Load the new subtitle file
            _loadSubtitleFile(caption.captionFilePath);
            break;
          }
        }
      }
    });
  }

  void _createChewieController() {
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      showOptions: false, // Disable default options dialog
      customControls: const MaterialControls(), // Use modified controls
      // Hide default controls so we can show our own
      showControlsOnInitialize: false,
    );

    _resetSliderAndButtonsVisiblity();
  }

  void _resetSliderAndButtonsVisiblity() {
    //video progress slider and play pause buttons also the brightness and volume ICONS
    setState(() {
      _isMaterialControlles = true;
    });
    _materialControllesTimer?.cancel();
    _materialControllesTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _isMaterialControlles = false;
      });
    });
  }

  Future<void> changeVolume(double value) async {
    await FlutterVolumeController.setVolume(value);
    setState(() {
      _volume = value;
    });
  }

  Future<void> changeBrightness(double value) async {
    await ScreenBrightness().setApplicationScreenBrightness(value);
    setState(() {
      _brightness = value;
    });
  }

  void toggleScreenLock() {
    setState(() {
      _isScreenLocked = !_isScreenLocked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _videoPlayerController.value.isInitialized
          ? Stack(
              children: [
                // Custom video container with zoom that affects only the video
                Center(
                  child: _buildZoomableVideoOnly(),
                ),

                // Screen locked indicator
                if (_isScreenLocked)
                  Positioned(
                    top: 20,
                    right: 20,
                    child: GestureDetector(
                      onTap: toggleScreenLock,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.lock,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                //(hide when locked)
                if (!_isScreenLocked && _chewieController != null)
                  _buildScreenSubtitlesAndScreenLockOverlay(),

                //(hide when locked)
                if (!_isScreenLocked && _chewieController != null)
                  _buildScreenBrightnessAndVolumeOverlay(),
                //(hide when locked)
                if (!_isScreenLocked && _chewieController != null)
                  _buildScreenVideoProgressOverlay(),

                // Subtitles overlay
                if (_subtitlesEnabled) _buildSubtitlesOverlay(),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  void _skipForward() {
    final newPosition =
        _videoPlayerController.value.position + const Duration(seconds: 10);
    // Make sure we don't go past the end of the video
    if (newPosition < _videoPlayerController.value.duration) {
      _videoPlayerController.seekTo(newPosition);
    } else {
      _videoPlayerController.seekTo(_videoPlayerController.value.duration);
    }
  }

  void _skipBackward() {
    final newPosition =
        _videoPlayerController.value.position - const Duration(seconds: 10);
    // Make sure we don't go before the start of the video
    if (newPosition > Duration.zero) {
      _videoPlayerController.seekTo(newPosition);
    } else {
      _videoPlayerController.seekTo(Duration.zero);
    }
  }

  Widget _buildPlaybackControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Backward 10s button
        IconButton(
          icon: const Icon(
            Icons.replay_10,
            color: Colors.white,
            size: 36,
          ),
          onPressed: _skipBackward,
        ),

        const SizedBox(width: 16),

        // Play/Pause button
        IconButton(
          icon: Icon(
            _videoPlayerController.value.isPlaying
                ? Icons.pause
                : Icons.play_arrow,
            color: Colors.white,
            size: 48,
          ),
          onPressed: () {
            setState(() {
              _videoPlayerController.value.isPlaying
                  ? _videoPlayerController.pause()
                  : _videoPlayerController.play();
            });
          },
        ),

        const SizedBox(width: 16),

        // Forward 10s button
        IconButton(
          icon: const Icon(
            Icons.forward_10,
            color: Colors.white,
            size: 36,
          ),
          onPressed: _skipForward,
        ),
      ],
    );
  }

  Widget _buildZoomableVideoOnly() {
    // Get the original aspect ratio
    final aspectRatio = _videoPlayerController.value.aspectRatio;

    return GestureDetector(
      // Only detect scale gestures (pinch to zoom)
      onScaleStart: !_isScreenLocked
          ? (ScaleStartDetails details) {
              // Store initial scale when gesture starts
              _initialScale = _scale;
            }
          : null,
      onScaleUpdate: !_isScreenLocked
          ? (ScaleUpdateDetails details) {
              setState(() {
                // Update scale based on gesture, starting from initial scale
                _scale = (_initialScale * details.scale).clamp(1.0, 3.0);
              });
            }
          : null,
      // Detect tap to show/hide controls, but don't affect zoom
      onTap: () {
        if (!_isScreenLocked) {
          _resetSliderAndButtonsVisiblity();
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Black background container to maintain proper sizing
          AspectRatio(
            aspectRatio: aspectRatio,
            child: Container(color: Colors.black),
          ),

          // Zoomable video layer
          ClipRect(
            child: Transform.scale(
              scale: _scale,
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.width / aspectRatio,
                child: VideoPlayer(_videoPlayerController),
              ),
            ),
          ),

          // Non-zoomable Chewie controls layer (invisible)
          Positioned.fill(
            child: IgnorePointer(
              // This ignores pointer events so they go to the gesture detector
              ignoring: true,
              child: Opacity(
                opacity: 0.0, // Make this invisible
                child: Chewie(controller: _chewieController!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitlesOverlay() {
    // Don't display anything if subtitles are disabled or no current subtitle
    if (!_subtitlesEnabled || _currentSubtitle == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _currentSubtitle!.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildScreenBrightnessAndVolumeOverlay() {
    return Visibility(
      visible: _isMaterialControlles,
      child: Positioned(
        top: 80,
        left: 0,
        right: 0,
        child: Column(
          // mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const Icon(Icons.brightness_6,
                        color: Colors.white, size: 25),
                    RotatedBox(
                      quarterTurns: 3,
                      child: SliderTheme(
                        data: const SliderThemeData(
                          thumbColor: Colors.white,
                          activeTrackColor: Colors.white70,
                          inactiveTrackColor: Colors.white30,
                          trackHeight: 2.0,
                          thumbShape:
                              RoundSliderThumbShape(enabledThumbRadius: 6.0),
                        ),
                        child: Slider(
                          value: _brightness,
                          onChanged: changeBrightness,
                        ),
                      ),
                    ),
                  ],
                ),

                // Volume control
                Column(
                  children: [
                    Icon(
                      _volume == 0
                          ? Icons.volume_off
                          : _volume < 0.5
                              ? Icons.volume_down
                              : Icons.volume_up,
                      color: Colors.white,
                      size: 25,
                    ),
                    // const SizedBox(width: 8),
                    RotatedBox(
                      quarterTurns: 3,
                      child: SliderTheme(
                        data: const SliderThemeData(
                          thumbColor: Colors.white,
                          activeTrackColor: Colors.white70,
                          inactiveTrackColor: Colors.white30,
                          trackHeight: 2.0,
                          thumbShape:
                              RoundSliderThumbShape(enabledThumbRadius: 6.0),
                        ),
                        child: Slider(
                          value: _volume,
                          onChanged: changeVolume,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenVideoProgressOverlay() {
    return Visibility(
      visible: _isMaterialControlles,
      child: Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black54],
            ),
          ),
          child: Column(
            // mainAxisSize: MainAxisSize.min,
            children: [
              // Progress indicator
              VideoProgressIndicator(
                _videoPlayerController,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.red,
                  bufferedColor: Colors.white54,
                  backgroundColor: Colors.white24,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),

              // Play/Pause button + time
              Row(
                children: [
                  // Current position / Total duration
                  Text(
                    '${_formatDuration(_videoPlayerController.value.position)} / ${_formatDuration(_videoPlayerController.value.duration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.25,
                  ),
                  _buildPlaybackControls(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreenSubtitlesAndScreenLockOverlay() {
    return Visibility(
      visible: _isMaterialControlles,
      child: Positioned(
        top: 20,
        left: 0,
        right: 10,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () async {
                await SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp, // Force portrait before exiting
                  DeviceOrientation.portraitDown,
                ]);
                Navigator.pop(context); // Close the screen
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    _subtitlesEnabled ? Icons.subtitles : Icons.subtitles_off,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () {
                    _showSubtitleMenu(context);
                  },
                ),
                // Lock screen
                IconButton(
                  icon: const Icon(Icons.lock_outline, color: Colors.white),
                  onPressed: toggleScreenLock,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to format duration as mm:ss
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _videoPlayerController.removeListener(_subtitleSync);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    _volumeSliderTimer?.cancel();
    _brightnessSliderTimer?.cancel();

    _videoPlayerController.removeListener(_subtitleSync);
    _videoPlayerController.removeListener(_detectSeek); // Remove seek listener

    // Clean up ad controller if it exists
    _cleanupAdController();
    WakelockPlus.disable();
    super.dispose();
  }
}

// Simple caption model
class Caption {
  final String captionFileName;
  final String captionFilePath;

  Caption({
    required this.captionFileName,
    required this.captionFilePath,
  });

  factory Caption.fromJson(Map<String, dynamic> json) {
    return Caption(
      captionFileName: json['captionFileName'] ?? '',
      captionFilePath: json['captionFilePath'] ?? '',
    );
  }
}

// Subtitle model for parsed VTT subtitles
class Subtitle {
  final Duration start;
  final Duration end;
  final String text;

  Subtitle({
    required this.start,
    required this.end,
    required this.text,
  });
}
