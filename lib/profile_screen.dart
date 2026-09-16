import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

// ============================================================================
// RASA MAIN DESIGN TOKENS (Synced with main.dart Material 3 Theme)
// ============================================================================
abstract final class _RasaColors {
  static const background = Color(0xFF141218);
  static const surfaceContainer = Color(0xFF211F26);
  static const surfaceHigh = Color(0xFF2B2930);

  static const onSurface = Color(0xFFE6E0E9);
  static const onSurfaceVariant = Color(0xFFCAC4D0);
  static const muted = Color(0xFF938F99);

  static const lavender = Color(0xFFD0BCFF);
  static const lavenderDeep = Color(0xFF381E72);

  static const teal = Color(0xFF9ADCCB);

  static const peach = Color(0xFFFFB599);

  static const error = Color(0xFFFFB4AB);
  static const errorContainer = Color(0xFF3B2020);
}

// ============================================================================
// PROFILE SCREEN
// ============================================================================

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String get _apiBaseUrl =>
      dotenv.env['EXPO_PUBLIC_API_BASE_URL'] ?? 'http://10.0.2.2:8080';

  Map<String, dynamic>? _profile;
  List<dynamic> _catalogNotes = [];
  List<dynamic> _catalogAccords = [];

  bool _loading = true;
  bool _saving = false;
  String _errorMessage = '';

  late final AnimationController _pageController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  late final Animation<double> _pageFade = CurvedAnimation(
    parent: _pageController,
    curve: Curves.easeOutCubic,
  );

  late final Animation<Offset> _pageSlide =
      Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
        CurvedAnimation(parent: _pageController, curve: Curves.easeOutCubic),
      );

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<String?> _accessToken() => _secureStorage.read(key: 'accessToken');

  Future<void> _loadProfile({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _errorMessage = '';
      });
    }

    try {
      final token = await _accessToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Your session has expired. Please sign in again.';
          _loading = false;
        });
        return;
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final responses = await Future.wait([
        http.get(Uri.parse('$_apiBaseUrl/identity/profile'), headers: headers),
        http.get(Uri.parse('$_apiBaseUrl/catalog/notes'), headers: headers),
        http.get(Uri.parse('$_apiBaseUrl/catalog/accords'), headers: headers),
      ]);

      if (!mounted) return;

      if (responses[0].statusCode != 200) {
        setState(() {
          _errorMessage = 'Could not load your profile right now.';
          _loading = false;
        });
        return;
      }

      final decodedProfile = jsonDecode(responses[0].body);
      final notes = responses[1].statusCode == 200
          ? jsonDecode(responses[1].body)
          : <dynamic>[];
      final accords = responses[2].statusCode == 200
          ? jsonDecode(responses[2].body)
          : <dynamic>[];

      setState(() {
        _profile = Map<String, dynamic>.from(decodedProfile as Map);
        _catalogNotes = notes is List ? notes : [];
        _catalogAccords = accords is List ? accords : [];
        _loading = false;
      });

      _pageController
        ..reset()
        ..forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network error connecting to your profile.';
        _loading = false;
      });
    }
  }

  String _prettyEnum(dynamic value) {
    if (value == null) return 'Not set';

    final raw = value.toString().split('.').last;
    return raw
        .toLowerCase()
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ')
        .replaceAll('Ac Office', 'AC Office')
        .replaceAll('Mid Range', 'Mid-range')
        .replaceAll('Night Out', 'Night out');
  }

  List<String> _idsFor(String key) {
    final value = _profile?[key];
    if (value is! List) return [];
    return value.map((e) => e.toString()).toList();
  }

  String _itemName(dynamic id, List<dynamic> catalog) {
    final wanted = id.toString();
    for (final item in catalog) {
      if (item is Map && item['id']?.toString() == wanted) {
        return (item['name'] ?? 'Unknown').toString();
      }
    }
    return 'Unknown';
  }

  List<String> _itemNames(String key, List<dynamic> catalog) {
    return _idsFor(key)
        .map((id) => _itemName(id, catalog))
        .where((name) => name != 'Unknown')
        .toList();
  }

  // --- API Updates ---
  Future<void> _updateLifestyle({
    required String city,
    required String state,
    required String primaryEnvironment,
    required String sweatLevel,
    required String vibePreference,
    required String budgetPreference,
  }) async {
    final token = await _accessToken();
    if (token == null) return;
    setState(() => _saving = true);

    try {
      final response = await http.patch(
        Uri.parse('$_apiBaseUrl/identity/profile/lifestyle'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'city': city.trim(),
          'state': state.trim(),
          'primaryEnvironment': primaryEnvironment,
          'sweatLevel': sweatLevel,
          'vibePreference': vibePreference,
          'budgetPreference': budgetPreference,
        }),
      );
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        setState(() => _profile = Map<String, dynamic>.from(decoded as Map));
        _showMessage('Context updated successfully.');
      } else {
        _showMessage('Could not update context.', error: true);
      }
    } catch (e) {
      if (mounted) _showMessage('Network error while saving.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updatePreferences({
    required List<String> likedNoteIds,
    required List<String> dislikedNoteIds,
    required List<String> preferredAccordIds,
    required List<String> dislikedAccordIds,
  }) async {
    final token = await _accessToken();
    if (token == null) return;
    setState(() => _saving = true);

    try {
      final response = await http.patch(
        Uri.parse('$_apiBaseUrl/identity/profile/preferences'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'likedNoteIds': likedNoteIds,
          'dislikedNoteIds': dislikedNoteIds,
          'preferredAccordIds': preferredAccordIds,
          'dislikedAccordIds': dislikedAccordIds,
        }),
      );
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        setState(() => _profile = Map<String, dynamic>.from(decoded as Map));
        _showMessage('Olfactory taste updated.');
      } else {
        _showMessage('Could not update preferences.', error: true);
      }
    } catch (e) {
      if (mounted) _showMessage('Network error while saving.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // --- Auth Actions ---
  Future<void> _logoutCurrentDevice() async {
    final refreshToken = await _secureStorage.read(key: 'refreshToken');
    if (refreshToken == null || refreshToken.isEmpty) {
      await _clearLocalSession();
      return;
    }
    setState(() => _saving = true);
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/logout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _clearLocalSession();
      } else {
        if (mounted)
          _showMessage('Could not log out. Please try again.', error: true);
      }
    } catch (e) {
      if (mounted)
        _showMessage('Network error while logging out.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logoutEverywhere() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return Dialog(
          backgroundColor: _RasaColors.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.devices_rounded,
                  color: _RasaColors.peach,
                  size: 32,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Log out everywhere?',
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlexDisplay',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _RasaColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will revoke every active Rasa session, including this device.',
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlexUI',
                    fontSize: 14,
                    color: _RasaColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'GoogleSansFlexUI',
                          color: _RasaColors.lavender,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _RasaColors.peach,
                        foregroundColor: _RasaColors.surfaceContainer,
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Log out',
                        style: TextStyle(
                          fontFamily: 'GoogleSansFlexUI',
                          fontWeight: FontWeight.w700,
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
    );

    if (confirmed != true || !mounted) return;

    final token = await _accessToken();
    if (token == null) return;
    setState(() => _saving = true);

    try {
      final response = await http.delete(
        Uri.parse('$_apiBaseUrl/auth/sessions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _clearLocalSession();
      } else {
        if (mounted)
          _showMessage('Could not revoke all sessions.', error: true);
      }
    } catch (e) {
      if (mounted)
        _showMessage('Network error while logging out.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearLocalSession() async {
    await _secureStorage.delete(key: 'accessToken');
    await _secureStorage.delete(key: 'refreshToken');
    if (!mounted) return;
    widget.onLogout();
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: error
              ? _RasaColors.errorContainer
              : _RasaColors.surfaceHigh,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              Icon(
                error
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: error ? _RasaColors.error : _RasaColors.teal,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlexUI',
                    fontWeight: FontWeight.w500,
                    color: error ? _RasaColors.error : _RasaColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ============================================================================
  // BUILD
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Material(
      color: _RasaColors.background,
      child: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              color: _RasaColors.lavenderDeep,
              backgroundColor: _RasaColors.lavender,
              onRefresh: () => _loadProfile(showLoader: false),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Row(
                        children: [
                          const Text(
                            'Profile',
                            style: TextStyle(
                              fontFamily: 'GoogleSansFlexDisplay',
                              color: _RasaColors.onSurface,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: _RasaColors.surfaceContainer,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: _RasaColors.lavender,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_loading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ProfileLoading(),
                    )
                  else if (_errorMessage.isNotEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildErrorState(),
                    )
                  else if (_profile != null)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: SlideTransition(
                          position: _pageSlide,
                          child: FadeTransition(
                            opacity: _pageFade,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildContextSummaryCard(),
                                const SizedBox(height: 16),
                                _buildPreferencesSummaryCard(),
                                const SizedBox(height: 32),
                                _buildSecuritySection(),
                                const SizedBox(
                                  height: 100,
                                ), // Bottom padding for navbar
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_saving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(
                  color: _RasaColors.lavender,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // PRODUCT SUMMARY CARDS (Eliminates Redundancy)
  // ============================================================================

  Widget _buildContextSummaryCard() {
    final experience = _prettyEnum(_profile?['experienceLevel']).toUpperCase();
    final city = (_profile?['city'] ?? '').toString();
    final state = (_profile?['state'] ?? '').toString();
    final env = _prettyEnum(_profile?['primaryEnvironment']);
    final sweat = _prettyEnum(_profile?['sweatLevel']);
    final vibe = _prettyEnum(_profile?['vibePreference']);
    final budget = _prettyEnum(_profile?['budgetPreference']);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _RasaColors.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Wear Context',
                style: TextStyle(
                  fontFamily: 'GoogleSansFlexDisplay',
                  color: _RasaColors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: _showLifestyleEditor,
                icon: const Icon(
                  Icons.edit_rounded,
                  color: _RasaColors.muted,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: _RasaColors.surfaceHigh,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: _RasaColors.lavender,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                [city, state].where((e) => e.trim().isNotEmpty).join(', '),
                style: const TextStyle(
                  fontFamily: 'GoogleSansFlexUI',
                  color: _RasaColors.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPill(experience, _RasaColors.peach),
              _buildPill(env, _RasaColors.onSurfaceVariant),
              _buildPill(vibe, _RasaColors.onSurfaceVariant),
              _buildPill(sweat, _RasaColors.onSurfaceVariant),
              _buildPill(budget, _RasaColors.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSummaryCard() {
    final likedNotes = _itemNames('likedNoteIds', _catalogNotes);
    final dislikedNotes = _itemNames('dislikedNoteIds', _catalogNotes);
    final likedAccords = _itemNames('preferredAccordIds', _catalogAccords);
    final dislikedAccords = _itemNames('dislikedAccordIds', _catalogAccords);

    final bool isEmpty =
        likedNotes.isEmpty &&
        dislikedNotes.isEmpty &&
        likedAccords.isEmpty &&
        dislikedAccords.isEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _RasaColors.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Olfactory Taste',
                style: TextStyle(
                  fontFamily: 'GoogleSansFlexDisplay',
                  color: _RasaColors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: _showPreferenceEditor,
                icon: const Icon(
                  Icons.edit_rounded,
                  color: _RasaColors.muted,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: _RasaColors.surfaceHigh,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isEmpty)
            const Text(
              'Tap edit to define the notes and accords you love and avoid.',
              style: TextStyle(
                fontFamily: 'GoogleSansFlexUI',
                color: _RasaColors.muted,
                fontSize: 14,
                height: 1.4,
              ),
            )
          else ...[
            if (likedNotes.isNotEmpty)
              _buildTasteRow(
                Icons.favorite_rounded,
                _RasaColors.error,
                'Loves',
                likedNotes,
              ),
            if (likedAccords.isNotEmpty)
              _buildTasteRow(
                Icons.auto_awesome_rounded,
                _RasaColors.lavender,
                'Prefers',
                likedAccords,
              ),
            if (dislikedNotes.isNotEmpty || dislikedAccords.isNotEmpty)
              _buildTasteRow(Icons.block_rounded, _RasaColors.peach, 'Avoids', [
                ...dislikedNotes,
                ...dislikedAccords,
              ]),
          ],
        ],
      ),
    );
  }

  Widget _buildTasteRow(
    IconData icon,
    Color color,
    String label,
    List<String> items,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'GoogleSansFlexUI',
                  fontSize: 14,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '$label  ',
                    style: const TextStyle(
                      color: _RasaColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: items.join(', '),
                    style: const TextStyle(color: _RasaColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _RasaColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'GoogleSansFlexUI',
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            'SECURITY',
            style: TextStyle(
              fontFamily: 'GoogleSansFlexUI',
              color: _RasaColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _RasaColors.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: _RasaColors.onSurfaceVariant,
                ),
                title: const Text(
                  'Log out',
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlexUI',
                    color: _RasaColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: _saving ? null : _logoutCurrentDevice,
              ),
              Divider(
                color: Colors.white.withOpacity(0.05),
                height: 1,
                indent: 60,
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                leading: const Icon(
                  Icons.devices_rounded,
                  color: _RasaColors.peach,
                ),
                title: const Text(
                  'Log out everywhere',
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlexUI',
                    color: _RasaColors.peach,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: _saving ? null : _logoutEverywhere,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: _RasaColors.muted,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Profile unavailable',
            style: TextStyle(
              fontFamily: 'GoogleSansFlexDisplay',
              color: _RasaColors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: const TextStyle(
              fontFamily: 'GoogleSansFlexUI',
              color: _RasaColors.muted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _RasaColors.surfaceHigh,
              foregroundColor: _RasaColors.onSurface,
              elevation: 0,
            ),
            onPressed: _loadProfile,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // EDITORS (Bottom Sheets)
  // ============================================================================

  Future<void> _showLifestyleEditor() async {
    final cityController = TextEditingController(
      text: (_profile?['city'] ?? '').toString(),
    );
    final stateController = TextEditingController(
      text: (_profile?['state'] ?? '').toString(),
    );
    String environment = (_profile?['primaryEnvironment'] ?? 'AC_OFFICE')
        .toString();
    String sweat = (_profile?['sweatLevel'] ?? 'MODERATE').toString();
    String vibe = (_profile?['vibePreference'] ?? 'FRESH_CASUAL').toString();
    String budget = (_profile?['budgetPreference'] ?? 'MID_RANGE').toString();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                decoration: const BoxDecoration(
                  color: _RasaColors.surfaceContainer,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _RasaColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Edit Context',
                        style: TextStyle(
                          fontFamily: 'GoogleSansFlexDisplay',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: _RasaColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField('City', cityController),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField('State', stateController),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownRow('Environment', environment, const {
                        'AC_OFFICE': 'AC Office',
                        'OUTDOORS': 'Outdoors',
                        'ACTIVE_GYM': 'Gym',
                      }, (v) => setSheetState(() => environment = v!)),
                      const SizedBox(height: 12),
                      _buildDropdownRow('Perspiration', sweat, const {
                        'LOW': 'Low',
                        'MODERATE': 'Moderate',
                        'HIGH': 'High',
                      }, (v) => setSheetState(() => sweat = v!)),
                      const SizedBox(height: 12),
                      _buildDropdownRow('Vibe', vibe, const {
                        'PROFESSIONAL': 'Professional',
                        'SEDUCTIVE': 'Night Out',
                        'FRESH_CASUAL': 'Fresh/Casual',
                        'LOUD_ATTENTION_GRABBING': 'Loud/Bold',
                      }, (v) => setSheetState(() => vibe = v!)),
                      const SizedBox(height: 12),
                      _buildDropdownRow('Budget', budget, const {
                        'BUDGET': 'Budget',
                        'MID_RANGE': 'Mid Range',
                        'DESIGNER': 'Designer',
                        'NICHE': 'Niche',
                        'LUXURY': 'Luxury',
                      }, (v) => setSheetState(() => budget = v!)),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _RasaColors.lavender,
                            foregroundColor: _RasaColors.lavenderDeep,
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _updateLifestyle(
                              city: cityController.text,
                              state: stateController.text,
                              primaryEnvironment: environment,
                              sweatLevel: sweat,
                              vibePreference: vibe,
                              budgetPreference: budget,
                            );
                          },
                          child: const Text(
                            'Save Context',
                            style: TextStyle(
                              fontFamily: 'GoogleSansFlexUI',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showPreferenceEditor() async {
    final result = await showModalBottomSheet<_PreferenceResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PreferenceEditorSheet(
        notes: _catalogNotes,
        accords: _catalogAccords,
        likedNotes: _idsFor('likedNoteIds'),
        dislikedNotes: _idsFor('dislikedNoteIds'),
        likedAccords: _idsFor('preferredAccordIds'),
        dislikedAccords: _idsFor('dislikedAccordIds'),
      ),
    );

    if (result != null) {
      await _updatePreferences(
        likedNoteIds: result.likedNotes,
        dislikedNoteIds: result.dislikedNotes,
        preferredAccordIds: result.likedAccords,
        dislikedAccordIds: result.dislikedAccords,
      );
    }
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        fontFamily: 'GoogleSansFlexUI',
        color: _RasaColors.onSurface,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _RasaColors.muted, fontSize: 13),
        filled: true,
        fillColor: _RasaColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildDropdownRow(
    String label,
    String value,
    Map<String, String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _RasaColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: _RasaColors.surfaceHigh,
          icon: const Icon(Icons.expand_more_rounded, color: _RasaColors.muted),
          items: items.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(
                    e.value,
                    style: const TextStyle(
                      fontFamily: 'GoogleSansFlexUI',
                      color: _RasaColors.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: _RasaColors.lavender),
    );
  }
}

// ============================================================================
// PREFERENCES EDITOR SHEET
// ============================================================================
class _PreferenceResult {
  final List<String> likedNotes;
  final List<String> dislikedNotes;
  final List<String> likedAccords;
  final List<String> dislikedAccords;
  const _PreferenceResult({
    required this.likedNotes,
    required this.dislikedNotes,
    required this.likedAccords,
    required this.dislikedAccords,
  });
}

class _PreferenceEditorSheet extends StatefulWidget {
  final List<dynamic> notes;
  final List<dynamic> accords;
  final List<String> likedNotes;
  final List<String> dislikedNotes;
  final List<String> likedAccords;
  final List<String> dislikedAccords;

  const _PreferenceEditorSheet({
    required this.notes,
    required this.accords,
    required this.likedNotes,
    required this.dislikedNotes,
    required this.likedAccords,
    required this.dislikedAccords,
  });

  @override
  State<_PreferenceEditorSheet> createState() => _PreferenceEditorSheetState();
}

class _PreferenceEditorSheetState extends State<_PreferenceEditorSheet> {
  late List<String> likedNotes = [...widget.likedNotes];
  late List<String> dislikedNotes = [...widget.dislikedNotes];
  late List<String> likedAccords = [...widget.likedAccords];
  late List<String> dislikedAccords = [...widget.dislikedAccords];

  String _queryNotesLove = '';
  String _queryNotesAvoid = '';
  String _queryAccordsLove = '';
  String _queryAccordsAvoid = '';

  final _nLoveCtrl = TextEditingController();
  final _nAvoidCtrl = TextEditingController();
  final _aLoveCtrl = TextEditingController();
  final _aAvoidCtrl = TextEditingController();

  String _name(dynamic item) => (item['name'] ?? 'Unknown').toString();
  String _id(dynamic item) => item['id'].toString();

  List<dynamic> _results(
    List<dynamic> items,
    String query,
    List<String> selected,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return items
        .whereType<Map>()
        .where(
          (item) =>
              _name(item).toLowerCase().contains(q) &&
              !selected.contains(_id(item)),
        )
        .take(5)
        .toList();
  }

  void _toggle(List<String> target, List<String> opposite, dynamic item) {
    final id = _id(item);
    setState(() {
      if (!target.contains(id)) target.add(id);
      opposite.remove(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.9,
        decoration: const BoxDecoration(
          color: _RasaColors.surfaceContainer,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _RasaColors.surfaceHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Olfactory Taste',
                    style: TextStyle(
                      fontFamily: 'GoogleSansFlexDisplay',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _RasaColors.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: _RasaColors.muted,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildSearchGroup(
                    'Notes you love',
                    'Search vanilla, oud...',
                    _nLoveCtrl,
                    _queryNotesLove,
                    (v) => setState(() => _queryNotesLove = v),
                    widget.notes,
                    likedNotes,
                    dislikedNotes,
                    _RasaColors.lavender,
                    Icons.favorite_border_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildSearchGroup(
                    'Notes you avoid',
                    'Search civet...',
                    _nAvoidCtrl,
                    _queryNotesAvoid,
                    (v) => setState(() => _queryNotesAvoid = v),
                    widget.notes,
                    dislikedNotes,
                    likedNotes,
                    _RasaColors.peach,
                    Icons.block_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildSearchGroup(
                    'Accords you love',
                    'Search woody, fresh...',
                    _aLoveCtrl,
                    _queryAccordsLove,
                    (v) => setState(() => _queryAccordsLove = v),
                    widget.accords,
                    likedAccords,
                    dislikedAccords,
                    _RasaColors.teal,
                    Icons.auto_awesome_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildSearchGroup(
                    'Accords you avoid',
                    'Search animalic...',
                    _aAvoidCtrl,
                    _queryAccordsAvoid,
                    (v) => setState(() => _queryAccordsAvoid = v),
                    widget.accords,
                    dislikedAccords,
                    likedAccords,
                    _RasaColors.peach,
                    Icons.block_rounded,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _RasaColors.lavender,
                        foregroundColor: _RasaColors.lavenderDeep,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      onPressed: () => Navigator.pop(
                        context,
                        _PreferenceResult(
                          likedNotes: likedNotes,
                          dislikedNotes: dislikedNotes,
                          likedAccords: likedAccords,
                          dislikedAccords: dislikedAccords,
                        ),
                      ),
                      child: const Text(
                        'Save Taste',
                        style: TextStyle(
                          fontFamily: 'GoogleSansFlexUI',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchGroup(
    String title,
    String hint,
    TextEditingController ctrl,
    String query,
    ValueChanged<String> onQuery,
    List<dynamic> catalog,
    List<String> selected,
    List<String> opposite,
    Color accent,
    IconData icon,
  ) {
    final results = _results(catalog, query, selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'GoogleSansFlexUI',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _RasaColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          onChanged: onQuery,
          style: const TextStyle(color: _RasaColors.onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _RasaColors.muted),
            filled: true,
            fillColor: _RasaColors.surfaceHigh,
            prefixIcon: Icon(icon, color: accent, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        if (results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: _RasaColors.surfaceHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: results
                    .map(
                      (item) => ListTile(
                        title: Text(
                          _name(item),
                          style: const TextStyle(
                            fontSize: 13,
                            color: _RasaColors.onSurface,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.add_rounded,
                          color: _RasaColors.muted,
                          size: 18,
                        ),
                        onTap: () {
                          _toggle(selected, opposite, item);
                          ctrl.clear();
                          onQuery('');
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        if (selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: selected.map((id) {
                final name = catalog.firstWhere(
                  (e) => e is Map && _id(e) == id,
                  orElse: () => {'name': 'Unknown'},
                )['name'];
                return Chip(
                  label: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _RasaColors.onSurface,
                    ),
                  ),
                  backgroundColor: _RasaColors.surfaceHigh,
                  deleteIcon: const Icon(Icons.close_rounded, size: 14),
                  onDeleted: () => setState(() => selected.remove(id)),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
