import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/app_social_button.dart';
import '../providers/auth_provider.dart';

/// Pantalla de autenticación rediseñada con Glassmorphism y formas geométricas asimétricas.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  // 0 para Login, 1 para Registro
  int _currentIndex = 0;

  // Controladores para login
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Controladores para registro
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmPasswordController = TextEditingController();

  // Estado de errores
  String? _loginEmailError;
  String? _loginPasswordError;
  String? _signupEmailError;
  String? _signupPasswordError;
  String? _signupConfirmPasswordError;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canUseBiometrics = ref.watch(canUseBiometricsProvider);
    final isLoading = ref.watch(authLoadingProvider);

    ref.listen<AsyncValue<dynamic>>(authNotifierProvider, (previous, next) {
      next.when(
        data: (user) {
          if (user != null) {
            context.go('/');
          }
        },
        loading: () {},
        error: (error, stack) {
          _showErrorSnackBar(error.toString());
        },
      );
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F12) : AppColors.backgroundColor,
      body: SafeArea(
        child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo Geométrico
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                            topRight: Radius.circular(10),
                            bottomLeft: Radius.circular(10),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Finanzas Personal',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gestiona tu dinero de forma inteligente',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Switcher de Pestañas (Pill Switch)
                    _buildPillSwitch(isDark),
                    const SizedBox(height: 32),

                    // Formulario sin card — directo sobre el fondo
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _currentIndex == 0
                            ? _buildLoginForm(isDark, canUseBiometrics, isLoading)
                            : _buildSignupForm(isDark, isLoading),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildPillSwitch(bool isDark) {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
        borderRadius: BorderRadius.circular(40),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            alignment: _currentIndex == 0 ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchTab(0),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      'Ingresar',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: _currentIndex == 0 ? FontWeight.w700 : FontWeight.w600,
                        color: _currentIndex == 0
                            ? (isDark ? Colors.white : AppColors.primary)
                            : (isDark ? Colors.white54 : Colors.grey[500]),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchTab(1),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      'Registro',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: _currentIndex == 1 ? FontWeight.w700 : FontWeight.w600,
                        color: _currentIndex == 1
                            ? (isDark ? Colors.white : AppColors.primary)
                            : (isDark ? Colors.white54 : Colors.grey[500]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(bool isDark, AsyncValue<bool> canUseBiometrics, bool isLoading) {
    return Column(
      key: const ValueKey('login_form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!kIsWeb)
          AppSocialButton(
            label: 'Continuar con Google',
            provider: 'google',
            onPressed: isLoading ? null : _handleGoogleSignIn,
          ),
        if (!kIsWeb) const SizedBox(height: 12),
        if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS))
          AppSocialButton(
            label: 'Continuar con Apple',
            provider: 'apple',
            onPressed: isLoading ? null : _handleAppleSignIn,
          ),
        if (!kIsWeb) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey[300])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'O CON EMAIL',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.grey[500],
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey[300])),
            ],
          ),
          const SizedBox(height: 24),
        ],

        AppTextField(
          label: 'Correo electrónico',
          controller: _loginEmailController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.alternate_email_rounded,
          helperText: _loginEmailError,
          isError: _loginEmailError != null,
          enabled: !isLoading,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Contraseña',
          controller: _loginPasswordController,
          isPassword: true,
          prefixIcon: Icons.lock_outline_rounded,
          helperText: _loginPasswordError,
          isError: _loginPasswordError != null,
          enabled: !isLoading,
        ),
        const SizedBox(height: 12),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: isLoading ? null : _handleForgotPassword,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '¿Olvidaste tu contraseña?',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        AppButton(
          label: 'Iniciar sesión',
          onPressed: isLoading ? null : _handleEmailLogin,
          isFullWidth: true,
          isLoading: isLoading,
          height: 48,
        ),
        const SizedBox(height: 16),

        canUseBiometrics.when(
          data: (canUse) {
            if (!canUse) return const SizedBox.shrink();
            final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
            return AppButton(
              label: isIOS ? 'Usar Face ID' : 'Usar Touch ID',
              icon: isIOS ? Icons.face_rounded : Icons.fingerprint_rounded,
              onPressed: isLoading ? null : _handleBiometricLogin,
              variant: 'outlined',
              isFullWidth: true,
              height: 48,
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSignupForm(bool isDark, bool isLoading) {
    return Column(
      key: const ValueKey('signup_form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!kIsWeb)
          AppSocialButton(
            label: 'Registrarse con Google',
            provider: 'google',
            onPressed: isLoading ? null : _handleGoogleSignIn,
          ),
        if (!kIsWeb) const SizedBox(height: 12),
        if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS))
          AppSocialButton(
            label: 'Registrarse con Apple',
            provider: 'apple',
            onPressed: isLoading ? null : _handleAppleSignIn,
          ),
        if (!kIsWeb) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey[300])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'O CON EMAIL',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.grey[500],
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey[300])),
            ],
          ),
          const SizedBox(height: 24),
        ],

        AppTextField(
          label: 'Correo electrónico',
          controller: _signupEmailController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.alternate_email_rounded,
          helperText: _signupEmailError,
          isError: _signupEmailError != null,
          enabled: !isLoading,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Contraseña',
          controller: _signupPasswordController,
          isPassword: true,
          prefixIcon: Icons.lock_outline_rounded,
          helperText: _signupPasswordError,
          isError: _signupPasswordError != null,
          enabled: !isLoading,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Confirmar contraseña',
          controller: _signupConfirmPasswordController,
          isPassword: true,
          prefixIcon: Icons.lock_clock_rounded,
          helperText: _signupConfirmPasswordError,
          isError: _signupConfirmPasswordError != null,
          enabled: !isLoading,
        ),
        const SizedBox(height: 32),

        AppButton(
          label: 'Crear cuenta',
          onPressed: isLoading ? null : _handleEmailSignup,
          isFullWidth: true,
          isLoading: isLoading,
          height: 48,
        ),
      ],
    );
  }

  // ==================== HANDLERS ====================

  Future<void> _handleEmailLogin() async {
    setState(() {
      _loginEmailError = null;
      _loginPasswordError = null;
    });

    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text.trim();

    bool hasError = false;
    if (email.isEmpty) {
      setState(() => _loginEmailError = 'Ingresa tu email');
      hasError = true;
    } else if (!_isValidEmail(email)) {
      setState(() => _loginEmailError = 'Email inválido');
      hasError = true;
    }

    if (password.isEmpty) {
      setState(() => _loginPasswordError = 'Ingresa tu contraseña');
      hasError = true;
    }

    if (hasError) return;

    await ref.read(authNotifierProvider.notifier).signInWithEmailPassword(email, password);
  }

  Future<void> _handleEmailSignup() async {
    setState(() {
      _signupEmailError = null;
      _signupPasswordError = null;
      _signupConfirmPasswordError = null;
    });

    final email = _signupEmailController.text.trim();
    final password = _signupPasswordController.text.trim();
    final confirmPassword = _signupConfirmPasswordController.text.trim();

    bool hasError = false;
    if (email.isEmpty) {
      setState(() => _signupEmailError = 'Ingresa tu email');
      hasError = true;
    } else if (!_isValidEmail(email)) {
      setState(() => _signupEmailError = 'Email inválido');
      hasError = true;
    }

    if (password.isEmpty) {
      setState(() => _signupPasswordError = 'Ingresa una contraseña');
      hasError = true;
    } else if (password.length < 6) {
      setState(() => _signupPasswordError = 'Mínimo 6 caracteres');
      hasError = true;
    }

    if (confirmPassword.isEmpty) {
      setState(() => _signupConfirmPasswordError = 'Confirma tu contraseña');
      hasError = true;
    } else if (password != confirmPassword) {
      setState(() => _signupConfirmPasswordError = 'Las contraseñas no coinciden');
      hasError = true;
    }

    if (hasError) return;

    await ref.read(authNotifierProvider.notifier).signUpWithEmailPassword(email, password);
  }

  Future<void> _handleGoogleSignIn() async {
    await ref.read(authNotifierProvider.notifier).signInWithGoogle();
  }

  Future<void> _handleAppleSignIn() async {
    await ref.read(authNotifierProvider.notifier).signInWithApple();
  }

  Future<void> _handleBiometricLogin() async {
    await ref.read(authNotifierProvider.notifier).signInWithBiometrics();
  }

  Future<void> _handleForgotPassword() async {
    final email = _loginEmailController.text.trim();
    
    if (email.isEmpty || !_isValidEmail(email)) {
      _showErrorSnackBar('Por favor ingresa un email válido arriba para recuperar');
      return;
    }

    try {
      await ref.read(authNotifierProvider.notifier).resetPassword(email);
      _showSuccessSnackBar('Email de recuperación enviado');
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _showErrorSnackBar(String message) {
    showAppToast(
      context,
      message: message,
      type: ToastType.error,
    );
  }
  
  void _showSuccessSnackBar(String message) {
    showAppToast(
      context,
      message: message,
      type: ToastType.success,
    );
  }
}
