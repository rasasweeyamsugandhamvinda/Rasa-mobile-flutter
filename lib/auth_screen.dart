import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ============================================================================
// RASA AUTH COLORS
// ============================================================================

abstract final class _RasaAuthColors {
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

  // --------------------------------------------------------------------------
  // Semantic
  // --------------------------------------------------------------------------

  static const teal = Color(0xFF9ADCCB);
  static const peach = Color(0xFFFFB599);

  // --------------------------------------------------------------------------
  // Error / Success
  // --------------------------------------------------------------------------

  static const error = Color(0xFFFFB4AB);
  static const errorContainer = Color(0xFF3B2020);

  static const success = Color(0xFF9CDBC7);
  static const successContainer = Color(0xFF17322F);
}

// ============================================================================
// AUTH SCREEN
// ============================================================================

class AuthScreen extends StatefulWidget {
  final VoidCallback onClose;
  final Function(Map<String, dynamic>) onSuccess;
  final bool initialIsLogin;

  const AuthScreen({
    super.key,
    required this.onClose,
    required this.onSuccess,
    this.initialIsLogin = true,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

// ============================================================================
// AUTH STATE
// ============================================================================

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late bool _isLogin;

  // Signup flow:
  // 'email'  -> email entry
  // 'verify' -> OTP + password
  String _signupStep = 'email';

  bool _loading = false;
  bool _passwordVisible = false;

  String _errorMessage = '';
  String _successMessage = '';

  // --------------------------------------------------------------------------
  // Controllers
  // --------------------------------------------------------------------------

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _otpController = TextEditingController();

  final _secureStorage = const FlutterSecureStorage();

  // --------------------------------------------------------------------------
  // API
  // --------------------------------------------------------------------------

  String get _apiBaseUrl =>
      dotenv.env['EXPO_PUBLIC_API_BASE_URL'] ?? 'http://10.0.2.2:8080';

  // --------------------------------------------------------------------------
  // Toggle animation
  // --------------------------------------------------------------------------

  late AnimationController _modeToggleController;

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _isLogin = widget.initialIsLogin;

    _modeToggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
      value: _isLogin ? 0.0 : 1.0,
    );
  }

  @override
  void dispose() {
    _modeToggleController.dispose();

    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // MODE SWITCHING
  // ==========================================================================

  void _switchMode(bool login) {
    if (_loading) return;
    if (login == _isLogin) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLogin = login;
      _signupStep = 'email';
      _errorMessage = '';
      _successMessage = '';
      _passwordVisible = false;
    });

    _modeToggleController.animateTo(
      login ? 0.0 : 1.0,
      curve: Curves.easeOutBack,
    );
  }

  // ==========================================================================
  // SECURE TOKEN STORAGE
  // ==========================================================================

  Future<void> _saveTokensAndProceed(Map<String, dynamic> tokens) async {
    try {
      await _secureStorage.write(
        key: 'accessToken',
        value: tokens['accessToken'],
      );

      await _secureStorage.write(
        key: 'refreshToken',
        value: tokens['refreshToken'],
      );

      debugPrint('Tokens securely stored on device!');

      widget.onSuccess(tokens);
    } catch (error) {
      debugPrint('Error saving tokens securely: $error');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to securely save login session.';
      });
    }
  }

  // ==========================================================================
  // GOOGLE SIGN-IN
  // ==========================================================================

  Future<void> _handleGoogleSignIn() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: dotenv.env['EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID'],
      );

      final GoogleSignInAccount? account = await GoogleSignIn.instance
          .authenticate();

      if (account == null) {
        if (!mounted) return;

        setState(() {
          _errorMessage = 'Google authentication cancelled.';
          _loading = false;
        });

        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      final String? idToken = auth.idToken;

      if (idToken != null) {
        await _handleOAuthBackendVerification(idToken);
      } else {
        if (!mounted) return;

        setState(() {
          _errorMessage = 'Failed to retrieve Google ID token.';
        });
      }
    } catch (error) {
      debugPrint('Google Sign-In Error: $error');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Google authentication failed.';
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
  // GOOGLE BACKEND VERIFICATION
  // ==========================================================================

  Future<void> _handleOAuthBackendVerification(String idToken) async {
    try {
      debugPrint('Sending Google ID Token to backend...');

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/oauth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        await _saveTokensAndProceed(data['data']);
      } else {
        if (!mounted) return;

        setState(() {
          _errorMessage =
              data['message'] ?? 'OAuth verification failed on server.';
        });
      }
    } catch (err) {
      debugPrint('OAuth Backend Error: $err');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Network error connecting to backend.';
      });
    }
  }

  // ==========================================================================
  // LOGIN
  // ==========================================================================

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Email and password are required.';
      });

      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      debugPrint(
        'Sending login request to: '
        '$_apiBaseUrl/auth/login',
      );

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        await _saveTokensAndProceed(data['data']);
      } else {
        if (!mounted) return;

        setState(() {
          _errorMessage = data['message'] ?? 'Login failed.';
        });
      }
    } catch (err) {
      debugPrint('Login Fetch Error: $err');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Network error. Check connection to backend.';
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
  // INITIATE SIGNUP
  // ==========================================================================

  Future<void> _handleInitiateSignup() async {
    FocusScope.of(context).unfocus();

    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Email is required.';
      });

      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      debugPrint(
        'Sending signup request to: '
        '$_apiBaseUrl/auth/initiate',
      );

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/initiate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim()}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        if (!mounted) return;

        setState(() {
          _successMessage = 'OTP sent to your email.';
          _signupStep = 'verify';
        });
      } else {
        if (!mounted) return;

        setState(() {
          _errorMessage = data['message'] ?? 'Failed to initiate signup.';
        });
      }
    } catch (err) {
      debugPrint('Initiate Signup Error: $err');

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
  // VERIFY OTP
  // ==========================================================================

  Future<void> _handleVerifyOtp() async {
    FocusScope.of(context).unfocus();

    if (_otpController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'OTP and password are required.';
      });

      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      debugPrint(
        'Sending OTP verify to: '
        '$_apiBaseUrl/auth/verify-otp',
      );

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'otp': _otpController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        if (data['data'] != null && data['data']['accessToken'] != null) {
          await _saveTokensAndProceed(data['data']);
        } else {
          if (!mounted) return;

          setState(() {
            _successMessage =
                data['message'] ?? 'Account created! Please log in.';

            _isLogin = true;
            _signupStep = 'email';

            _passwordController.clear();
            _otpController.clear();

            _modeToggleController.animateTo(0.0, curve: Curves.easeOutBack);
          });
        }
      } else {
        if (!mounted) return;

        setState(() {
          _errorMessage = data['message'] ?? 'OTP verification failed.';
        });
      }
    } catch (err) {
      debugPrint('Verify OTP Error: $err');

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
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Positioned.fill(
      child: Material(
        color: _RasaAuthColors.background,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              // ================================================================
              // AMBIENT BACKGROUND
              // ================================================================

              const _AuthAmbientBackground(),

              // ================================================================
              // KEYBOARD-AWARE CONTENT
              // ================================================================
              AnimatedPadding(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: SafeArea(
                  child: Column(
                    children: [
                      // --------------------------------------------------------
                      // TOP BAR
                      // --------------------------------------------------------

                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'RASA',
                              style: TextStyle(
                                fontFamily: 'GoogleSansFlexHero',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3.5,
                                color: _RasaAuthColors.onSurface,
                              ),
                            ),
                            _buildCloseButton(),
                          ],
                        ),
                      ),

                      // --------------------------------------------------------
                      // SCROLLABLE CONTENT
                      // --------------------------------------------------------
                      Expanded(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                _buildHeader(),

                                const SizedBox(height: 30),

                                // Mode switcher
                                _buildModeSwitcher(),

                                const SizedBox(height: 24),

                                // Error
                                if (_errorMessage.isNotEmpty)
                                  _buildMessageBanner(
                                    message: _errorMessage,
                                    isError: true,
                                  ),

                                // Success
                                if (_successMessage.isNotEmpty)
                                  _buildMessageBanner(
                                    message: _successMessage,
                                    isError: false,
                                  ),

                                // Form
                                _buildForm(),

                                const SizedBox(height: 24),

                                // OR divider
                                _buildOrDivider(),

                                const SizedBox(height: 18),

                                // Google
                                _buildGoogleButton(),

                                const SizedBox(height: 28),

                                // Footer
                                _buildFooter(),

                                // Extra keyboard breathing room.
                                //
                                // This is intentionally inside the scroll
                                // view so the final controls can move above
                                // the keyboard.
                                SizedBox(height: keyboardInset > 0 ? 32 : 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // CLOSE BUTTON
  // ==========================================================================

  Widget _buildCloseButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _loading ? null : widget.onClose,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: _RasaAuthColors.surfaceContainer,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 21,
            color: _RasaAuthColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader() {
    final bool isVerification = !_isLogin && _signupStep == 'verify';

    final String mainText;
    final String accentWord;

    if (isVerification) {
      mainText = 'One last\n';
      accentWord = 'step.';
    } else if (_isLogin) {
      mainText = 'Welcome\n';
      accentWord = 'back.';
    } else {
      mainText = 'Make Rasa\n';
      accentWord = 'yours.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --------------------------------------------------------------------
        // EYEBROW
        // --------------------------------------------------------------------

        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _RasaAuthColors.lavender,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isVerification
                  ? 'ALMOST THERE'
                  : _isLogin
                  ? 'WELCOME BACK'
                  : 'JOIN RASA',
              style: const TextStyle(
                fontFamily: 'GoogleSansFlexUI',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.8,
                color: _RasaAuthColors.muted,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // --------------------------------------------------------------------
        // EXPRESSIVE HEADING
        // --------------------------------------------------------------------
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: mainText,
                style: const TextStyle(
                  fontFamily: 'GoogleSansFlexDisplay',
                  fontSize: 42,
                  height: 0.98,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.6,
                  color: _RasaAuthColors.onSurface,
                ),
              ),
              TextSpan(
                text: accentWord,
                style: const TextStyle(
                  fontFamily: 'GoogleSansFlexDisplay',
                  fontSize: 42,
                  height: 0.98,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.6,
                  color: _RasaAuthColors.lavender,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // --------------------------------------------------------------------
        // SUPPORTING COPY
        // --------------------------------------------------------------------
        Text(
          isVerification
              ? 'We sent a verification code to your email. Create your password to continue.'
              : _isLogin
              ? 'Access your saved olfactory profile and discover what suits you next.'
              : 'Create your olfactory identity and let Rasa learn what feels like you.',
          style: const TextStyle(
            fontFamily: 'GoogleSansFlexUI',
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w400,
            color: _RasaAuthColors.muted,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // PIXEL-STYLE MODE SWITCHER
  // ==========================================================================

  Widget _buildModeSwitcher() {
    return AnimatedBuilder(
      animation: _modeToggleController,
      builder: (context, child) {
        final double t = Curves.easeOutCubic.transform(
          _modeToggleController.value,
        );

        return Container(
          height: 62,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _RasaAuthColors.surfaceContainer,
            borderRadius: BorderRadius.circular(32),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double halfWidth = constraints.maxWidth / 2;

              // Slide between left and right.
              final double left = t * halfWidth;

              // Small bubble effect during
              // the movement.
              final double distance = (t - 0.5).abs() * 2;

              final double verticalScale = 0.96 + (1 - distance) * 0.04;

              final double horizontalScale = 0.97 + (1 - distance) * 0.03;

              return Stack(
                children: [
                  // ----------------------------------------------------------
                  // MOVING LAVENDER PILL
                  // ----------------------------------------------------------

                  Positioned(
                    left: left,
                    top: 0,
                    width: halfWidth,
                    bottom: 0,
                    child: Center(
                      child: Transform.scale(
                        scaleX: horizontalScale,
                        scaleY: verticalScale,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _RasaAuthColors.lavender,
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ----------------------------------------------------------
                  // LABELS
                  // ----------------------------------------------------------
                  Row(
                    children: [
                      _buildModeLabel(label: 'Sign In', selected: _isLogin),
                      _buildModeLabel(label: 'Sign Up', selected: !_isLogin),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildModeLabel({required String label, required bool selected}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading ? null : () => _switchMode(label == 'Sign In'),
          borderRadius: BorderRadius.circular(28),
          splashColor: _RasaAuthColors.lavenderDeep.withOpacity(0.08),
          highlightColor: _RasaAuthColors.lavenderDeep.withOpacity(0.04),
          child: SizedBox(
            height: 52,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontFamily: 'GoogleSansFlexUI',
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? _RasaAuthColors.lavenderDeep
                      : _RasaAuthColors.muted,
                ),
                child: Text(label),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // MESSAGE BANNER
  // ==========================================================================

  Widget _buildMessageBanner({required String message, required bool isError}) {
    final Color foreground = isError
        ? _RasaAuthColors.error
        : _RasaAuthColors.success;

    final Color background = isError
        ? _RasaAuthColors.errorContainer
        : _RasaAuthColors.successContainer;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 19,
            color: foreground,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'GoogleSansFlexUI',
                color: foreground,
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
  // FORM
  // ==========================================================================

  Widget _buildForm() {
    final bool isVerification = !_isLogin && _signupStep == 'verify';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --------------------------------------------------------------------
        // EMAIL
        // --------------------------------------------------------------------

        if (_isLogin || _signupStep == 'email')
          _buildRasaTextField(
            controller: _emailController,
            label: 'Email address',
            hint: 'you@example.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),

        if (_isLogin || _signupStep == 'email') const SizedBox(height: 12),

        // --------------------------------------------------------------------
        // OTP
        // --------------------------------------------------------------------
        if (isVerification)
          _buildRasaTextField(
            controller: _otpController,
            label: 'Verification code',
            hint: '6-digit OTP',
            icon: Icons.mark_email_read_outlined,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textInputAction: TextInputAction.next,
          ),

        if (isVerification) const SizedBox(height: 12),

        // --------------------------------------------------------------------
        // PASSWORD
        // --------------------------------------------------------------------
        if (_isLogin || isVerification)
          _buildRasaTextField(
            controller: _passwordController,
            label: _isLogin ? 'Password' : 'Create password',
            hint: _isLogin ? 'Your password' : 'At least 8 characters',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (_isLogin) {
                _handleLogin();
              } else if (_signupStep == 'email') {
                _handleInitiateSignup();
              } else {
                _handleVerifyOtp();
              }
            },
          ),

        const SizedBox(height: 18),

        _buildPrimaryButton(),
      ],
    );
  }

  // ==========================================================================
  // TEXT FIELD
  // ==========================================================================

  Widget _buildRasaTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      decoration: BoxDecoration(
        color: _RasaAuthColors.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _RasaAuthColors.onSurface.withOpacity(0.045),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 9, 10, 9),
      child: Row(
        children: [
          // ----------------------------------------------------------
          // ICON
          // ----------------------------------------------------------

          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: _RasaAuthColors.surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 19,
              color: _RasaAuthColors.onSurfaceVariant,
            ),
          ),

          const SizedBox(width: 12),

          // ----------------------------------------------------------
          // INPUT
          // ----------------------------------------------------------
          Expanded(
            child: TextField(
              controller: controller,

              // ------------------------------------------------------
              // KEYBOARD FIX
              //
              // Gives Flutter extra room to bring the focused field
              // above the Android keyboard.
              // ------------------------------------------------------
              scrollPadding: const EdgeInsets.only(top: 120, bottom: 140),

              obscureText: isPassword && !_passwordVisible,

              keyboardType: keyboardType,

              maxLength: maxLength,

              textInputAction: textInputAction,

              onSubmitted: onSubmitted,

              style: const TextStyle(
                fontFamily: 'GoogleSansFlexUI',
                color: _RasaAuthColors.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),

              cursorColor: _RasaAuthColors.lavender,

              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                labelText: label,
                hintText: hint,
                labelStyle: const TextStyle(
                  fontFamily: 'GoogleSansFlexUI',
                  color: _RasaAuthColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintStyle: const TextStyle(
                  fontFamily: 'GoogleSansFlexUI',
                  color: _RasaAuthColors.muted,
                  fontSize: 15,
                ),
                counterText: '',
              ),
            ),
          ),

          // ----------------------------------------------------------
          // PASSWORD VISIBILITY
          // ----------------------------------------------------------
          if (isPassword)
            IconButton(
              onPressed: () {
                setState(() {
                  _passwordVisible = !_passwordVisible;
                });
              },
              splashRadius: 22,
              icon: Icon(
                _passwordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: _RasaAuthColors.muted,
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PRIMARY BUTTON
  // ==========================================================================

  Widget _buildPrimaryButton() {
    final String label;

    if (_isLogin) {
      label = 'Sign in';
    } else if (_signupStep == 'email') {
      label = 'Continue with email';
    } else {
      label = 'Verify & activate';
    }

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: Material(
        color: _RasaAuthColors.lavender,
        borderRadius: BorderRadius.circular(29),
        child: InkWell(
          onTap: _loading
              ? null
              : () {
                  if (_isLogin) {
                    _handleLogin();
                  } else if (_signupStep == 'email') {
                    _handleInitiateSignup();
                  } else {
                    _handleVerifyOtp();
                  }
                },
          borderRadius: BorderRadius.circular(29),
          splashColor: _RasaAuthColors.lavenderDeep.withOpacity(0.12),
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
                      color: _RasaAuthColors.lavenderDeep,
                    ),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'GoogleSansFlexUI',
                          color: _RasaAuthColors.lavenderDeep,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: _RasaAuthColors.lavenderDeep,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // OR DIVIDER
  // ==========================================================================

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: _RasaAuthColors.onSurface.withOpacity(0.055),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: const TextStyle(
              fontFamily: 'GoogleSansFlexUI',
              color: _RasaAuthColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: _RasaAuthColors.onSurface.withOpacity(0.055),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // GOOGLE BUTTON
  // ==========================================================================

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: Material(
        color: _RasaAuthColors.surfaceContainer,
        borderRadius: BorderRadius.circular(29),
        child: InkWell(
          onTap: _loading ? null : _handleGoogleSignIn,
          borderRadius: BorderRadius.circular(29),
          splashColor: _RasaAuthColors.onSurface.withOpacity(0.04),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE6E0E9),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'G',
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlexUI',
                    color: Color(0xFF141218),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              const Text(
                'Continue with Google',
                style: TextStyle(
                  fontFamily: 'GoogleSansFlexUI',
                  color: _RasaAuthColors.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // FOOTER
  // ==========================================================================

  Widget _buildFooter() {
    final bool isVerification = !_isLogin && _signupStep == 'verify';

    return Column(
      children: [
        if (isVerification)
          Center(
            child: TextButton.icon(
              onPressed: _loading
                  ? null
                  : () {
                      setState(() {
                        _signupStep = 'email';
                        _otpController.clear();
                        _errorMessage = '';
                        _successMessage = '';
                      });
                    },
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: const Text('Use a different email'),
              style: TextButton.styleFrom(
                foregroundColor: _RasaAuthColors.onSurfaceVariant,
                textStyle: const TextStyle(
                  fontFamily: 'GoogleSansFlexUI',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
        else
          const Center(
            child: Text(
              'Your fragrance profile stays yours.',
              style: TextStyle(
                fontFamily: 'GoogleSansFlexUI',
                color: _RasaAuthColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// AUTH AMBIENT BACKGROUND
// ============================================================================

class _AuthAmbientBackground extends StatelessWidget {
  const _AuthAmbientBackground();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          // ================================================================
          // TOP RIGHT LAVENDER
          // ================================================================

          Positioned(
            top: -105,
            right: -90,
            child: _AuthAmbientBlob(
              width: 260,
              height: 260,
              color: _RasaAuthColors.lavender,
              opacity: 0.115,
              blur: 30,
              borderRadiusFactor: 0.42,
            ),
          ),

          // ================================================================
          // LEFT WARM PEACH
          // ================================================================
          Positioned(
            top: 145,
            left: -78,
            child: _AuthAmbientBlob(
              width: 155,
              height: 155,
              color: _RasaAuthColors.peach,
              opacity: 0.085,
              blur: 24,
              borderRadiusFactor: 0.44,
            ),
          ),

          // ================================================================
          // BOTTOM LEFT TEAL
          // ================================================================
          Positioned(
            bottom: -95,
            left: -75,
            child: _AuthAmbientBlob(
              width: 240,
              height: 240,
              color: _RasaAuthColors.teal,
              opacity: 0.105,
              blur: 28,
              borderRadiusFactor: 0.42,
            ),
          ),

          // ================================================================
          // SECONDARY LAVENDER
          // ================================================================
          Positioned(
            top: 430,
            right: -95,
            child: _AuthAmbientBlob(
              width: 175,
              height: 175,
              color: _RasaAuthColors.lavender,
              opacity: 0.045,
              blur: 38,
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

class _AuthAmbientBlob extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double opacity;
  final double blur;
  final double borderRadiusFactor;

  const _AuthAmbientBlob({
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
