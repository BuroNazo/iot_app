import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isRegister = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Email ve sifre bos birakilamaz.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = _isRegister
        ? await _authService.register(
            _emailController.text.trim(), _passwordController.text)
        : await _authService.signInWithEmail(
            _emailController.text.trim(), _passwordController.text);

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final error = await _authService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBottom,
      body: AuroraBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: AppTheme.accentGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppTheme.accentStart.withValues(alpha: 0.35),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.electrical_services_rounded,
                          color: Colors.white, size: 40),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      _isRegister ? 'Hesap Olustur' : 'Hosgeldiniz',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _isRegister
                          ? 'Akilli evine katil'
                          : 'Akilli evine giris yap',
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 36),
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    borderRadius: 24,
                    child: Column(
                      children: [
                        _GlassTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'ornek@email.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _GlassTextField(
                          controller: _passwordController,
                          label: 'Sifre',
                          hint: 'En az 6 karakter',
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          obscureText: _obscurePassword,
                          onToggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.offline.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.offline
                                      .withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppTheme.offline, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                        color: AppTheme.offline,
                                        fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        GradientButton(
                          label: _isRegister ? 'Kayit Ol' : 'Giris Yap',
                          isLoading: _isLoading,
                          onTap: _handleEmailAuth,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _isRegister = !_isRegister;
                        _errorMessage = null;
                      }),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 14),
                          children: [
                            TextSpan(
                                text: _isRegister
                                    ? 'Zaten hesabin var mi? '
                                    : 'Hesabin yok mu? '),
                            TextSpan(
                              text: _isRegister ? 'Giris Yap' : 'Kayit Ol',
                              style: const TextStyle(
                                  color: AppTheme.accentStart,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.1))),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('veya',
                            style: TextStyle(color: AppTheme.textMuted)),
                      ),
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.1))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    borderRadius: 16,
                    onTap: _isLoading ? null : _handleGoogleSignIn,
                    child: SizedBox(
                      height: 56,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: Colors.white),
                            child: const Center(
                              child: Text('G',
                                  style: TextStyle(
                                      color: Color(0xFF4285F4),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Google ile Giris Yap',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54, fontSize: 12, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.glassFillSubtle,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppTheme.accentStart, size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      onPressed: onToggleObscure,
                      icon: Icon(
                        obscureText
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.white38,
                        size: 20,
                      ),
                    )
                  : null,
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
