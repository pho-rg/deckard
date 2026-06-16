import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'main_navigation.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final needsOnboarding = _isLogin
          ? await AuthService.login(
              _emailCtrl.text.trim(), _passwordCtrl.text)
          : await AuthService.register(
              _emailCtrl.text.trim(),
              _usernameCtrl.text.trim(),
              _passwordCtrl.text,
            );
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => needsOnboarding
                ? const OnboardingScreen()
                : const MainNavigation(),
          ),
          (_) => false,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Logo ─────────────────────────────────────────────────
                  const _DeckardLogo(),
                  const SizedBox(height: 12),
                  Text(
                    l10n.loginSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textDim),
                  ),

                  const SizedBox(height: 36),

                  // ── Toggle login / register ───────────────────────────────
                  _ModeToggle(
                    isLogin: _isLogin,
                    onToggle: _toggleMode,
                    loginLabel: l10n.loginTab,
                    registerLabel: l10n.registerTab,
                  ),

                  const SizedBox(height: 28),

                  // ── Champs ────────────────────────────────────────────────
                  _FieldLabel(l10n.emailLabel),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: _isLogin
                        ? TextInputAction.next
                        : TextInputAction.next,
                    autocorrect: false,
                    style: const TextStyle(color: AppTheme.textMain),
                    decoration: _inputDeco(
                        hint: 'you@example.com',
                        icon: Icons.alternate_email),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return l10n.fieldRequired;
                      }
                      if (!v.contains('@')) return l10n.invalidEmail;
                      return null;
                    },
                  ),

                  // Username — register only
                  if (!_isLogin) ...[
                    const SizedBox(height: 16),
                    _FieldLabel(l10n.usernameLabel),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _usernameCtrl,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      style: const TextStyle(color: AppTheme.textMain),
                      decoration: _inputDeco(
                          hint: 'john_doe', icon: Icons.person_outline),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return l10n.fieldRequired;
                        }
                        if (v.trim().length < 3) return l10n.usernameTooShort;
                        return null;
                      },
                    ),
                  ],

                  const SizedBox(height: 16),
                  _FieldLabel(l10n.passwordLabel),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    textInputAction: _isLogin
                        ? TextInputAction.done
                        : TextInputAction.next,
                    onFieldSubmitted: _isLogin ? (_) => _submit() : null,
                    style: const TextStyle(color: AppTheme.textMain),
                    decoration: _inputDeco(
                      hint: '••••••••',
                      icon: Icons.lock_outline,
                      suffix: _visibilityToggle(
                        obscure: _obscurePassword,
                        onTap: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return l10n.fieldRequired;
                      if (!_isLogin && v.length < 8) {
                        return l10n.passwordTooShort;
                      }
                      return null;
                    },
                  ),

                  // Confirm password — register only
                  if (!_isLogin) ...[
                    const SizedBox(height: 16),
                    _FieldLabel(l10n.confirmPasswordLabel),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      style: const TextStyle(color: AppTheme.textMain),
                      decoration: _inputDeco(
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        suffix: _visibilityToggle(
                          obscure: _obscureConfirm,
                          onTap: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return l10n.fieldRequired;
                        if (v != _passwordCtrl.text) {
                          return l10n.passwordMismatch;
                        }
                        return null;
                      },
                    ),
                  ],

                  // ── Erreur ────────────────────────────────────────────────
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(message: _errorMessage!),
                  ],

                  const SizedBox(height: 28),

                  // ── Bouton principal ──────────────────────────────────────
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _isLogin ? l10n.loginButton : l10n.registerButton,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _visibilityToggle(
      {required bool obscure, required VoidCallback onTap}) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
        color: AppTheme.textDim,
      ),
      onPressed: onTap,
    );
  }

  InputDecoration _inputDeco(
      {required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      prefixIcon: Icon(icon, color: AppTheme.textDim, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppTheme.surface,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white12)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white12)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppTheme.primaryPurple, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: Colors.redAccent.withOpacity(0.6))),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent)),
      errorStyle:
          const TextStyle(color: Colors.redAccent, fontSize: 12),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toggle Connexion / Inscription
// ─────────────────────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onToggle;
  final String loginLabel;
  final String registerLabel;

  const _ModeToggle({
    required this.isLogin,
    required this.onToggle,
    required this.loginLabel,
    required this.registerLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _Tab(
              label: loginLabel,
              active: isLogin,
              onTap: isLogin ? null : onToggle),
          _Tab(
              label: registerLabel,
              active: !isLogin,
              onTap: !isLogin ? null : onToggle),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _Tab(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppTheme.primaryPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: active ? Colors.white : AppTheme.textDim,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo
// ─────────────────────────────────────────────────────────────────────────────

class _DeckardLogo extends StatelessWidget {
  const _DeckardLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryPurple.withOpacity(0.15),
            border: Border.all(
                color: AppTheme.primaryPurple.withOpacity(0.4), width: 1.5),
          ),
          child: const Icon(Icons.movie_creation_outlined,
              color: AppTheme.secondaryPurple, size: 34),
        ),
        const SizedBox(height: 16),
        const Text(
          'DECKARD',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppTheme.textMain,
            letterSpacing: 6,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: AppTheme.textDim,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style:
                    const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
