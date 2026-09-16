import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// ============================================================================
// RASA ONBOARDING DESIGN TOKENS
// ============================================================================

abstract final class _RasaOnboardingColors {
  // --------------------------------------------------------------------------
  // Surfaces
  // --------------------------------------------------------------------------

  static const background = Color(0xFF141218);
  static const surfaceContainer = Color(0xFF211F26);
  static const surfaceHigh = Color(0xFF2B2930);

  // --------------------------------------------------------------------------
  // Text
  // --------------------------------------------------------------------------

  static const onSurface = Color(0xFFE6E0E9);
  static const onSurfaceVariant = Color(0xFFCAC4D0);
  static const muted = Color(0xFF938F99);

  // --------------------------------------------------------------------------
  // Brand
  // --------------------------------------------------------------------------

  static const lavender = Color(0xFFD0BCFF);
  static const lavenderDeep = Color(0xFF381E72);
  static const lavenderContainer = Color(0xFF2F2842);

  // --------------------------------------------------------------------------
  // Accent
  // --------------------------------------------------------------------------

  static const teal = Color(0xFF9ADCCB);
  static const tealContainer = Color(0xFF183A35);

  static const peach = Color(0xFFFFB599);

  // --------------------------------------------------------------------------
  // Feedback
  // --------------------------------------------------------------------------

  static const error = Color(0xFFFFB4AB);
  static const errorContainer = Color(0xFF3B2020);
}

// ============================================================================
// ONBOARDING SCREEN
// ============================================================================

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback? onBack;

  const OnboardingScreen({super.key, required this.onComplete, this.onBack});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

// ============================================================================
// STATE
// ============================================================================

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  // --------------------------------------------------------------------------
  // Current step
  //
  // 0 = Experience
  // 1 = Lifestyle
  // 2 = Preferences (Connoisseur)
  // --------------------------------------------------------------------------

  int _currentStep = 0;

  bool _loading = false;
  bool _fetchingLocation = false;
  bool _fetchingCatalog = false;

  String _errorMessage = '';

  // --------------------------------------------------------------------------
  // Experience
  // --------------------------------------------------------------------------

  String _experienceLevel = 'NOVICE';

  // --------------------------------------------------------------------------
  // Lifestyle
  // --------------------------------------------------------------------------

  final TextEditingController _cityController = TextEditingController();

  final TextEditingController _stateController = TextEditingController();

  String _primaryEnvironment = 'AC_OFFICE';
  String _sweatLevel = 'MODERATE';
  String _vibePreference = 'FRESH_CASUAL';
  String _budgetPreference = 'MID_RANGE';

  // --------------------------------------------------------------------------
  // Connoisseur catalog
  // --------------------------------------------------------------------------

  List<dynamic> _catalogNotes = [];
  List<dynamic> _catalogAccords = [];

  final List<String> _likedNoteIds = [];
  final List<String> _dislikedNoteIds = [];
  final List<String> _preferredAccordIds = [];
  final List<String> _dislikedAccordIds = [];

  // --------------------------------------------------------------------------
  // Search controllers
  // --------------------------------------------------------------------------

  final TextEditingController _likedNoteSearchController =
      TextEditingController();

  final TextEditingController _dislikedNoteSearchController =
      TextEditingController();

  final TextEditingController _likedAccordSearchController =
      TextEditingController();

  final TextEditingController _dislikedAccordSearchController =
      TextEditingController();

  // --------------------------------------------------------------------------
  // Search queries
  // --------------------------------------------------------------------------

  String _likedNoteQuery = '';
  String _dislikedNoteQuery = '';
  String _likedAccordQuery = '';
  String _dislikedAccordQuery = '';

  // --------------------------------------------------------------------------
  // Storage / API
  // --------------------------------------------------------------------------

  final _secureStorage = const FlutterSecureStorage();

  String get _apiBaseUrl =>
      dotenv.env['EXPO_PUBLIC_API_BASE_URL'] ?? 'http://10.0.2.2:8080';

  // --------------------------------------------------------------------------
  // Step animation
  // --------------------------------------------------------------------------

  late AnimationController _stepAnimationController;

  late Animation<Offset> _stepSlideAnimation;

  late Animation<double> _stepFadeAnimation;

  double _edgeDragStartX = 0;

  @override
  void initState() {
    super.initState();

    _stepAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _stepSlideAnimation =
        Tween<Offset>(begin: const Offset(0.075, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _stepAnimationController,
            curve: Curves.easeOutBack,
          ),
        );

    _stepFadeAnimation = CurvedAnimation(
      parent: _stepAnimationController,
      curve: Curves.easeOutCubic,
    );

    _stepAnimationController.forward();
  }

  @override
  void dispose() {
    _stepAnimationController.dispose();

    _cityController.dispose();
    _stateController.dispose();

    _likedNoteSearchController.dispose();

    _dislikedNoteSearchController.dispose();

    _likedAccordSearchController.dispose();

    _dislikedAccordSearchController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // STEP ANIMATION
  // ==========================================================================

  void _animateToStep(int step) {
    if (step == _currentStep || step < 0 || step > 2) {
      return;
    }

    final bool movingForward = step > _currentStep;
    final double startX = movingForward ? 0.075 : -0.075;

    _stepSlideAnimation =
        Tween<Offset>(begin: Offset(startX, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _stepAnimationController,
            curve: Curves.easeOutBack,
          ),
        );

    setState(() {
      _currentStep = step;
      _errorMessage = '';
    });

    _stepAnimationController
      ..reset()
      ..forward();
  }

  void _handleEdgeSwipeEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;

    if (_edgeDragStartX <= 30 && velocity > 350 && !_loading) {
      _handlePreviousStep();
    }
  }

  Future<void> _showChoiceSheet({
    required String title,
    required String selectedValue,
    required Color accent,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) async {
    FocusScope.of(context).unfocus();

    final String? result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.42),
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Material(
              color: _RasaOnboardingColors.surfaceContainer,
              borderRadius: BorderRadius.circular(34),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _RasaOnboardingColors.muted.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'GoogleSansFlexUI',
                              color: _RasaOnboardingColors.onSurface,
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...items.entries.map((entry) {
                      final bool selected = entry.key == selectedValue;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: selected
                              ? accent.withOpacity(0.13)
                              : _RasaOnboardingColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(24),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () =>
                                Navigator.of(sheetContext).pop(entry.key),
                            borderRadius: BorderRadius.circular(24),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOutBack,
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? accent.withOpacity(0.16)
                                          : _RasaOnboardingColors
                                                .surfaceContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      selected
                                          ? Icons.check_rounded
                                          : Icons.chevron_right_rounded,
                                      size: 20,
                                      color: selected
                                          ? accent
                                          : _RasaOnboardingColors.muted,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      entry.value,
                                      style: TextStyle(
                                        fontFamily: 'GoogleSansFlexUI',
                                        color: selected
                                            ? _RasaOnboardingColors.onSurface
                                            : _RasaOnboardingColors
                                                  .onSurfaceVariant,
                                        fontSize: 15,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (result != null && mounted) {
      onChanged(result);
    }
  }

  // ==========================================================================
  // CATALOG
  // ==========================================================================

  Future<void> _fetchCatalogData() async {
    if (_catalogNotes.isNotEmpty && _catalogAccords.isNotEmpty) {
      return;
    }

    setState(() {
      _fetchingCatalog = true;
      _errorMessage = '';
    });

    try {
      final String? token = await _secureStorage.read(key: 'accessToken');

      final responses = await Future.wait([
        http.get(
          Uri.parse('$_apiBaseUrl/catalog/notes'),
          headers: {'Authorization': 'Bearer $token'},
        ),
        http.get(
          Uri.parse('$_apiBaseUrl/catalog/accords'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      ]);

      if (!mounted) return;

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final decodedNotes = jsonDecode(responses[0].body);

        final decodedAccords = jsonDecode(responses[1].body);

        if (decodedNotes is List && decodedAccords is List) {
          setState(() {
            _catalogNotes = decodedNotes;

            _catalogAccords = decodedAccords;
          });
        } else {
          setState(() {
            _errorMessage = 'Invalid catalog data received from server.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load catalog data.';
        });
      }
    } catch (e) {
      debugPrint('Catalog Fetch Error: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Network error fetching notes/accords.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _fetchingCatalog = false;
        });
      }
    }
  }

  // ==========================================================================
  // LOCATION
  // ==========================================================================

  Future<void> _fetchUserLocation() async {
    setState(() {
      _fetchingLocation = true;
      _errorMessage = '';
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          _errorMessage =
              'Location services are disabled. Please enter manually.';
        });

        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          if (!mounted) return;

          setState(() {
            _errorMessage =
                'Location permission denied. Please enter manually.';
          });

          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          _errorMessage =
              'Location permissions permanently denied. Please enter manually.';
        });

        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final geocodingInstance = Geocoding();

      final List<Placemark> placemarks = await geocodingInstance
          .placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;

        if (!mounted) return;

        setState(() {
          _cityController.text =
              place.locality ?? place.subAdministrativeArea ?? '';

          _stateController.text = place.administrativeArea ?? '';
        });
      }
    } catch (e) {
      debugPrint('Location Error: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Could not auto-detect location. Type manually.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _fetchingLocation = false;
        });
      }
    }
  }

  // ==========================================================================
  // SUBMIT ONBOARDING
  // ==========================================================================

  Future<void> _submitOnboarding() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _errorMessage = '';
    });

    try {
      final String? token = await _secureStorage.read(key: 'accessToken');

      final Map<String, dynamic> payload = {
        "experienceLevel": _experienceLevel,

        "lifestyle": {
          "city": _cityController.text.trim().isEmpty
              ? 'Raipur'
              : _cityController.text.trim(),

          "state": _stateController.text.trim().isEmpty
              ? 'Chhattisgarh'
              : _stateController.text.trim(),

          "primaryEnvironment": _primaryEnvironment,

          "sweatLevel": _sweatLevel,

          "vibePreference": _vibePreference,

          "budgetPreference": _budgetPreference,
        },
      };

      // ----------------------------------------------------------------------
      // Connoisseur preferences
      // ----------------------------------------------------------------------

      if (_experienceLevel == 'CONNOISSEUR') {
        payload["preferences"] = {
          "likedNoteIds": _likedNoteIds,

          "dislikedNoteIds": _dislikedNoteIds,

          "preferredAccordIds": _preferredAccordIds,

          "dislikedAccordIds": _dislikedAccordIds,
        };

        payload["pastInteractions"] = [];
      }

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/identity/onboarding'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        widget.onComplete();
      } else {
        setState(() {
          _errorMessage = data['message'] ?? 'Onboarding submission failed.';
        });
      }
    } catch (e) {
      debugPrint('Onboarding Error: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Network error connecting to backend.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ==========================================================================
  // NEXT STEP
  // ==========================================================================

  void _handleNextStep() {
    if (_currentStep == 0) {
      _animateToStep(1);
      _fetchUserLocation();

      return;
    }

    if (_currentStep == 1) {
      if (_experienceLevel == 'NOVICE') {
        _submitOnboarding();
      } else {
        _animateToStep(2);
        _fetchCatalogData();
      }

      return;
    }

    _submitOnboarding();
  }

  // ==========================================================================
  // PREVIOUS STEP
  // ==========================================================================

  void _handlePreviousStep() {
    if (_currentStep <= 0) {
      widget.onBack?.call();
      return;
    }

    FocusScope.of(context).unfocus();
    _animateToStep(_currentStep - 1);
  }

  // ==========================================================================
  // SEARCH / AUTOCOMPLETE
  // ==========================================================================

  List<dynamic> _getFilteredItems(String query, List<dynamic> catalog) {
    final String normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return [];
    }

    final List<dynamic> filtered = catalog.where((item) {
      if (item is! Map) {
        return false;
      }

      final String name = (item['name'] ?? '').toString().trim();

      if (name.isEmpty) {
        return false;
      }

      return name.toLowerCase().contains(normalizedQuery);
    }).toList();

    filtered.sort((a, b) {
      final String aName = (a['name'] ?? '').toString().toLowerCase();

      final String bName = (b['name'] ?? '').toString().toLowerCase();

      final bool aStarts = aName.startsWith(normalizedQuery);

      final bool bStarts = bName.startsWith(normalizedQuery);

      if (aStarts && !bStarts) {
        return -1;
      }

      if (!aStarts && bStarts) {
        return 1;
      }

      return aName.compareTo(bName);
    });

    if (filtered.length > 8) {
      return filtered.take(8).toList();
    }

    return filtered;
  }

  // ==========================================================================
  // SELECT CATALOG ITEM
  // ==========================================================================

  void _selectItem(
    dynamic item,
    List<String> targetList,
    List<String> oppositeList,
    TextEditingController controller,
    Function resetQuery,
  ) {
    final String id = item['id'].toString();

    setState(() {
      if (!targetList.contains(id)) {
        targetList.add(id);
      }

      // Mutual exclusivity
      oppositeList.remove(id);

      controller.clear();

      resetQuery();
    });
  }

  dynamic _findItemById(String id, List<dynamic> catalog) {
    for (final item in catalog) {
      if (item is Map && item['id'].toString() == id) {
        return item;
      }
    }

    return null;
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: _RasaOnboardingColors.background,
        child: Stack(
          children: [
            // ================================================================
            // AMBIENT BACKGROUND
            // ================================================================

            const _OnboardingAmbientBackground(),

            // ================================================================
            // MAIN CONTENT
            // ================================================================
            AnimatedPadding(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // ----------------------------------------------------------
                    // TOP BAR
                    // ----------------------------------------------------------

                    _buildTopBar(),

                    // ----------------------------------------------------------
                    // CONTENT
                    // ----------------------------------------------------------
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 36),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ------------------------------------------------
                              // PROGRESS
                              // ------------------------------------------------

                              _buildProgressIndicator(),

                              const SizedBox(height: 28),

                              // ------------------------------------------------
                              // HEADER
                              // ------------------------------------------------
                              _buildHeader(),

                              const SizedBox(height: 28),

                              // ------------------------------------------------
                              // ERROR
                              // ------------------------------------------------
                              if (_errorMessage.isNotEmpty)
                                _buildErrorMessage(),

                              // ------------------------------------------------
                              // STEP CONTENT
                              // ------------------------------------------------
                              SlideTransition(
                                position: _stepSlideAnimation,
                                child: FadeTransition(
                                  opacity: _stepFadeAnimation,
                                  child: _buildStepContent(),
                                ),
                              ),

                              const SizedBox(height: 28),

                              // ------------------------------------------------
                              // NAVIGATION
                              // ------------------------------------------------
                              _buildNavigation(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ================================================================
            // NARROW EDGE-ONLY SWIPE ZONE
            // ================================================================
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 34,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (DragStartDetails details) {
                  _edgeDragStartX = details.globalPosition.dx;
                },
                onHorizontalDragEnd: (DragEndDetails details) {
                  _handleEdgeSwipeEnd(details);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TOP BAR
  // ==========================================================================

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          const Text(
            'RASA',
            style: TextStyle(
              fontFamily: 'GoogleSansFlexHero',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.5,
              color: _RasaOnboardingColors.onSurface,
            ),
          ),

          const Spacer(),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _RasaOnboardingColors.surfaceContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'PROFILE SETUP',
              style: const TextStyle(
                fontFamily: 'GoogleSansFlexUI',
                color: _RasaOnboardingColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PROGRESS
  // ==========================================================================

  Widget _buildProgressIndicator() {
    final int visibleSteps = _experienceLevel == 'CONNOISSEUR' ? 3 : 2;

    return Row(
      children: [
        for (int index = 0; index < visibleSteps; index++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              height: index <= _currentStep ? 6 : 4,
              decoration: BoxDecoration(
                color: index <= _currentStep
                    ? _RasaOnboardingColors.lavender
                    : _RasaOnboardingColors.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          if (index < visibleSteps - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader() {
    switch (_currentStep) {
      case 0:
        return _buildExpressiveHeader(
          eyebrow: 'STEP 01 · THE BASICS',
          firstLine: 'Tell us',
          accentLine: 'your nose.',
          description:
              'We only need a little context to make Rasa feel personal.',
        );

      case 1:
        return _buildExpressiveHeader(
          eyebrow: 'STEP 02 · YOUR WORLD',
          firstLine: 'Where do',
          accentLine: 'you wear it?',
          description:
              'Your climate, routine and style shape how a fragrance performs.',
        );

      case 2:
        return _buildExpressiveHeader(
          eyebrow: 'STEP 03 · YOUR SIGNATURE',
          firstLine: 'Get',
          accentLine: 'specific.',
          description: 'Tell Rasa about the notes and accords you already love—or avoid.',
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildExpressiveHeader({
    required String eyebrow,
    required String firstLine,
    required String accentLine,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _RasaOnboardingColors.lavender,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              eyebrow,
              style: const TextStyle(
                fontFamily: 'GoogleSansFlexUI',
                color: _RasaOnboardingColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$firstLine\n',
                style: const TextStyle(
                  fontFamily: 'GoogleSansFlexDisplay',
                  fontSize: 42,
                  height: 0.98,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.6,
                  color: _RasaOnboardingColors.onSurface,
                ),
              ),
              TextSpan(
                text: accentLine,
                style: const TextStyle(
                  fontFamily: 'GoogleSansFlexDisplay',
                  fontSize: 42,
                  height: 0.98,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.6,
                  color: _RasaOnboardingColors.lavender,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        Text(
          description,
          style: const TextStyle(
            fontFamily: 'GoogleSansFlexUI',
            color: _RasaOnboardingColors.muted,
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // ERROR
  // ==========================================================================

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _RasaOnboardingColors.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 19,
            color: _RasaOnboardingColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(
                fontFamily: 'GoogleSansFlexUI',
                color: _RasaOnboardingColors.error,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // STEP CONTENT
  // ==========================================================================

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildExperienceStep();

      case 1:
        return _buildLifestyleStep();

      case 2:
        return _buildPreferencesStep();

      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================================================
  // STEP 0 — EXPERIENCE
  // ==========================================================================

  Widget _buildExperienceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExperienceCard(
          title: 'Novice',
          subtitle: 'I just want something that smells great and fits my day.',
          icon: Icons.auto_awesome_rounded,
          selected: _experienceLevel == 'NOVICE',
          accent: _RasaOnboardingColors.teal,
          containerColor: _RasaOnboardingColors.tealContainer,
          onTap: () {
            setState(() {
              _experienceLevel = 'NOVICE';
            });
          },
        ),

        const SizedBox(height: 12),

        _buildExperienceCard(
          title: 'Connoisseur',
          subtitle: 'I care about notes, accords, houses, and the details behind a scent.',
          icon: Icons.science_rounded,
          selected: _experienceLevel == 'CONNOISSEUR',
          accent: _RasaOnboardingColors.lavender,
          containerColor: _RasaOnboardingColors.lavenderContainer,
          onTap: () {
            setState(() {
              _experienceLevel = 'CONNOISSEUR';
            });
          },
        ),

        const SizedBox(height: 18),

        _buildSmallHint(
          icon: Icons.lightbulb_outline_rounded,
          text: 'You can always refine your preferences later.',
        ),
      ],
    );
  }

  Widget _buildExperienceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required Color accent,
    required Color containerColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        splashColor: accent.withOpacity(0.08),
        highlightColor: accent.withOpacity(0.04),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          scale: selected ? 1.0 : 0.985,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutBack,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: selected
                  ? containerColor
                  : _RasaOnboardingColors.surfaceContainer,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: selected
                    ? accent.withOpacity(0.28)
                    : _RasaOnboardingColors.onSurface.withOpacity(0.035),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // --------------------------------------------------------------
                // Icon
                // --------------------------------------------------------------

                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withOpacity(0.12)
                        : _RasaOnboardingColors.surfaceHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 23,
                    color: selected ? accent : _RasaOnboardingColors.muted,
                  ),
                ),

                const SizedBox(width: 14),

                // --------------------------------------------------------------
                // Copy
                // --------------------------------------------------------------
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'GoogleSansFlexUI',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? _RasaOnboardingColors.onSurface
                              : _RasaOnboardingColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'GoogleSansFlexUI',
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w400,
                          color: _RasaOnboardingColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // --------------------------------------------------------------
                // Selection indicator
                // --------------------------------------------------------------
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? accent
                        : _RasaOnboardingColors.surfaceHigh,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: selected
                        ? Icon(
                            Icons.check_rounded,
                            key: const ValueKey('selected'),
                            size: 17,
                            color: accent == _RasaOnboardingColors.lavender
                                ? _RasaOnboardingColors.lavenderDeep
                                : _RasaOnboardingColors.background,
                          )
                        : const SizedBox(key: ValueKey('empty')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // STEP 1 — LIFESTYLE
  // ==========================================================================

  Widget _buildLifestyleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ----------------------------------------------------------------------
        // LOCATION CARD
        // ----------------------------------------------------------------------

        _buildSectionCard(
          title: 'Your location',
          subtitle: 'Climate changes how fragrance behaves on skin.',
          accent: _RasaOnboardingColors.teal,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildLabeledField(
                      label: 'City',
                      controller: _cityController,
                      hint: 'Raipur',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildLabeledField(
                      label: 'State',
                      controller: _stateController,
                      hint: 'Chhattisgarh',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: Material(
                  color: _RasaOnboardingColors.tealContainer,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: _fetchingLocation ? null : _fetchUserLocation,
                    borderRadius: BorderRadius.circular(24),
                    splashColor: _RasaOnboardingColors.teal.withOpacity(0.08),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_fetchingLocation)
                          const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _RasaOnboardingColors.teal,
                            ),
                          )
                        else
                          const Icon(
                            Icons.my_location_rounded,
                            size: 18,
                            color: _RasaOnboardingColors.teal,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _fetchingLocation
                              ? 'Detecting your location…'
                              : 'Use my location',
                          style: const TextStyle(
                            fontFamily: 'GoogleSansFlexUI',
                            color: _RasaOnboardingColors.teal,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ----------------------------------------------------------------------
        // ENVIRONMENT
        // ----------------------------------------------------------------------
        _buildDropdownCard(
          label: 'Where are you usually wearing fragrance?',
          value: _primaryEnvironment,
          accent: _RasaOnboardingColors.lavender,
          items: const {
            'AC_OFFICE': 'AC Office / Indoor',
            'OUTDOORS': 'Outdoors · Heat & Sun',
            'ACTIVE_GYM': 'Active Gym / Workout',
          },
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _primaryEnvironment = value;
            });
          },
        ),

        const SizedBox(height: 12),

        // ----------------------------------------------------------------------
        // SWEAT
        // ----------------------------------------------------------------------
        _buildDropdownCard(
          label: 'How much do you perspire?',
          value: _sweatLevel,
          accent: _RasaOnboardingColors.peach,
          items: const {'LOW': 'Low', 'MODERATE': 'Moderate', 'HIGH': 'High'},
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _sweatLevel = value;
            });
          },
        ),

        const SizedBox(height: 12),

        // ----------------------------------------------------------------------
        // VIBE
        // ----------------------------------------------------------------------
        _buildDropdownCard(
          label: 'What energy feels most like you?',
          value: _vibePreference,
          accent: _RasaOnboardingColors.lavender,
          items: const {
            'PROFESSIONAL': 'Professional',
            'SEDUCTIVE': 'Seductive · Night Out',
            'FRESH_CASUAL': 'Fresh & Casual',
            'LOUD_ATTENTION_GRABBING': 'Loud & Bold',
          },
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _vibePreference = value;
            });
          },
        ),

        const SizedBox(height: 12),

        // ----------------------------------------------------------------------
        // BUDGET
        // ----------------------------------------------------------------------
        _buildDropdownCard(
          label: 'What range feels comfortable?',
          value: _budgetPreference,
          accent: _RasaOnboardingColors.teal,
          items: const {
            'BUDGET': 'Budget Friendly',
            'MID_RANGE': 'Mid Range',
            'DESIGNER': 'Designer',
            'NICHE': 'Niche',
            'LUXURY': 'Luxury',
          },
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _budgetPreference = value;
            });
          },
        ),
      ],
    );
  }

  // ==========================================================================
  // SECTION CARD
  // ==========================================================================

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Color accent,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _RasaOnboardingColors.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _RasaOnboardingColors.onSurface.withOpacity(0.035),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'GoogleSansFlexUI',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _RasaOnboardingColors.onSurface,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'GoogleSansFlexUI',
              color: _RasaOnboardingColors.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),

          const SizedBox(height: 16),

          child,
        ],
      ),
    );
  }

  // ==========================================================================
  // LABELED FIELD
  // ==========================================================================

  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      height: 68,
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 7),
      decoration: BoxDecoration(
        color: _RasaOnboardingColors.surfaceHigh,
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'GoogleSansFlexUI',
              color: _RasaOnboardingColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 1),
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(
                fontFamily: 'GoogleSansFlexUI',
                color: _RasaOnboardingColors.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: _RasaOnboardingColors.lavender,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
                hintStyle: const TextStyle(
                  fontFamily: 'GoogleSansFlexUI',
                  color: _RasaOnboardingColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // DROPDOWN CARD
  // ==========================================================================

  Widget _buildDropdownCard({
    required String label,
    required String value,
    required Color accent,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final String displayValue = items[value] ?? value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showChoiceSheet(
          title: label,
          selectedValue: value,
          accent: accent,
          items: items,
          onChanged: onChanged,
        ),
        borderRadius: BorderRadius.circular(26),
        splashColor: accent.withOpacity(0.06),
        highlightColor: accent.withOpacity(0.035),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutBack,
          padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
          decoration: BoxDecoration(
            color: _RasaOnboardingColors.surfaceContainer,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: accent.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 17,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'GoogleSansFlexUI',
                        color: _RasaOnboardingColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.92,
                            end: 1,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Text(
                        displayValue,
                        key: ValueKey(displayValue),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'GoogleSansFlexUI',
                          color: _RasaOnboardingColors.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _RasaOnboardingColors.surfaceHigh,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.expand_more_rounded,
                  size: 21,
                  color: _RasaOnboardingColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // STEP 2 — CONNOISSEUR PREFERENCES
  // ==========================================================================

  Widget _buildPreferencesStep() {
    if (_fetchingCatalog) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60),
        decoration: BoxDecoration(
          color: _RasaOnboardingColors.surfaceContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                strokeCap: StrokeCap.round,
                color: _RasaOnboardingColors.lavender,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Preparing your scent palette…',
              style: TextStyle(
                fontFamily: 'GoogleSansFlexUI',
                color: _RasaOnboardingColors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPreferenceIntroCard(),

        const SizedBox(height: 14),

        _buildAutocompleteSection(
          title: 'Notes you love',
          hint: 'Search notes · Vanilla, Oud…',
          controller: _likedNoteSearchController,
          query: _likedNoteQuery,
          selectedIds: _likedNoteIds,
          catalogItems: _catalogNotes,
          suggestedTerms: const [
            'Vanilla',
            'Bergamot',
            'Oud',
            'Sandalwood',
            'Rose',
          ],
          icon: Icons.favorite_outline_rounded,
          accent: _RasaOnboardingColors.lavender,
          onQueryChanged: (value) {
            setState(() {
              _likedNoteQuery = value;
            });
          },
          onSelect: (item) => _selectItem(
            item,
            _likedNoteIds,
            _dislikedNoteIds,
            _likedNoteSearchController,
            () => _likedNoteQuery = '',
          ),
          onRemove: (id) {
            setState(() {
              _likedNoteIds.remove(id);
            });
          },
        ),

        const SizedBox(height: 14),

        _buildAutocompleteSection(
          title: 'Notes you dislike',
          hint: 'Search notes to avoid…',
          controller: _dislikedNoteSearchController,
          query: _dislikedNoteQuery,
          selectedIds: _dislikedNoteIds,
          catalogItems: _catalogNotes,
          suggestedTerms: const [
            'Civet',
            'Patchouli',
            'Leather',
            'Cumin',
            'Aldehydes',
          ],
          icon: Icons.block_rounded,
          accent: _RasaOnboardingColors.peach,
          onQueryChanged: (value) {
            setState(() {
              _dislikedNoteQuery = value;
            });
          },
          onSelect: (item) => _selectItem(
            item,
            _dislikedNoteIds,
            _likedNoteIds,
            _dislikedNoteSearchController,
            () => _dislikedNoteQuery = '',
          ),
          onRemove: (id) {
            setState(() {
              _dislikedNoteIds.remove(id);
            });
          },
        ),

        const SizedBox(height: 14),

        _buildAutocompleteSection(
          title: 'Accords you love',
          hint: 'Search accords · Woody, Fresh…',
          controller: _likedAccordSearchController,
          query: _likedAccordQuery,
          selectedIds: _preferredAccordIds,
          catalogItems: _catalogAccords,
          suggestedTerms: const [
            'Woody',
            'Fresh Spicy',
            'Citrus',
            'Sweet',
            'Aromatic',
          ],
          icon: Icons.auto_awesome_rounded,
          accent: _RasaOnboardingColors.teal,
          onQueryChanged: (value) {
            setState(() {
              _likedAccordQuery = value;
            });
          },
          onSelect: (item) => _selectItem(
            item,
            _preferredAccordIds,
            _dislikedAccordIds,
            _likedAccordSearchController,
            () => _likedAccordQuery = '',
          ),
          onRemove: (id) {
            setState(() {
              _preferredAccordIds.remove(id);
            });
          },
        ),

        const SizedBox(height: 14),

        _buildAutocompleteSection(
          title: 'Accords you dislike',
          hint: 'Search accords to avoid…',
          controller: _dislikedAccordSearchController,
          query: _dislikedAccordQuery,
          selectedIds: _dislikedAccordIds,
          catalogItems: _catalogAccords,
          suggestedTerms: const [
            'Animalic',
            'Powdery',
            'Earthy',
            'Aquatic',
            'Smoky',
          ],
          icon: Icons.block_rounded,
          accent: _RasaOnboardingColors.peach,
          onQueryChanged: (value) {
            setState(() {
              _dislikedAccordQuery = value;
            });
          },
          onSelect: (item) => _selectItem(
            item,
            _dislikedAccordIds,
            _preferredAccordIds,
            _dislikedAccordSearchController,
            () => _dislikedAccordQuery = '',
          ),
          onRemove: (id) {
            setState(() {
              _dislikedAccordIds.remove(id);
            });
          },
        ),
      ],
    );
  }

  // ==========================================================================
  // PREFERENCE INTRO
  // ==========================================================================

  Widget _buildPreferenceIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _RasaOnboardingColors.lavenderContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: _RasaOnboardingColors.lavender,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: _RasaOnboardingColors.lavenderDeep,
              size: 22,
            ),
          ),

          const SizedBox(width: 13),

          const Expanded(
            child: Text(
              'Pick anything you already know about your taste. Rasa will use it as a starting point.',
              style: TextStyle(
                fontFamily: 'GoogleSansFlexUI',
                color: _RasaOnboardingColors.onSurface,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // AUTOCOMPLETE SECTION
  // ==========================================================================

  Widget _buildAutocompleteSection({
    required String title,
    required String hint,
    required TextEditingController controller,
    required String query,
    required List<String> selectedIds,
    required List<dynamic> catalogItems,
    required List<String> suggestedTerms,
    required IconData icon,
    required Color accent,
    required ValueChanged<String> onQueryChanged,
    required ValueChanged<dynamic> onSelect,
    required ValueChanged<String> onRemove,
  }) {
    final List<dynamic> searchResults = _getFilteredItems(query, catalogItems)
        .where((item) {
          final String id = item['id'].toString();

          return !selectedIds.contains(id);
        })
        .toList();

    final List<dynamic> suggestionPills = catalogItems
        .where((item) {
          final String name = (item['name'] ?? '').toString();

          final String id = item['id'].toString();

          return suggestedTerms.contains(name) && !selectedIds.contains(id);
        })
        .take(6)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _RasaOnboardingColors.surfaceContainer,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _RasaOnboardingColors.onSurface.withOpacity(0.035),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --------------------------------------------------------------
          // TITLE
          // --------------------------------------------------------------

          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'GoogleSansFlexUI',
                  color: _RasaOnboardingColors.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // --------------------------------------------------------------
          // SEARCH
          // --------------------------------------------------------------
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: _RasaOnboardingColors.surfaceHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: controller,
              onChanged: onQueryChanged,

              // ------------------------------------------------------------
              // TEXT ALIGNMENT
              // ------------------------------------------------------------
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.search,

              style: const TextStyle(
                fontFamily: 'GoogleSansFlexUI',
                color: _RasaOnboardingColors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),

              cursorColor: accent,

              decoration: InputDecoration(
                border: InputBorder.none,

                // ----------------------------------------------------------
                // HINT
                // ----------------------------------------------------------
                hintText: hint,
                hintStyle: const TextStyle(
                  fontFamily: 'GoogleSansFlexUI',
                  color: _RasaOnboardingColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),

                // ----------------------------------------------------------
                // SEARCH ICON
                // ----------------------------------------------------------
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      size: 19,
                      color: accent.withOpacity(0.85),
                    ),
                  ),
                ),

                prefixIconConstraints: const BoxConstraints(
                  minWidth: 58,
                  minHeight: 56,
                  maxHeight: 56,
                ),

                // ----------------------------------------------------------
                // CLEAR BUTTON
                // ----------------------------------------------------------
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          controller.clear();
                          onQueryChanged('');
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: _RasaOnboardingColors.muted,
                        ),
                      )
                    : null,

                // ----------------------------------------------------------
                // INTERNAL PADDING
                // ----------------------------------------------------------
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),

          // --------------------------------------------------------------
          // QUICK SUGGESTIONS
          // --------------------------------------------------------------
          if (query.isEmpty && suggestionPills.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: suggestionPills.map((item) {
                final String name = (item['name'] ?? 'Unknown').toString();

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelect(item),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 14, color: accent),
                          const SizedBox(width: 4),
                          Text(
                            name,
                            style: const TextStyle(
                              fontFamily: 'GoogleSansFlexUI',
                              color: _RasaOnboardingColors.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // --------------------------------------------------------------
          // AUTOCOMPLETE RESULTS
          // --------------------------------------------------------------
          if (query.isNotEmpty && searchResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _RasaOnboardingColors.surfaceHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: List.generate(searchResults.length, (index) {
                  final dynamic item = searchResults[index];

                  final String name = (item['name'] ?? '').toString();

                  final bool isLast = index == searchResults.length - 1;

                  return InkWell(
                    onTap: () => onSelect(item),
                    borderRadius: BorderRadius.vertical(
                      top: index == 0 ? const Radius.circular(20) : Radius.zero,
                      bottom: isLast ? const Radius.circular(20) : Radius.zero,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 15, color: accent),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontFamily: 'GoogleSansFlexUI',
                                color: _RasaOnboardingColors.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: _RasaOnboardingColors.muted,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],

          // --------------------------------------------------------------
          // SELECTED ITEMS
          // --------------------------------------------------------------
          if (selectedIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: selectedIds.map((id) {
                final dynamic item = _findItemById(id, catalogItems);

                final String name = item != null
                    ? (item['name'] ?? 'Unknown').toString()
                    : 'Unknown';

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'GoogleSansFlexUI',
                          color: _RasaOnboardingColors.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => onRemove(id),
                        child: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // SMALL HINT
  // ==========================================================================

  Widget _buildSmallHint({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: _RasaOnboardingColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'GoogleSansFlexUI',
              color: _RasaOnboardingColors.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // NAVIGATION
  // ==========================================================================

  Widget _buildNavigation() {
    final bool showBack = _currentStep > 0 || widget.onBack != null;

    final bool isLastStep =
        (_currentStep == 1 && _experienceLevel == 'NOVICE') ||
        _currentStep == 2;

    final String primaryLabel = isLastStep ? 'Complete my profile' : 'Continue';

    return Row(
      children: [
        // ----------------------------------------------------------------------
        // BACK
        // ----------------------------------------------------------------------

        if (showBack)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _loading ? null : _handlePreviousStep,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _RasaOnboardingColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 21,
                  color: _RasaOnboardingColors.onSurfaceVariant,
                ),
              ),
            ),
          ),

        if (showBack) const SizedBox(width: 10),

        // ----------------------------------------------------------------------
        // PRIMARY
        // ----------------------------------------------------------------------
        Expanded(
          child: SizedBox(
            height: 58,
            child: Material(
              color: _RasaOnboardingColors.lavender,
              borderRadius: BorderRadius.circular(29),
              child: InkWell(
                onTap: _loading ? null : _handleNextStep,
                borderRadius: BorderRadius.circular(29),
                splashColor: _RasaOnboardingColors.lavenderDeep.withOpacity(
                  0.12,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _loading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            strokeCap: StrokeCap.round,
                            color: _RasaOnboardingColors.lavenderDeep,
                          ),
                        )
                      : Row(
                          key: const ValueKey('label'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              primaryLabel,
                              style: const TextStyle(
                                fontFamily: 'GoogleSansFlexUI',
                                color: _RasaOnboardingColors.lavenderDeep,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 20,
                              color: _RasaOnboardingColors.lavenderDeep,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// AMBIENT BACKGROUND
// ============================================================================

class _OnboardingAmbientBackground extends StatelessWidget {
  const _OnboardingAmbientBackground();

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);

    return IgnorePointer(
      child: Stack(
        children: [
          // ================================================================
          // TOP RIGHT LAVENDER
          // ================================================================

          Positioned(
            top: -105,
            right: -85,
            child: _OnboardingAmbientBlob(
              width: 260,
              height: 260,
              color: _RasaOnboardingColors.lavender,
              opacity: 0.11,
              blur: 30,
              borderRadiusFactor: 0.42,
            ),
          ),

          // ================================================================
          // LEFT WARM PEACH
          // ================================================================
          Positioned(
            top: size.height * 0.18,
            left: -80,
            child: _OnboardingAmbientBlob(
              width: 155,
              height: 155,
              color: _RasaOnboardingColors.peach,
              opacity: 0.075,
              blur: 25,
              borderRadiusFactor: 0.44,
            ),
          ),

          // ================================================================
          // BOTTOM LEFT TEAL
          // ================================================================
          Positioned(
            bottom: -105,
            left: -80,
            child: _OnboardingAmbientBlob(
              width: 245,
              height: 245,
              color: _RasaOnboardingColors.teal,
              opacity: 0.095,
              blur: 29,
              borderRadiusFactor: 0.42,
            ),
          ),

          // ================================================================
          // SECONDARY PURPLE
          // ================================================================
          Positioned(
            top: size.height * 0.54,
            right: -105,
            child: _OnboardingAmbientBlob(
              width: 180,
              height: 180,
              color: _RasaOnboardingColors.lavender,
              opacity: 0.035,
              blur: 40,
              borderRadiusFactor: 0.46,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// AMBIENT BLOB
// ============================================================================

class _OnboardingAmbientBlob extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double opacity;
  final double blur;
  final double borderRadiusFactor;

  const _OnboardingAmbientBlob({
    required this.width,
    required this.height,
    required this.color,
    required this.opacity,
    required this.blur,
    this.borderRadiusFactor = 0.42,
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
          borderRadius: BorderRadius.circular(width * borderRadiusFactor),
        ),
      ),
    );
  }
}
