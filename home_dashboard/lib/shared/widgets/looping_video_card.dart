import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/services/animation_service.dart';

class LoopingVideoCard extends StatefulWidget {
  final String videoAssetPath;

  const LoopingVideoCard({super.key, required this.videoAssetPath});

  @override
  State<LoopingVideoCard> createState() => _LoopingVideoCardState();
}

class _LoopingVideoCardState extends State<LoopingVideoCard> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  late final VoidCallback _globalListener;
  bool _locallyPaused = false; // local override via the overlay button

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.videoAssetPath)
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          // Respect global pause on init
          if (AnimationService.paused.value || _locallyPaused) {
            _controller.pause();
          } else {
            _controller.play();
          }
        }
      }).catchError((error) {
        print('Error loading video: $error');
      });

    // Preload by seeking to start and mute
    _controller.setVolume(0);

    // Listen to global pause/play
    _globalListener = () {
      if (!mounted || !_isInitialized) return;
      if (AnimationService.paused.value || _locallyPaused) {
        _controller.pause();
      } else {
        _controller.play();
      }
      setState(() {});
    };
    AnimationService.paused.addListener(_globalListener);
  }

  @override
  void dispose() {
    AnimationService.paused.removeListener(_globalListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final overlay = colorScheme.onSurface.withOpacity(0.12);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9, // Standard video aspect ratio
        child: _isInitialized
            ? Stack(
                fit: StackFit.expand,
                children: [
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                  // Per-video pause/play control (lower-right)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Material(
                      type: MaterialType.transparency,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        hoverColor: overlay,
                        splashColor: overlay,
                        onTap: () {
                          setState(() {
                            _locallyPaused = !_locallyPaused;
                          });
                          if (_locallyPaused || AnimationService.paused.value) {
                            _controller.pause();
                          } else if (_isInitialized) {
                            _controller.play();
                          }
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.8),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              (_locallyPaused || AnimationService.paused.value)
                                  ? Icons.play_arrow
                                  : Icons.pause,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
