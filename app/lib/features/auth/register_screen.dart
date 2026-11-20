import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/services/api_client.dart';
import '../../core/theme/app_colors.dart';
import 'auth_gate.dart';
import 'auth_provider.dart';
import 'login_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
    ref.read(authProvider.notifier).clearError();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final l10n = AppLocalizations.of(context);

    try {
      await ref.read(authProvider.notifier).register(name, email, password);
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _mapAuthError(e, l10n);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = l10n.strings.authErrorConnection;
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _mapAuthError(ApiException e, AppLocalizations l10n) {
    if (e.statusCode == 400 && e.message.toLowerCase().contains('already exists')) {
      return l10n.strings.authErrorEmailExists;
    } else if (e.statusCode == 422) {
      return l10n.strings.authErrorValidation;
    } else if (e.statusCode == null || e.statusCode == 503 || e.statusCode == 502) {
      return l10n.strings.authErrorConnection;
    }
    return e.message.isNotEmpty ? e.message : l10n.strings.authErrorEmailExists;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: l10n.strings.languageLabel,
            icon: const Icon(LucideIcons.languages, size: 20),
            onPressed: () {
              ref.read(localeProvider.notifier).toggleLocale();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.secondary.withAlpha(isDark ? 80 : 40),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/sia_logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title & Subtitle
                  Text(
                    l10n.strings.registerTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.strings.registerSubtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Name Field
                  Text(
                    l10n.strings.nameLabel,
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    onChanged: (_) => _onFieldChanged(),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return l10n.strings.validationNameRequired;
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(LucideIcons.user, size: 18),
                      hintText: l10n.strings.nameHint,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  Text(
                    l10n.strings.emailLabel,
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => _onFieldChanged(),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return l10n.strings.validationEmailRequired;
                      }
                      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                      if (!emailRegex.hasMatch(val.trim())) {
                        return l10n.strings.validationEmailInvalid;
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(LucideIcons.mail, size: 18),
                      hintText: l10n.strings.emailHint,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  Text(
                    l10n.strings.passwordLabel,
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    onChanged: (_) => _onFieldChanged(),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return l10n.strings.validationPasswordRequired;
                      }
                      if (val.length < 6) {
                        return l10n.strings.validationPasswordTooShort;
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(LucideIcons.lock, size: 18),
                      hintText: l10n.strings.passwordHint,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password Field
                  Text(
                    l10n.strings.confirmPasswordLabel,
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    onChanged: (_) => _onFieldChanged(),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return l10n.strings.validationConfirmPasswordRequired;
                      }
                      if (val != _passwordController.text) {
                        return l10n.strings.validationPasswordsDoNotMatch;
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(LucideIcons.checkCheck, size: 18),
                      hintText: l10n.strings.confirmPasswordHint,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Prominent Inline Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.errorBgDark.withAlpha(200) : AppColors.errorBgLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.error.withAlpha(isDark ? 160 : 100),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              key: const Key('register_error_banner_text'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? const Color(0xFFFCA5A5) : AppColors.errorBgDark,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Sign Up Button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleRegister,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(l10n.strings.signUpButton),
                  ),
                  const SizedBox(height: 20),

                  // Switch to Login
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: Text(l10n.strings.alreadyHaveAccount),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
