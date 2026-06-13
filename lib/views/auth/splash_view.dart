import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'login_view.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Ticker _rippleTicker;

  // Staged animations
  late Animation<double> _gridAnimation;
  late Animation<double> _cornerAnimation;
  late Animation<double> _logoSquareAnimation;
  late Animation<double> _logoCrossAnimation;
  late Animation<double> _logoCornerSquaresAnimation;
  late Animation<double> _logoCenterBoxAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _footerAnimation;

  Offset? _hoverPosition;
  final List<BlueprintRipple> _ripples = [];
  bool _isNavigated = false;

  @override
  void initState() {
    super.initState();

    // Main animation controller (3.5 seconds)
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // Grid lines drawing (0.0 to 0.25)
    _gridAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );

    // Corner brackets fade/slide (0.15 to 0.35)
    _cornerAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.15, 0.35, curve: Curves.easeOut),
    );

    // Central logo square outline drawing (0.30 to 0.55)
    _logoSquareAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.30, 0.55, curve: Curves.easeOut),
    );

    // Central logo square cross lines (0.45 to 0.65)
    _logoCrossAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.45, 0.65, curve: Curves.easeOut),
    );

    // Central logo square corner accent squares (0.60 to 0.75)
    _logoCornerSquaresAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.60, 0.75, curve: Curves.elasticOut),
    );

    // Central logo inner center box (0.65 to 0.80)
    _logoCenterBoxAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.65, 0.80, curve: Curves.easeOut),
    );

    // Typography fade and slide (0.75 to 0.95)
    _textFadeAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.75, 0.95, curve: Curves.easeOut),
    );

    // Footer information fade (0.85 to 1.0)
    _footerAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
    );

    // Start ripple ticker for active ripples
    _rippleTicker = createTicker((elapsed) {
      if (_ripples.isNotEmpty) {
        setState(() {
          _ripples.removeWhere((ripple) {
            ripple.ageMs += 16; // increment frame
            return ripple.ageMs > 800; // max ripple life
          });
        });
      }
    });
    _rippleTicker.start();

    // Start the splash sequence
    _mainController.forward();

    // Setup auto navigation after 5 seconds
    Timer(const Duration(milliseconds: 5000), () {
      _navigateToLogin();
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rippleTicker.dispose();
    super.dispose();
  }

  void _addRipple(Offset position) {
    setState(() {
      _ripples.add(BlueprintRipple(position: position));
    });
  }

  void _navigateToLogin() {
    if (_isNavigated) return;
    _isNavigated = true;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginView(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8), // Soft blueprint off-white background
      body: SafeArea(
        child: Stack(
          children: [
            // Interactive custom painter canvas
            Positioned.fill(
              child: Listener(
                onPointerHover: (event) {
                  setState(() {
                    _hoverPosition = event.localPosition;
                  });
                },
                onPointerDown: (event) {
                  setState(() {
                    _hoverPosition = event.localPosition;
                  });
                  _addRipple(event.localPosition);
                },
                onPointerMove: (event) {
                  setState(() {
                    _hoverPosition = event.localPosition;
                  });
                },
                onPointerCancel: (_) {
                  setState(() {
                    _hoverPosition = null;
                  });
                },
                onPointerUp: (_) {
                  setState(() {
                    _hoverPosition = null;
                  });
                },
                child: MouseRegion(
                  onExit: (_) {
                    setState(() {
                      _hoverPosition = null;
                    });
                  },
                  child: AnimatedBuilder(
                    animation: _mainController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: BlueprintPainter(
                          gridProgress: _gridAnimation.value,
                          cornerProgress: _cornerAnimation.value,
                          logoSquareProgress: _logoSquareAnimation.value,
                          logoCrossProgress: _logoCrossAnimation.value,
                          logoCornerSquaresProgress: _logoCornerSquaresAnimation.value,
                          logoCenterBoxProgress: _logoCenterBoxAnimation.value,
                          hoverPosition: _hoverPosition,
                          ripples: List.from(_ripples),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Typography overlay
            AnimatedBuilder(
              animation: _textFadeAnimation,
              builder: (context, child) {
                final double opacity = _textFadeAnimation.value;
                final double slideOffset = (1.0 - opacity) * 20.0;

                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Space matching the central logo (height 160 + spacer)
                      const SizedBox(height: 190),

                      // Brand title: KURNIA
                      Transform.translate(
                        offset: Offset(0, slideOffset),
                        child: Opacity(
                          opacity: opacity,
                          child: Column(
                            children: [
                              const Text(
                                'KURNIA',
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 10.0,
                                  color: Color(0xFF1E293B), // Premium dark slate
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Technical divider line
                              Container(
                                width: 70,
                                height: 1.5,
                                color: const Color(0xFF94A3B8), // slate-400
                              ),
                              const SizedBox(height: 12),
                              // Tagline
                              const Text(
                                'MAKE YOUR OWN DESIGN',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 4.5,
                                  color: Color(0xFF64748B), // slate-500
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Footer overlay
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _footerAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _footerAnimation.value,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Small technical solid square
                        Container(
                          width: 8,
                          height: 8,
                          color: const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'V.1.0.0_BUILD',
                          style: TextStyle(
                            fontSize: 9,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Skip / Lewati Button
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _textFadeAnimation,
                  builder: (context, child) {
                    final double opacity = _textFadeAnimation.value;
                    return Opacity(
                      opacity: opacity,
                      child: IgnorePointer(
                        ignoring: opacity < 0.5,
                        child: GestureDetector(
                          onTap: _navigateToLogin,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                border: Border.all(
                                  color: const Color(0xFF475569).withOpacity(0.8),
                                  width: 1.2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3F51B5).withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'LEWATI',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.5,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color: Color(0xFF1E293B),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BlueprintRipple {
  final Offset position;
  int ageMs = 0;

  BlueprintRipple({required this.position});

  double get progress => (ageMs / 800).clamp(0.0, 1.0);
  double get radius => progress * 130.0;
  double get opacity => 1.0 - progress;
}

class BlueprintPainter extends CustomPainter {
  final double gridProgress;
  final double cornerProgress;
  final double logoSquareProgress;
  final double logoCrossProgress;
  final double logoCornerSquaresProgress;
  final double logoCenterBoxProgress;
  final Offset? hoverPosition;
  final List<BlueprintRipple> ripples;

  BlueprintPainter({
    required this.gridProgress,
    required this.cornerProgress,
    required this.logoSquareProgress,
    required this.logoCrossProgress,
    required this.logoCornerSquaresProgress,
    required this.logoCenterBoxProgress,
    required this.hoverPosition,
    required this.ripples,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Draw Blueprint Background Grid
    _paintBackgroundGrid(canvas, size, center);

    // 2. Draw Corner L-Brackets
    _paintCornerBrackets(canvas, size);

    // 3. Draw Logo Square (Outer Outline, Cross, Corner Squares, Center Box)
    _paintLogoSquare(canvas, center);

    // 4. Draw CAD Crosshairs & live coordinates
    _paintCrosshairs(canvas, size);

    // 5. Draw Interactive Ripples
    _paintRipples(canvas);
  }

  void _paintBackgroundGrid(Canvas canvas, Size size, Offset center) {
    if (gridProgress <= 0.0) return;

    final fineGridPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withOpacity(gridProgress * 0.15)
      ..strokeWidth = 0.5;

    // Draw coordinate lines grid (every 40px)
    const double gridSpacing = 40.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), fineGridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), fineGridPaint);
    }

    // Draw main center lines drawing outward from the center
    final centerLinePaint = Paint()
      ..color = const Color(0xFF94A3B8).withOpacity(gridProgress * 0.45)
      ..strokeWidth = 1.0;

    final double verticalLength = (size.height / 2) * gridProgress;
    final double horizontalLength = (size.width / 2) * gridProgress;

    // Vertical center line
    canvas.drawLine(
      Offset(center.dx, center.dy - verticalLength),
      Offset(center.dx, center.dy + verticalLength),
      centerLinePaint,
    );

    // Horizontal center line
    canvas.drawLine(
      Offset(center.dx - horizontalLength, center.dy),
      Offset(center.dx + horizontalLength, center.dy),
      centerLinePaint,
    );
  }

  void _paintCornerBrackets(Canvas canvas, Size size) {
    if (cornerProgress <= 0.0) return;

    final bracketPaint = Paint()
      ..color = const Color(0xFF475569).withOpacity(cornerProgress)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const double padding = 20.0;
    final double lineLength = 20.0 * cornerProgress;

    // Top-Left
    canvas.drawLine(const Offset(padding, padding), Offset(padding + lineLength, padding), bracketPaint);
    canvas.drawLine(const Offset(padding, padding), Offset(padding, padding + lineLength), bracketPaint);

    // Top-Right
    canvas.drawLine(Offset(size.width - padding, padding), Offset(size.width - padding - lineLength, padding), bracketPaint);
    canvas.drawLine(Offset(size.width - padding, padding), Offset(size.width - padding, padding + lineLength), bracketPaint);

    // Bottom-Left
    canvas.drawLine(Offset(padding, size.height - padding), Offset(padding + lineLength, size.height - padding), bracketPaint);
    canvas.drawLine(Offset(padding, size.height - padding), Offset(padding, size.height - padding - lineLength), bracketPaint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width - padding, size.height - padding), Offset(size.width - padding - lineLength, size.height - padding), bracketPaint);
    canvas.drawLine(Offset(size.width - padding, size.height - padding), Offset(size.width - padding, size.height - padding - lineLength), bracketPaint);
  }

  void _paintLogoSquare(Canvas canvas, Offset center) {
    const double squareSize = 160.0;
    final double left = center.dx - squareSize / 2;
    final double top = center.dy - 70 - squareSize / 2; // Offset upward to clear space for text

    // 1. Draw outer boundary clockwise using path metrics
    if (logoSquareProgress > 0.0) {
      final Path rectPath = Path();
      rectPath.addRect(Rect.fromLTWH(left, top, squareSize, squareSize));

      final outlinePaint = Paint()
        ..color = const Color(0xFF475569)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final Path drawnPath = Path();
      for (final PathMetric metric in rectPath.computeMetrics()) {
        final double extractLength = metric.length * logoSquareProgress;
        drawnPath.addPath(metric.extractPath(0.0, extractLength), Offset.zero);
      }
      canvas.drawPath(drawnPath, outlinePaint);
    }

    // 2. Draw cross diagonal lines
    if (logoCrossProgress > 0.0) {
      final crossPaint = Paint()
        ..color = const Color(0xFF64748B).withOpacity(logoCrossProgress * 0.5)
        ..strokeWidth = 0.8;

      // Diagonal 1: Top-Left to Bottom-Right
      canvas.drawLine(
        Offset(left, top),
        Offset(left + squareSize * logoCrossProgress, top + squareSize * logoCrossProgress),
        crossPaint,
      );

      // Diagonal 2: Top-Right to Bottom-Left
      canvas.drawLine(
        Offset(left + squareSize, top),
        Offset(left + squareSize - squareSize * logoCrossProgress, top + squareSize * logoCrossProgress),
        crossPaint,
      );
    }

    // 3. Scale up accent solid corner squares
    if (logoCornerSquaresProgress > 0.0) {
      final accentPaint = Paint()
        ..color = const Color(0xFF475569).withOpacity(logoCornerSquaresProgress)
        ..style = PaintingStyle.fill;

      final double accentSize = 6.0 * logoCornerSquaresProgress;
      final double halfSize = accentSize / 2;

      final List<Offset> corners = [
        Offset(left, top),
        Offset(left + squareSize, top),
        Offset(left + squareSize, top + squareSize),
        Offset(left, top + squareSize),
      ];

      for (final corner in corners) {
        canvas.drawRect(
          Rect.fromLTWH(corner.dx - halfSize, corner.dy - halfSize, accentSize, accentSize),
          accentPaint,
        );
      }
    }

    // 4. Draw Center Box & 'LOGO' Text
    if (logoCenterBoxProgress > 0.0) {
      final double progress = logoCenterBoxProgress;
      final double boxW = 84.0 * progress;
      final double boxH = 34.0 * progress;

      final Rect centerRect = Rect.fromCenter(
        center: Offset(center.dx, center.dy - 70),
        width: boxW,
        height: boxH,
      );

      // White fill
      final fillPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRect(centerRect, fillPaint);

      // Border outline
      final borderPaint = Paint()
        ..color = const Color(0xFF475569).withOpacity(progress)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawRect(centerRect, borderPaint);

      // Draw "LOGO" text when box is almost fully drawn
      if (progress > 0.8) {
        final double textOpacity = ((progress - 0.8) / 0.2).clamp(0.0, 1.0);
        final textPainter = TextPainter(
          text: TextSpan(
            text: 'LOGO',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: const Color(0xFF475569).withOpacity(textOpacity),
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            center.dx - textPainter.width / 2,
            center.dy - 70 - textPainter.height / 2,
          ),
        );
      }
    }
  }

  void _paintCrosshairs(Canvas canvas, Size size) {
    if (hoverPosition == null) return;

    final Offset pos = hoverPosition!;

    final crosshairPaint = Paint()
      ..color = const Color(0xFF3F51B5).withOpacity(0.25)
      ..strokeWidth = 0.8;

    // Draw horizontal dashed lines
    _drawDashedLine(canvas, Offset(0, pos.dy), Offset(size.width, pos.dy), crosshairPaint, 6, 4);

    // Draw vertical dashed lines
    _drawDashedLine(canvas, Offset(pos.dx, 0), Offset(pos.dx, size.height), crosshairPaint, 6, 4);

    // Draw Coordinates label box
    double boxX = pos.dx + 12;
    double boxY = pos.dy - 28;

    if (boxX + 90 > size.width) {
      boxX = pos.dx - 102;
    }
    if (boxY < 12) {
      boxY = pos.dy + 12;
    }

    final boxPaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.85)
      ..style = PaintingStyle.fill;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(boxX, boxY, 90, 20),
      const Radius.circular(3),
    );
    canvas.drawRRect(rrect, boxPaint);

    final coordTextPainter = TextPainter(
      text: TextSpan(
        text: 'X:${pos.dx.toStringAsFixed(0)} Y:${pos.dy.toStringAsFixed(0)}',
        style: const TextStyle(
          fontSize: 9,
          fontFamily: 'monospace',
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    coordTextPainter.layout();
    coordTextPainter.paint(
      canvas,
      Offset(boxX + 6, boxY + 4),
    );
  }

  void _paintRipples(Canvas canvas) {
    for (final ripple in ripples) {
      final double progress = ripple.progress;
      if (progress >= 1.0) continue;

      final double radius = ripple.radius;
      final double opacity = ripple.opacity;

      // Main ripple circle
      final ripplePaint = Paint()
        ..color = const Color(0xFF3F51B5).withOpacity(opacity * 0.35)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(ripple.position, radius, ripplePaint);

      // Outer ripple circle (offset, fainter)
      final outerRipplePaint = Paint()
        ..color = const Color(0xFF3F51B5).withOpacity(opacity * 0.15)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(ripple.position, radius * 1.15, outerRipplePaint);

      // Radius line at 35 degrees
      const double angle = 35.0 * pi / 180.0;
      final Offset endLine = Offset(
        ripple.position.dx + radius * cos(angle),
        ripple.position.dy - radius * sin(angle),
      );

      final linePaint = Paint()
        ..color = const Color(0xFF3F51B5).withOpacity(opacity * 0.5)
        ..strokeWidth = 1.0;
      canvas.drawLine(ripple.position, endLine, linePaint);

      // Label showing active radius: R: 42 px
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'R:${radius.toStringAsFixed(0)}px',
          style: TextStyle(
            fontSize: 9,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: const Color(0xFF3F51B5).withOpacity(opacity * 0.8),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Position text along the radius line
      final Offset textPos = Offset(
        ripple.position.dx + (radius / 2) * cos(angle) + 4,
        ripple.position.dy - (radius / 2) * sin(angle) - 12,
      );
      textPainter.paint(canvas, textPos);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, double dashWidth, double dashSpace) {
    final double distance = (p2 - p1).distance;
    final Offset direction = (p2 - p1) / distance;
    double currentDist = 0;
    while (currentDist < distance) {
      final Offset start = p1 + direction * currentDist;
      final double endDist = (currentDist + dashWidth).clamp(0.0, distance);
      final Offset end = p1 + direction * endDist;
      canvas.drawLine(start, end, paint);
      currentDist += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant BlueprintPainter oldDelegate) {
    return oldDelegate.gridProgress != gridProgress ||
        oldDelegate.cornerProgress != cornerProgress ||
        oldDelegate.logoSquareProgress != logoSquareProgress ||
        oldDelegate.logoCrossProgress != logoCrossProgress ||
        oldDelegate.logoCornerSquaresProgress != logoCornerSquaresProgress ||
        oldDelegate.logoCenterBoxProgress != logoCenterBoxProgress ||
        oldDelegate.hoverPosition != hoverPosition ||
        oldDelegate.ripples.length != ripples.length ||
        _ripplesChanged(oldDelegate.ripples, ripples);
  }

  bool _ripplesChanged(List<BlueprintRipple> oldList, List<BlueprintRipple> newList) {
    if (oldList.length != newList.length) return true;
    for (int i = 0; i < oldList.length; i++) {
      if (oldList[i].ageMs != newList[i].ageMs) return true;
    }
    return false;
  }
}
