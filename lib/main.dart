import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'splash_screen.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart';
import 'recommendations_screen.dart';
import 'profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  runApp(const RasaApp());
}

// ============================================================================
// RASA DESIGN TOKENS
// ============================================================================

abstract final class RasaColors {
  // Core surfaces
  static const background = Color(0xFF141218);
  static const surface = Color(0xFF1B191F);
  static const surfaceContainer = Color(0xFF211F26);
  static const surfaceContainerHigh = Color(0xFF2B2930);

  // Text
  static const onSurface = Color(0xFFE6E0E9);
  static const onSurfaceVariant = Color(0xFFCAC4D0);
  static const muted = Color(0xFF938F99);

  // Brand
  static const lavender = Color(0xFFD0BCFF);
  static const lavenderSoft = Color(0xFFBFA8F5);
  static const lavenderDeep = Color(0xFF381E72);

  // Semantic accents
  static const teal = Color(0xFF9ADCCB);
  static const tealContainer = Color(0xFF183A35);
  static const tealOutline = Color(0xFF356C62);

  static const peach = Color(0xFFFFB599);
  static const peachContainer = Color(0xFF3A2D24);
  static const peachOutline = Color(0xFF75563F);

  static const purpleContainer = Color(0xFF2F2842);
  static const purpleOutline = Color(0xFF66558A);

  // Ambient background colors
  static const ambientPurple = Color(0xFF5B3FCF);
  static const ambientTeal = Color(0xFF1FA98C);
  static const ambientOrange = Color(0xFFF2734A);
}

// ============================================================================
// RASA APP
// ============================================================================

class RasaApp extends StatelessWidget {
  const RasaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rasa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'GoogleSansFlexUI',
        scaffoldBackgroundColor: RasaColors.background,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(
          surface: RasaColors.background,
          primary: RasaColors.lavender,
          onPrimary: RasaColors.lavenderDeep,
          secondary: RasaColors.teal,
          tertiary: RasaColors.peach,
          onSurface: RasaColors.onSurface,
          onSurfaceVariant: RasaColors.onSurfaceVariant,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// ============================================================================
// MAIN SCREEN
// ============================================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  // --------------------------------------------------------------------------
  // Application State
  // --------------------------------------------------------------------------

  bool _splashVisible = true;
  bool _authVisible = false;
  bool _onboardingVisible = false;
  bool _isFullyAuthenticated = false;

  // Recommendations
  bool _isGenerating = false;
  bool _recommendationsVisible = false;
  List<dynamic> _recommendationResults = [];

  int _activeTabIdx = 0;

  String _prompt = '';

  final TextEditingController _textController = TextEditingController();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String get _apiBaseUrl =>
      dotenv.env['EXPO_PUBLIC_API_BASE_URL'] ?? 'http://10.0.2.2:8080';

  // --------------------------------------------------------------------------
  // Animation
  // --------------------------------------------------------------------------

  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // --------------------------------------------------------------------------
  // Lifecycle
  // --------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<double>(begin: 100.0, end: 0.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.018).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);

    _initializeAuthCheck();

    Future.delayed(const Duration(milliseconds: 3200), () {
      if (!mounted) return;

      setState(() {
        _splashVisible = false;
      });

      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    _textController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // AUTHENTICATION
  // ==========================================================================

  Future<void> _initializeAuthCheck() async {
    final String? token = await _secureStorage.read(key: 'accessToken');

    if (token != null) {
      await _checkOnboardingStatus();
    }
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      final String? token = await _secureStorage.read(key: 'accessToken');

      if (token == null) return;

      final response = await http.get(
        Uri.parse('$_apiBaseUrl/identity/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded['success'] == true) {
          final data = decoded['data'];

          final bool isCompleted = data['onboardingCompleted'] ?? false;

          setState(() {
            _authVisible = false;

            if (!isCompleted) {
              _onboardingVisible = true;
              _isFullyAuthenticated = false;
            } else {
              _onboardingVisible = false;
              _isFullyAuthenticated = true;
            }
          });
        }
      } else {
        setState(() {
          _isFullyAuthenticated = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
    }
  }

  // ==========================================================================
  // INPUT / NAVIGATION
  // ==========================================================================

  void _handleChipPress(String text) {
    final cleanText = text.replaceAll('"', '');

    setState(() {
      _prompt = cleanText;
    });

    _textController.text = cleanText;

    _textController.selection = TextSelection.collapsed(
      offset: _textController.text.length,
    );
  }

  void _handleTabPress(int index, String tabName) {
    setState(() {
      _activeTabIdx = index;

      if ((tabName == 'Collection' ||
              tabName == 'Wardrobe' ||
              tabName == 'Profile') &&
          !_isFullyAuthenticated) {
        _authVisible = true;
      } else {
        _authVisible = false;
        _onboardingVisible = false;
      }
    });
  }

  // ==========================================================================
  // RECOMMENDATION ENGINE
  // ==========================================================================

  Future<void> _handlePromptSubmit() async {
    if (_prompt.trim().isEmpty) {
      return;
    }

    if (!_isFullyAuthenticated) {
      setState(() {
        _authVisible = true;
      });

      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final String? token = await _secureStorage.read(key: 'accessToken');

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/recommendations/generate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"prompt": _prompt.trim()}),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _recommendationResults = data['data'];
          _recommendationsVisible = true;
        });
      } else {
        _showRasaSnackBar(
          data['message'] ?? 'Failed to generate recommendations.',
        );
      }
    } catch (e) {
      debugPrint('Recommendation Generation Error: $e');

      if (!mounted) return;

      _showRasaSnackBar('Network error connecting to AI engine.');
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  void _showRasaSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 92),
        backgroundColor: RasaColors.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'GoogleSansFlexUI',
            color: RasaColors.onSurface,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final bool isInputEmpty = _prompt.trim().isEmpty;

    return Scaffold(
      backgroundColor: RasaColors.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ==================================================================
          // AMBIENT BACKGROUND
          // ==================================================================

          if (!_splashVisible) const _RasaAmbientBackground(),

          // ==================================================================
          // MAIN DISCOVER CONTENT
          // ==================================================================
          if (!_splashVisible)
            AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                final double progress = (1 - (_slideAnimation.value / 100))
                    .clamp(0.0, 1.0);

                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Opacity(opacity: progress, child: child),
                );
              },
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ------------------------------------------------------
                      // HERO
                      // ------------------------------------------------------

                      RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Describe\n',
                              style: TextStyle(
                                fontFamily: 'GoogleSansFlexDisplay',
                                color: RasaColors.onSurface,
                                fontSize: 40,
                                height: 1.02,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.5,
                              ),
                            ),
                            TextSpan(
                              text: 'the ',
                              style: TextStyle(
                                fontFamily: 'GoogleSansFlexDisplay',
                                color: RasaColors.onSurface,
                                fontSize: 40,
                                height: 1.02,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -1.5,
                              ),
                            ),
                            const TextSpan(
                              text: 'moment.',
                              style: TextStyle(
                                fontFamily: 'GoogleSansFlexDisplay',
                                color: RasaColors.lavender,
                                fontSize: 40,
                                height: 1.02,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        "We'll find the fragrance.",
                        style: TextStyle(
                          fontFamily: 'GoogleSansFlexUI',
                          color: RasaColors.onSurface.withOpacity(0.68),
                          fontSize: 16,
                          height: 1.3,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.05,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ------------------------------------------------------
                      // AI PROMPT COMPOSER
                      // ------------------------------------------------------
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: _buildPromptComposer(isInputEmpty: isInputEmpty),
                      ),

                      const SizedBox(height: 30),

                      // ------------------------------------------------------
                      // SUGGESTION LABEL
                      // ------------------------------------------------------
                      Text(
                        'TRY TYPING THIS',
                        style: const TextStyle(
                          fontFamily: 'GoogleSansFlexUI',
                          color: RasaColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ------------------------------------------------------
                      // SUGGESTION CHIPS
                      // ------------------------------------------------------
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildM3Chip(
                            text: '"A fresh office scent for the Raipur heat in budget"',
                            icon: Icons.eco_rounded,
                            foregroundColor: RasaColors.teal,
                            backgroundColor: RasaColors.tealContainer,
                            borderColor: RasaColors.tealOutline.withOpacity(
                              0.32,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildM3Chip(
                            text: '"A gym-friendly fragrance that dries down to moss"',
                            icon: Icons.wb_sunny_rounded,
                            foregroundColor: RasaColors.peach,
                            backgroundColor: RasaColors.peachContainer,
                            borderColor: RasaColors.peachOutline.withOpacity(
                              0.32,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildM3Chip(
                            text: '"Something dark and atmospheric for a date night"',
                            icon: Icons.favorite_rounded,
                            foregroundColor: RasaColors.lavender,
                            backgroundColor: RasaColors.purpleContainer,
                            borderColor: RasaColors.purpleOutline.withOpacity(
                              0.30,
                            ),
                          ),
                        ],
                      ),

                      // ------------------------------------------------------
                      // BOTTOM BREATHING ROOM
                      // ------------------------------------------------------
                      const SizedBox(height: 118),
                    ],
                  ),
                ),
              ),
            ),
          if (!_splashVisible &&
              !_authVisible &&
              !_onboardingVisible &&
              !_recommendationsVisible &&
              _isFullyAuthenticated &&
              _activeTabIdx == 3)
            ProfileScreen(
              onLogout: () {
                setState(() {
                  _isFullyAuthenticated = false;
                  _authVisible = true;
                  _onboardingVisible = false;
                  _activeTabIdx = 0;
                });
              },
            ),
          // ==================================================================
          // NAVIGATION
          // ==================================================================
          if (!_splashVisible &&
              !_authVisible &&
              !_onboardingVisible &&
              !_recommendationsVisible)
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: M3FloatingNavbar(
                activeIndex: _activeTabIdx,
                isFullyAuthenticated: _isFullyAuthenticated,
                onTabPress: _handleTabPress,
              ),
            ),

          // ==================================================================
          // RECOMMENDATIONS
          // ==================================================================
          if (_recommendationsVisible)
            RecommendationsScreen(
              prompt: _prompt,
              recommendations: _recommendationResults,
              onClose: () {
                setState(() {
                  _recommendationsVisible = false;
                });
              },
            ),

          // ==================================================================
          // AUTH
          // ==================================================================
          if (_authVisible)
            AuthScreen(
              onClose: () {
                setState(() {
                  _authVisible = false;
                  _activeTabIdx = 0;
                });
              },
              onSuccess: (tokens) {
                _checkOnboardingStatus();
              },
            ),

          // ==================================================================
          // ONBOARDING
          // ==================================================================
          if (_onboardingVisible)
            OnboardingScreen(
              onComplete: () {
                setState(() {
                  _onboardingVisible = false;
                  _isFullyAuthenticated = true;
                  _activeTabIdx = 0;
                });
              },

              // Back from Step 0 → return to authentication.
              onBack: () {
                setState(() {
                  _onboardingVisible = false;
                  _authVisible = true;
                });
              },
            ),

          // ==================================================================
          // SPLASH
          // ==================================================================
          if (_splashVisible) const SplashScreen(),
        ],
      ),
    );
  }

  // ==========================================================================
  // PROMPT COMPOSER
  // ==========================================================================

  Widget _buildPromptComposer({required bool isInputEmpty}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 82, maxHeight: 148),
      decoration: BoxDecoration(
        color: RasaColors.surfaceContainer,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: isInputEmpty
              ? RasaColors.onSurface.withOpacity(0.035)
              : RasaColors.lavender.withOpacity(0.22),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ------------------------------------------------------------
            // SPARKLE
            // ------------------------------------------------------------

            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isInputEmpty
                    ? RasaColors.surfaceContainerHigh
                    : RasaColors.purpleContainer,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 21,
                color: isInputEmpty ? RasaColors.muted : RasaColors.lavender,
              ),
            ),

            const SizedBox(width: 12),

            // ------------------------------------------------------------
            // TEXT INPUT
            // ------------------------------------------------------------
            Expanded(
              child: TextField(
                controller: _textController,
                onChanged: (value) {
                  setState(() {
                    _prompt = value;
                  });
                },
                maxLines: null,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontFamily: 'GoogleSansFlexUI',
                  color: RasaColors.onSurface,
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                ),
                cursorColor: RasaColors.lavender,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'How do you want to smell?',
                  hintStyle: TextStyle(
                    fontFamily: 'GoogleSansFlexUI',
                    color: RasaColors.muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // ------------------------------------------------------------
            // ACTION
            // ------------------------------------------------------------
            GestureDetector(
              onTap: (isInputEmpty || _isGenerating)
                  ? null
                  : _handlePromptSubmit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isInputEmpty
                      ? RasaColors.surfaceContainerHigh
                      : RasaColors.lavender,
                ),
                child: _isGenerating
                    ? const Padding(
                        padding: EdgeInsets.all(15),
                        child: CircularProgressIndicator(
                          color: RasaColors.lavenderDeep,
                          strokeWidth: 2.5,
                          strokeCap: StrokeCap.round,
                        ),
                      )
                    : Icon(
                        Icons.arrow_upward_rounded,
                        size: 23,
                        color: isInputEmpty
                            ? RasaColors.muted
                            : RasaColors.lavenderDeep,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TONAL SUGGESTION CHIP
  // ==========================================================================

  Widget _buildM3Chip({
    required String text,
    required IconData icon,
    required Color foregroundColor,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleChipPress(text),
        borderRadius: BorderRadius.circular(24),
        splashColor: foregroundColor.withOpacity(0.08),
        highlightColor: foregroundColor.withOpacity(0.035),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ----------------------------------------------------------
              // ICON
              // ----------------------------------------------------------

              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: foregroundColor.withOpacity(0.10),
                ),
                child: Icon(icon, size: 17, color: foregroundColor),
              ),

              const SizedBox(width: 12),

              // ----------------------------------------------------------
              // TEXT
              // ----------------------------------------------------------
              Expanded(
                child: Text(
                  text.replaceAll('"', ''),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'GoogleSansFlexUI',
                    color: RasaColors.onSurface,
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// AMBIENT RASA BACKGROUND
// ============================================================================

class _RasaAmbientBackground extends StatelessWidget {
  const _RasaAmbientBackground();

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);

    return IgnorePointer(
      child: Stack(
        children: [
          // --------------------------------------------------------------
          // TOP-RIGHT PURPLE ORGANIC FORM
          // --------------------------------------------------------------

          Positioned(
            top: -110,
            right: -90,
            child: _AmbientBlob(
              width: 260,
              height: 260,
              color: RasaColors.ambientPurple,
              opacity: 0.085,
              blur: 30,
            ),
          ),

          // --------------------------------------------------------------
          // LEFT ORANGE FORM
          // --------------------------------------------------------------
          Positioned(
            top: size.height * 0.16,
            left: -72,
            child: _AmbientBlob(
              width: 150,
              height: 150,
              color: RasaColors.ambientOrange,
              opacity: 0.055,
              blur: 24,
            ),
          ),

          // --------------------------------------------------------------
          // BOTTOM-LEFT TEAL FORM
          // --------------------------------------------------------------
          Positioned(
            bottom: -95,
            left: -72,
            child: _AmbientBlob(
              width: 230,
              height: 230,
              color: RasaColors.ambientTeal,
              opacity: 0.075,
              blur: 28,
            ),
          ),

          // --------------------------------------------------------------
          // SMALL LAVENDER ATMOSPHERIC GLOW
          // --------------------------------------------------------------
          Positioned(
            top: size.height * 0.43,
            right: -100,
            child: _AmbientBlob(
              width: 180,
              height: 180,
              color: RasaColors.lavender,
              opacity: 0.025,
              blur: 45,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double opacity;
  final double blur;

  const _AmbientBlob({
    required this.width,
    required this.height,
    required this.color,
    required this.opacity,
    required this.blur,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color.withOpacity(opacity),
          borderRadius: BorderRadius.circular(width * 0.42),
        ),
      ),
    );
  }
}

// ============================================================================
// MATERIAL YOU EXPRESSIVE NAVBAR
// ============================================================================

class M3FloatingNavbar extends StatelessWidget {
  final int activeIndex;
  final bool isFullyAuthenticated;
  final Function(int, String) onTabPress;

  const M3FloatingNavbar({
    super.key,
    required this.activeIndex,
    required this.isFullyAuthenticated,
    required this.onTabPress,
  });

  // --------------------------------------------------------------------------
  // Navigation
  // --------------------------------------------------------------------------

  static const List<String> tabs = [
    'Discover',
    'Collection',
    'Wardrobe',
    'Profile',
  ];

  static const List<IconData> icons = [
    Icons.explore_rounded,
    Icons.collections_bookmark_rounded,
    Icons.checkroom_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        // TONAL SURFACE:
        // Deliberately no large drop shadow.
        color: RasaColors.surfaceContainer,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: RasaColors.onSurface.withOpacity(0.045),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double tabWidth = constraints.maxWidth / tabs.length;

            return Stack(
              children: [
                // ============================================================
                // ACTIVE TONAL CONTAINER
                // ============================================================

                AnimatedPositioned(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  left: activeIndex * tabWidth,
                  top: 6,
                  bottom: 6,
                  width: tabWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: RasaColors.purpleContainer,
                        borderRadius: BorderRadius.circular(27),
                      ),
                    ),
                  ),
                ),

                // ============================================================
                // NAV ITEMS
                // ============================================================
                Row(
                  children: List.generate(tabs.length, (index) {
                    final bool isActive = activeIndex == index;

                    final bool isLocked =
                        !isFullyAuthenticated &&
                        (tabs[index] == 'Collection' ||
                            tabs[index] == 'Wardrobe' ||
                            tabs[index] == 'Profile');

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onTabPress(index, tabs[index]),
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOut,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // ------------------------------------------------
                                // ICON
                                // ------------------------------------------------

                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? RasaColors.lavender
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        icons[index],
                                        size: 20,
                                        color: isActive
                                            ? RasaColors.lavenderDeep
                                            : RasaColors.onSurfaceVariant,
                                      ),
                                    ),

                                    // ----------------------------------------------
                                    // LOCK
                                    // ----------------------------------------------
                                    if (isLocked)
                                      Positioned(
                                        top: -4,
                                        right: -6,
                                        child: Container(
                                          width: 15,
                                          height: 15,
                                          decoration: BoxDecoration(
                                            color: RasaColors.peach,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color:
                                                  RasaColors.surfaceContainer,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.lock_rounded,
                                            size: 7,
                                            color: Color(0xFF35130B),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 1),

                                // ------------------------------------------------
                                // LABEL
                                // ------------------------------------------------
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 220),
                                  style: TextStyle(
                                    fontFamily: 'GoogleSansFlexUI',
                                    color: isActive
                                        ? RasaColors.onSurface
                                        : RasaColors.muted,
                                    fontSize: 11,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    height: 1.0,
                                  ),
                                  child: Text(tabs[index]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
