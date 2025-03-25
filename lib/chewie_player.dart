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
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

// Subtitle data model
class Subtitle {
  final Duration start;
  final Duration end;
  final String text;

  Subtitle({required this.start, required this.end, required this.text});
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _subtitlesEnabled = true;
  bool _isScreenLocked = false;
  bool _isSliderAndButtonsVisible = false;
  Timer? _sliderAndButtonsVisible;
  double _brightness = 0.5;
  double _volume = 0.5;
  double _scale = 1.0;
  double _initialScale = 1.0;
  // Add these variables to your _VideoPlayerScreenState class
  bool _showVolumeSlider = false;
  bool _showBrightnessSlider = false;
  Timer? _volumeSliderTimer;
  Timer? _brightnessSliderTimer;

  // Subtitle-related variables
  List<Subtitle> _subtitles = [];
  Subtitle? _currentSubtitle;
  Timer? _subtitleTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _initializeVolume();
    _initializeBrightness();
    _loadSubtitles(); // Load subtitles

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky); // Hide system UI
    // Keep screen on during video playback
    WakelockPlus.enable();
  }

  // Add these methods to your _VideoPlayerScreenState class
  void _showVolumeControl() {
    setState(() {
      _showVolumeSlider = true;
      _resetVolumeSliderTimer();
    });
  }

  void _showBrightnessControl() {
    setState(() {
      _showBrightnessSlider = true;
      _resetBrightnessSliderTimer();
    });
  }

  void _resetBrightnessSliderTimer() {
    _brightnessSliderTimer?.cancel();
    _brightnessSliderTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _showBrightnessSlider = false;
      });
    });
  }

  void _resetVolumeSliderTimer() {
    _volumeSliderTimer?.cancel();
    _volumeSliderTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _showVolumeSlider = false;
      });
    });
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

    _createChewieController();

    setState(() {});
  }

  void _updatePosition() {
    // Only update UI if the position actually changed to avoid unnecessary rebuilds
    if (mounted && _videoPlayerController.value.isPlaying) {
      setState(() {
        // Just triggering a rebuild so the time display updates
      });
    }
  }

  // Load and parse subtitles
  Future<void> _loadSubtitles() async {
    try {
      // Example: Load SRT from network
      // Replace this URL with your subtitle file URL
      final response = await http.get(Uri.parse(
          "https://nplflix-content-secure.bizalpha.ca/d8037f38-a1e3-495c-95c1-9f815cae72bb/videos/full/captions/en.vtt?Expires=1774366843&Signature=jVLAthgl~BCXImSi3kQblSqiBDhdjzlxrxqwmllr-~lJuKa6kiVezLER7ivEA~gVLAPwJj5fdwAG9E0hD8sKKHSkzSOHNLY0TgNLldL011Q3A6UcdHvc4jrRj98uGA6ogLjLye0d-NQLGOe8fN6qZ3StfvwQRXPE~N6eHtYCfovAOmxTq8Jcrq4t888OfD-LEhlFPYLUecRtMQthvnjwR2U6u5a1TZ7A4AL24~i2t1b2ETXy9GONvbI~Fu6evY-z-wea98A68BbU5j9YnCXYC84pjrr~CIB9wxf9FMJwV3lEFuGzYLTc50wsmeIPjyfPZREymtBrxT92lOnnnV-CKQ__&Key-Pair-Id=APKAZ3MGNFNZBDODWL67"));

      if (response.statusCode == 200) {
        final String srtContent = response.body;
        _parseSubtitles(srtContent);
      } else {
        debugPrint('Failed to load subtitles: ${response.statusCode}');
      }

      // Alternative: Load SRT from assets
      // final String srtContent = await rootBundle.loadString('assets/subtitles.srt');
      // _parseSubtitles(srtContent);
    } catch (e) {
      debugPrint('Error loading subtitles: $e');
    }
  }

  // Parse SRT format subtitles
  void _parseSubtitles(String srtContent) {
    final List<Subtitle> subtitles = [];

    // Split by double newline to get each subtitle block
    final blocks = srtContent.split('\r\n\r\n');
    if (blocks.length == 1) {
      // Try with just newline if double newline didn't work
      final newBlocks = srtContent.split('\n\n');
      if (newBlocks.length > blocks.length) {
        blocks.clear();
        blocks.addAll(newBlocks);
      }
    }

    for (var block in blocks) {
      final lines = block.split('\n');
      if (lines.length < 3) continue;

      // Skip the subtitle number (first line)

      // Parse the time line (second line)
      final timeLine = lines[1].trim();
      final timeComponents = timeLine.split(' --> ');
      if (timeComponents.length != 2) continue;

      final startTime = _parseSrtTime(timeComponents[0]);
      final endTime = _parseSrtTime(timeComponents[1]);

      // Join the rest of the lines as the subtitle text
      final subtitleText = lines.sublist(2).join('\n').trim();

      subtitles.add(Subtitle(
        start: startTime,
        end: endTime,
        text: subtitleText,
      ));
    }

    setState(() {
      _subtitles = subtitles;
    });

    debugPrint('Loaded ${subtitles.length} subtitles');
  }

  // Parse SRT time format (00:00:00,000)
  Duration _parseSrtTime(String timeString) {
    final cleaned = timeString.trim().replaceAll(',', '.');
    final parts = cleaned.split(':');

    if (parts.length != 3) {
      return Duration.zero;
    }

    int hours = int.parse(parts[0]);
    int minutes = int.parse(parts[1]);

    final secondsParts = parts[2].split('.');
    int seconds = int.parse(secondsParts[0]);
    int milliseconds = secondsParts.length > 1
        ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3))
        : 0;

    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }

  // Synchronize subtitles with video position
  void _subtitleSync() {
    if (!_subtitlesEnabled || _subtitles.isEmpty) {
      _currentSubtitle = null;
      return;
    }

    final position = _videoPlayerController.value.position;

    // Find the subtitle that should be displayed at the current position
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

  void _createChewieController() {
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      showOptions: false, // Disable default options dialog
      customControls: const MaterialControls(), // Use modified controls

      additionalOptions: (context) => [
        OptionItem(
          onTap: toggleSubtitles,
          iconData: _subtitlesEnabled ? Icons.subtitles : Icons.subtitles_off,
          title: _subtitlesEnabled ? 'Disable Subtitles' : 'Enable Subtitles',
        ),
      ],
      // Hide default controls so we can show our own
      showControlsOnInitialize: false,
    );

    _resetSliderAndButtonsVisiblity();
  }

  void _resetSliderAndButtonsVisiblity() {
    setState(() {
      _isSliderAndButtonsVisible = true;
    });
    _sliderAndButtonsVisible?.cancel();
    _sliderAndButtonsVisible = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _isSliderAndButtonsVisible = false;
      });
    });
  }

  void toggleSubtitles() {
    setState(() {
      _subtitlesEnabled = !_subtitlesEnabled;
      if (!_subtitlesEnabled) {
        _currentSubtitle = null;
      } else {
        // Re-sync to find current subtitle
        _subtitleSync();
      }
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

  // Add these methods to your _VideoPlayerScreenState class
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

// Replace your existing play/pause button row with this
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
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Column(
        // mainAxisSize: MainAxisSize.min,
        children: [
          // Brightness control
          Row(
            // mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  GestureDetector(
                      onTap: () {
                        _showBrightnessControl();
                      },
                      child: const Icon(Icons.brightness_6,
                          color: Colors.white, size: 30)),
                  Opacity(
                    opacity: _showBrightnessSlider ? 1 : 0,
                    child: RotatedBox(
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
                  ),
                ],
              ),

              // Volume control
              Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      _showVolumeControl();
                    },
                    child: Icon(
                      _volume == 0
                          ? Icons.volume_off
                          : _volume < 0.5
                              ? Icons.volume_down
                              : Icons.volume_up,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  // const SizedBox(width: 8),
                  Opacity(
                    opacity: _showVolumeSlider ? 1 : 0,
                    child: RotatedBox(
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
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScreenVideoProgressOverlay() {
    return Visibility(
      visible: _isSliderAndButtonsVisible,
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
    return Positioned(
      top: 20,
      left: 0,
      right: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(
              _subtitlesEnabled ? Icons.subtitles : Icons.subtitles_off,
              color: Colors.white,
              size: 24,
            ),
            onPressed: toggleSubtitles,
          ),
          // Lock screen
          IconButton(
            icon: const Icon(Icons.lock_outline, color: Colors.white),
            onPressed: toggleScreenLock,
          ),
        ],
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
    _subtitleTimer?.cancel();
    _volumeSliderTimer?.cancel();
    _brightnessSliderTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }
}
