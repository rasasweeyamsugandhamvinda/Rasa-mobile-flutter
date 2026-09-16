import 'dart:math' as math;

import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onAnimationComplete;

  const SplashScreen({super.key, this.onAnimationComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // --- Controllers ---
  late AnimationController _masterSprayController;
  late Animation<double> _sprayProgress;

  late AnimationController _entranceController;
  late Animation<double> _bottleScale;
  late Animation<double> _bottleOpacity;
  late Animation<double> _textTranslateY;
  late Animation<double> _textOpacity;

  late AnimationController _blobPulseController;
  late AnimationController _spinnerColorController;
  late Animation<Color?> _spinnerColorAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Mist & Nozzle Loop (1.8s)
    _masterSprayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _sprayProgress = CurvedAnimation(
      parent: _masterSprayController,
      curve: Curves.easeOutCubic,
    );

    // 2. Entrance Animation (Bottle & Text)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _bottleScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.4,
          end: 1.12,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.12,
          end: 0.96,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.96,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(_entranceController);

    _bottleOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 55,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
    ]).animate(_entranceController);

    _textTranslateY = Tween<double>(begin: 16.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // 3. Blob Breathing/Pulse Loop (Continuous 6s loop)
    _blobPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // 4. M3 Spinner Color Cycle Loop (3s loop)
    _spinnerColorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _spinnerColorAnimation = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(
          begin: const Color(0xFFD0BCFF),
          end: const Color(0xFF7ADEC6),
        ),
        weight: 33,
      ),
      TweenSequenceItem(
        tween: ColorTween(
          begin: const Color(0xFF7ADEC6),
          end: const Color(0xFFFFB599),
        ),
        weight: 33,
      ),
      TweenSequenceItem(
        tween: ColorTween(
          begin: const Color(0xFFFFB599),
          end: const Color(0xFFD0BCFF),
        ),
        weight: 34,
      ),
    ]).animate(_spinnerColorController);

    // Start Entrance
    _entranceController.forward();

    // Optional Auto-route
    // Future.delayed(const Duration(seconds: 4), () {
    //   widget.onAnimationComplete?.call();
    // });
  }

  @override
  void dispose() {
    _masterSprayController.dispose();
    _entranceController.dispose();
    _blobPulseController.dispose();
    _spinnerColorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141218),
      body: Stack(
        children: [
          // ============================================================
          // ORGANIC MATERIAL BLOBS
          // ============================================================
          AnimatedBuilder(
            animation: _blobPulseController,
            builder: (context, child) {
              final double t = _blobPulseController.value * 2 * math.pi;

              // Math functions to simulate CSS delayed pulse/float
              final double scale1 = 1.0 + 0.15 * math.sin(t);

              final double scale2 = 1.0 + 0.15 * math.sin(t - (math.pi / 2));

              final double scale3 = 1.0 + 0.15 * math.sin(t - math.pi);

              return Stack(
                children: [
                  // ----------------------------------------------------
                  // Top Right Purple Blob
                  // ----------------------------------------------------
                  Positioned(
                    top: -60,
                    right: -70,
                    child: Transform.translate(
                      offset: Offset(6 * math.sin(t), -8 * math.sin(t)),
                      child: Transform.scale(
                        scale: scale1,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5B3FCF).withOpacity(0.5),
                            borderRadius: const BorderRadius.all(
                              Radius.elliptical(120, 100),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ----------------------------------------------------
                  // Bottom Left Teal Blob
                  // ----------------------------------------------------
                  Positioned(
                    bottom: -80,
                    left: -60,
                    child: Transform.translate(
                      offset: Offset(
                        6 * math.sin(t - math.pi / 2),
                        -8 * math.sin(t - math.pi / 2),
                      ),
                      child: Transform.scale(
                        scale: scale2,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1FA98C).withOpacity(0.4),
                            borderRadius: const BorderRadius.all(
                              Radius.elliptical(100, 110),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ----------------------------------------------------
                  // Middle Left Orange Blob
                  // ----------------------------------------------------
                  Positioned(
                    top: 130,
                    left: -40,
                    child: Transform.translate(
                      offset: Offset(
                        6 * math.sin(t - math.pi),
                        -8 * math.sin(t - math.pi),
                      ),
                      child: Transform.scale(
                        scale: scale3,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF2734A).withOpacity(0.28),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ============================================================
          // MAIN FOREGROUND CONTENT
          // ============================================================
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ======================================================
                  // BOTTLE & MIST
                  // ======================================================
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _entranceController,
                      _masterSprayController,
                    ]),
                    builder: (context, child) {
                      return Opacity(
                        opacity: _bottleOpacity.value,
                        child: Transform.scale(
                          scale: _bottleScale.value,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              // ------------------------------------------------
                              // Mist Particles
                              // ------------------------------------------------
                              Positioned(
                                top: 4,
                                right: -2,
                                child: SizedBox(
                                  width: 0,
                                  height: 0,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      _buildMistParticle(
                                        translateX: _tween(0, 80),
                                        translateY: _tween(0, -20),
                                        scale: _tween(0.2, 3.5),
                                        opacity: _opacitySequence(
                                          weight1: 5,
                                          end1: 0.7,
                                          weight2: 45,
                                          end2: 0.0,
                                          weight3: 50,
                                        ),
                                      ),
                                      _buildMistParticle(
                                        translateX: _tween(0, 60),
                                        translateY: _tween(0, -50),
                                        scale: _tween(0.2, 2.5),
                                        opacity: _opacitySequence(
                                          weight1: 10,
                                          end1: 0.5,
                                          weight2: 50,
                                          end2: 0.0,
                                          weight3: 40,
                                        ),
                                      ),
                                      _buildMistParticle(
                                        translateX: _tween(0, 70),
                                        translateY: _tween(0, 10),
                                        scale: _tween(0.2, 2.0),
                                        opacity: _opacitySequence(
                                          weight1: 15,
                                          end1: 0.4,
                                          weight2: 55,
                                          end2: 0.0,
                                          weight3: 30,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // =================================================
                              // BOTTLE CONSTRUCTION
                              // =================================================
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // ---------------------------------------------
                                  // Nozzle
                                  // ---------------------------------------------
                                  Transform.translate(
                                    offset: Offset(0, _nozzleY()),
                                    child: Container(
                                      width: 16,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFD0BCFF),
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(3),
                                          bottom: Radius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // ---------------------------------------------
                                  // Neck
                                  // ---------------------------------------------
                                  Container(
                                    width: 22,
                                    height: 12,
                                    color: const Color(0xFF49454F),
                                  ),

                                  // =================================================
                                  // Body
                                  // =================================================
                                  Container(
                                    width: 92,
                                    height: 128,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2B2930),
                                      borderRadius: BorderRadius.circular(32),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                        width: 0.5,
                                      ),
                                    ),

                                    // IMPORTANT:
                                    // Clip all children of the bottle to the
                                    // same rounded shape as the bottle itself.
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(32),
                                      clipBehavior: Clip.antiAlias,
                                      child: Stack(
                                        children: [
                                          // ========================================
                                          // Specular Reflection
                                          // ========================================
                                          Positioned(
                                            top: -20,
                                            left: -16,
                                            child: Transform.rotate(
                                              angle: -18 * (math.pi / 180),
                                              child: Container(
                                                width: 56,
                                                height: 150,
                                                color: Colors.white.withOpacity(
                                                  0.06,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // ========================================
                                          // Droplet Icon
                                          // ========================================
                                          const Center(
                                            child: Icon(
                                              Icons.water_drop_rounded,
                                              size: 34,
                                              color: Color(0xFFD0BCFF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // ============================================================
                  // TEXT
                  // ============================================================
                  AnimatedBuilder(
                    animation: _entranceController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _textOpacity.value,
                        child: Transform.translate(
                          offset: Offset(0, _textTranslateY.value),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // -----------------------------------------------
                              // RASA
                              // -----------------------------------------------
                              const Text(
                                'RASA',
                                style: TextStyle(
                                  fontFamily: 'GoogleSansFlexHero',
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 5.0,
                                  color: Color(0xFFE6E0E9),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // -----------------------------------------------
                              // TAGLINE
                              // -----------------------------------------------
                              Text(
                                'SWEEYAM SUGANDHAM VINDA',
                                style: TextStyle(
                                  fontFamily: 'GoogleSansFlexDisplay',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 2.0,
                                  color: const Color(0xFFE6E0E9)
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // ============================================================
                  // M3 SPINNER
                  // ============================================================
                  AnimatedBuilder(
                    animation: _spinnerColorController,
                    builder: (context, child) {
                      return SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          strokeCap: StrokeCap.round,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _spinnerColorAnimation.value ??
                                const Color(0xFFD0BCFF),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // Animation Helpers
  // ========================================================================

  double _tween(double begin, double end) {
    return Tween<double>(begin: begin, end: end).evaluate(_sprayProgress);
  }

  double _opacitySequence({
    required double weight1,
    required double end1,
    required double weight2,
    required double end2,
    required double weight3,
  }) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: end1),
        weight: weight1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: end1, end: end2),
        weight: weight2,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: weight3),
    ]).evaluate(_sprayProgress);
  }

  double _nozzleY() {
    return TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 4.0), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 85),
    ]).evaluate(_sprayProgress);
  }

  Widget _buildMistParticle({
    required double translateX,
    required double translateY,
    required double scale,
    required double opacity,
  }) {
    // Start offset slightly back to mimic the -10px, -10px from CSS
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translate(translateX - 10, translateY - 10)
        ..scale(scale),
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.85),
            border: Border.all(
              color: const Color(0xFFD0BCFF).withOpacity(0.3),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
