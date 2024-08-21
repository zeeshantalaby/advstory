import 'package:advstory/src/util/animated_border_painter.dart';
import 'package:advstory/src/view/components/shimmer.dart';
import 'package:advstory/advstory.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AdvStoryTray extends AnimatedTray {
  /// Creates a story tray to show in story tray list.
  ///
  /// [borderRadius] sets tray and image border shape.
  AdvStoryTray({
    super.key,
    required this.url,
    required this.index,
    this.customWidget,
    this.username,
    required this.video,
    this.size = const Size(80, 80),
    this.shimmerStyle = const ShimmerStyle(),
    this.shape = BoxShape.circle,
    this.borderGradientColors = const [
      Color(0xaf405de6),
      Color(0xaf5851db),
      Color(0xaf833ab4),
      Color(0xafc13584),
      Color(0xafe1306c),
      Color(0xaffd1d1d),
      Color(0xaf405de6),
    ],
    this.gapSize = 3,
    this.strokeWidth = 2,
    this.animationDuration = const Duration(milliseconds: 1200),
    double? borderRadius,
  })  : assert(
  (() => shape == BoxShape.circle ? size.width == size.height : true)(),
  'Size width and height must be equal for a circular tray',
  ),
        assert(
        borderGradientColors.length >= 2,
        'At least 2 colors are required for tray border gradient',
        ),
        borderRadius = shape == BoxShape.circle
            ? size.width
            : borderRadius ?? size.width / 10;

  /// Image url that shown as tray.
  final String url;
  final int index;

  /// Name of the user who posted the story. This username is displayed
  /// below the story tray.
  final Widget? username;
  final Widget? customWidget;

  /// Size of the story tray. For a circular tray, width and height must be
  /// equal.
  final Size size;
  final bool video;

  /// Border gradient colors. Two same color creates a solid border.
  final List<Color> borderGradientColors;

  /// Style of the shimmer that showing while preparing the tray content.
  final ShimmerStyle shimmerStyle;

  /// Shap of the tray.
  final BoxShape shape;

  /// Width of the stroke that wraps the tray image.
  final double strokeWidth;

  /// Radius of the border that wraps the tray image.
  final double borderRadius;

  /// Transparent area size between image and the border.
  final double gapSize;

  /// Rotate animation duration of the border.
  final Duration animationDuration;

  @override
  AnimatedTrayState<AdvStoryTray> createState() => _AdvStoryTrayState();
}

/// State of the [AdvStoryTray] widget.
class _AdvStoryTrayState extends AnimatedTrayState<AdvStoryTray>
    with TickerProviderStateMixin {
  late VideoPlayerController _controller;
  late final _rotationController = AnimationController(
    vsync: this,
    duration: widget.animationDuration,
  );
  late List<Color> _gradientColors = widget.borderGradientColors;
  List<Color> _fadedColors = [];

  List<Color> _calculateFadedColors(List<Color> baseColors) {
    final colors = <Color>[];
    for (int i = 0; i < baseColors.length; i++) {
      final opacity = i == 0 ? 1 / baseColors.length : 1 / i;

      colors.add(
        baseColors[i].withOpacity(opacity),
      );
    }

    return colors;
  }

  @override
  void startAnimation() {
    setState(() {
      _gradientColors = _fadedColors;
    });

    _rotationController.repeat();
  }

  @override
  void stopAnimation() {
    _rotationController.reset();

    setState(() {
      _gradientColors = widget.borderGradientColors;
    });
  }

  @override
  void initState() {
    _fadedColors = _calculateFadedColors(widget.borderGradientColors);
    if (widget.video) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (widget.index == 0) {
            _controller.setVolume(0.0);
            _controller.play();
          }
          setState(() {});
        });
    }
    super.initState();
  }

  @override
  void didUpdateWidget(AdvStoryTray oldWidget) {
    if (oldWidget.borderGradientColors != widget.borderGradientColors) {
      _gradientColors = widget.borderGradientColors;
      _fadedColors = _calculateFadedColors(widget.borderGradientColors);
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: widget.size.width,
          height: widget.size.height,
          child: Stack(
            children: [
              CustomPaint(
                painter: AnimatedBorderPainter(
                  gradientColors: _gradientColors,
                  gapSize: widget.gapSize,
                  radius: widget.shape == BoxShape.circle
                      ? widget.size.width
                      : widget.borderRadius,
                  strokeWidth: widget.strokeWidth,
                  animation: CurvedAnimation(
                    parent: Tween(begin: 0.0, end: 1.0).animate(
                      _rotationController,
                    ),
                    curve: Curves.slowMiddle,
                  ),
                ),
                child: SizedBox(
                  width: widget.size.width,
                  height: widget.size.height,
                ),
              ),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    widget.borderRadius - (widget.strokeWidth + widget.gapSize),
                  ),
                  child: widget.video
                      ? SizedBox(
                      child: _controller.value.isInitialized
                          ? FittedBox(
                        fit: BoxFit.contain,
                        child: GestureDetector(
                          onTap: () {
                            if (widget.index == 0) {
                              _controller.pause();
                            }
                          },
                          child: SizedBox(
                              width: widget.size.width,
                              height: widget.size.height,
                              // color: Colors.red,
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: ClipRRect(
                                    borderRadius:
                                    BorderRadius.circular(
                                      widget.borderRadius - 5,
                                    ),
                                    child: VideoPlayer(_controller)),
                              )),
                        ),
                      )
                          : Shimmer(style: widget.shimmerStyle))
                      : Image.network(
                    widget.url,
                    width: widget.size.width -
                        (widget.gapSize + widget.strokeWidth) * 2,
                    height: widget.size.height -
                        (widget.gapSize + widget.strokeWidth) * 2,
                    fit: BoxFit.cover,
                    frameBuilder: (context, child, frame, _) {
                      return frame != null
                          ? TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: .1, end: 1),
                        curve: Curves.ease,
                        duration: const Duration(milliseconds: 300),
                        builder: (BuildContext context,
                            double opacity, _) {
                          return Opacity(
                            opacity: opacity,
                            child: child,
                          );
                        },
                      )
                          : Shimmer(style: widget.shimmerStyle);
                    },
                    errorBuilder: (_, __, ___) {
                      return const Icon(Icons.error);
                    },
                  ),
                ),
              ),
              if (widget.customWidget != null) widget.customWidget!,
            ],
          ),
        ),
        if (widget.username != null) ...[
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.bottomCenter,
            child: widget.username,
          ),
        ],
      ],
    );
  }
}
