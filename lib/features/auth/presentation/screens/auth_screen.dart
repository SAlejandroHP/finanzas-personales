import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/app_social_button.dart';
import '../providers/auth_provider.dart';

/// Pantalla de autenticación con tabs para Login y Registro.
/// Incluye soporte para Face ID/Touch ID y login social con Google/Apple.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;

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
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pageController = PageController();

    // Sincroniza el TabController con el PageController
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _pageController.animateToPage(
          _tabController.index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canUseBiometrics = ref.watch(canUseBiometricsProvider);
    final isLoading = ref.watch(authLoadingProvider);

    // Escucha cambios en el estado de autenticación
    ref.listen<AsyncValue<dynamic>>(authNotifierProvider, (previous, next) {
      next.when(
        data: (user) {
          if (user != null) {
            // Navega al dashboard cuando hay usuario autenticado
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
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo y título
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size : 64,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Finanzas Personal',
                      style: GoogleFonts.montserrat(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gestiona tu dinero de forma inteligente',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Tabs personalizados
              _buildCustomTabs(isDark),
              const SizedBox(height: 24),

              // Contenedor con altura fija para los formularios
              SizedBox(
                height: 450, // Altura fija para evitar cambios
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    _tabController.animateTo(index);
                  },
                  children: [
                    // Pestaña de Login
                    _buildLoginForm(isDark, canUseBiometrics, isLoading),
                    // Pestaña de Registro
                    _buildSignupForm(isDark, isLoading),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye los tabs personalizados con indicador animado
  Widget _buildCustomTabs(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTab('Iniciar sesión', 0, isDark),
            ),
            Expanded(
              child: _buildTab('Crear cuenta', 1, isDark),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Indicador animado con degradado teal
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, child) {
            return Stack(
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  left: _tabController.index == 0
                      ? 0
                      : MediaQuery.of(context).size.width / 2 - 24,
                  child: Container(
                    height: 3,
                    width: (MediaQuery.of(context).size.width - 48) / 2,
                    decoration: BoxDecoration(
                      gradient: AppColors.tealGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Construye un tab individual
  Widget _buildTab(String text, int index, bool isDark) {
    final isSelected = _tabController.index == index;

    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.white : AppColors.primary)
                : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  /// Construye el formulario de login
  Widget _buildLoginForm(bool isDark, AsyncValue<bool> canUseBiometrics, bool isLoading) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // Botones sociales
          // Google Sign-In solo disponible en plataformas móviles
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
          if (!kIsWeb) const SizedBox(height: 20),

          // Divisor
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[400])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'O con email',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey[400])),
            ],
          ),
          const SizedBox(height: 20),

          // Campos de email y contraseña
          AppTextField(
            label: 'Email',
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline,
            helperText: _loginEmailError,
            isError: _loginEmailError != null,
            enabled: !isLoading,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Contraseña',
            controller: _loginPasswordController,
            isPassword: true,
            prefixIcon: Icons.lock_outline,
            helperText: _loginPasswordError,
            isError: _loginPasswordError != null,
            enabled: !isLoading,
          ),
          const SizedBox(height: 8),

          // Olvidé mi contraseña
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isLoading ? null : _handleForgotPassword,
              child: Text(
                'Olvidé mi contraseña',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Botón de login
          AppButton(
            label      : 'Iniciar sesión',
            onPressed  : isLoading ? null: _handleEmailLogin,
            isFullWidth: true,
            isLoading  : isLoading,
            height     : AppSizes.buttonHeight,
          ),
          const SizedBox(height: 16),

          // Botón de Face ID / Touch ID (si está disponible)
          canUseBiometrics.when(
            data: (canUse) {
              if (!canUse) return const SizedBox.shrink();
              
              final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
              
              return AppButton(
                label: isIOS ? 'Ingresar con Face ID' : 'Ingresar con Touch ID',
                icon: isIOS ? Icons.qr_code_scanner_outlined : Icons.fingerprint_outlined,
                onPressed: isLoading ? null : _handleBiometricLogin,
                variant: 'outlined',
                isFullWidth: true,
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Construye el formulario de registro
  Widget _buildSignupForm(bool isDark, bool isLoading) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // Botones sociales
          // Google Sign-In solo disponible en plataformas móviles
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
          if (!kIsWeb) const SizedBox(height: 20),

          // Divisor
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[400])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'O con email',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey[400])),
            ],
          ),
          const SizedBox(height: 20),

          // Campos de registro
          AppTextField(
            label: 'Email',
            controller: _signupEmailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline,
            helperText: _signupEmailError,
            isError: _signupEmailError != null,
            enabled: !isLoading,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Contraseña',
            controller: _signupPasswordController,
            isPassword: true,
            prefixIcon: Icons.lock_outline,
            helperText: _signupPasswordError,
            isError: _signupPasswordError != null,
            enabled: !isLoading,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Confirmar contraseña',
            controller: _signupConfirmPasswordController,
            isPassword: true,
            prefixIcon: Icons.lock_outline,
            helperText: _signupConfirmPasswordError,
            isError: _signupConfirmPasswordError != null,
            enabled: !isLoading,
          ),
          const SizedBox(height: 24),

          // Botón de registro
          AppButton(
            label: 'Crear cuenta',
            onPressed: isLoading ? null : _handleEmailSignup,
            isFullWidth: true,
            isLoading: isLoading,
          ),
        ],
      ),
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

    // Validación
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

    // Validación
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
      _showErrorSnackBar('Por favor ingresa un email válido');
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
