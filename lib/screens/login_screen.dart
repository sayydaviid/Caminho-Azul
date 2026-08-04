import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../services/auth_service.dart';
import '../widgets/dashboard_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    this.authService,
    super.key,
  });

  final AuthService? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AuthService _authService;

  AccessProfile? selectedProfile;
  bool showPassword = false;
  bool remember = false;
  bool isLoginLoading = false;
  bool isResetLoading = false;

  static const profiles = [
    (AccessProfile.escola, 'Escola', Icons.school_outlined),
    (AccessProfile.familia, 'Familia', Icons.favorite_outline),
    (AccessProfile.saude, 'Saude', Icons.medical_services_outlined),
    (
      AccessProfile.administracao,
      'Administracao',
      Icons.admin_panel_settings_outlined
    ),
  ];

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? FirebaseAuthService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEFF6FF), Colors.white, Color(0xFFEFF6FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Brand(),
                        const SizedBox(height: 26),
                        Text('Perfil de acesso',
                            style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 2.2,
                          children: profiles.map(_profileButton).toList(),
                        ),
                        const SizedBox(height: 22),
                        _LoginTextField(
                          key: const Key('login-email-field'),
                          label: 'E-mail',
                          hint: 'Digite seu e-mail',
                          controller: _emailController,
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          enabled: !isLoginLoading,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 16),
                        _LoginTextField(
                          key: const Key('login-password-field'),
                          label: 'Senha',
                          hint: 'Digite sua senha',
                          controller: _passwordController,
                          icon: Icons.lock_outline,
                          suffixIcon: showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          obscureText: !showPassword,
                          enabled: !isLoginLoading,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          validator: _validatePassword,
                          onSuffixPressed: () =>
                              setState(() => showPassword = !showPassword),
                          onFieldSubmitted: (_) => _handleLogin(),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: remember,
                                  onChanged: isLoginLoading
                                      ? null
                                      : (value) => setState(
                                          () => remember = value ?? false),
                                ),
                                const Text('Lembrar acesso',
                                    style: TextStyle(color: AppColors.muted)),
                              ],
                            ),
                            TextButton(
                              onPressed: isLoginLoading || isResetLoading
                                  ? null
                                  : _handlePasswordReset,
                              child: Text(isResetLoading
                                  ? 'Enviando...'
                                  : 'Esqueci minha senha'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: const Key('login-submit-button'),
                            onPressed: isLoginLoading ? null : _handleLogin,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: isLoginLoading
                                  ? const SizedBox(
                                      key: Key('login-loading-indicator'),
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Entrar',
                                      key: Key('login-submit-label'),
                                      textAlign: TextAlign.center,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileButton((AccessProfile, String, IconData) profile) {
    final selected = selectedProfile == profile.$1;
    return InkWell(
      key: Key('access-profile-${profile.$1.name}'),
      borderRadius: BorderRadius.circular(12),
      onTap: isLoginLoading
          ? null
          : () => setState(() => selectedProfile = profile.$1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF4F8FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              profile.$3,
              size: 20,
              color: selected ? AppColors.primary : AppColors.muted,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                profile.$2,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (isLoginLoading) {
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final profile = selectedProfile;
    if (profile == null) {
      _showMessage('Selecione um perfil de acesso.');
      return;
    }

    setState(() => isLoginLoading = true);

    try {
      final user = await _authService.signIn(
        email: _normalizedEmail,
        password: _passwordController.text,
      );

      if (user.role != profile.requiredRole) {
        await _authService.signOut();
        throw const AuthException(
          'O perfil selecionado nao corresponde ao perfil cadastrado para este usuario.',
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        _routeForProfile(profile),
        (_) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(mapFirebaseAuthError(error));
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Nao foi possivel entrar. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => isLoginLoading = false);
      }
    }
  }

  Future<void> _handlePasswordReset() async {
    if (isResetLoading) {
      return;
    }

    final emailError = _validateEmail(_emailController.text);
    if (emailError != null) {
      _showMessage('Digite um e-mail valido para recuperar a senha.');
      return;
    }

    setState(() => isResetLoading = true);

    try {
      await _authService.sendPasswordResetEmail(email: _normalizedEmail);
      if (!mounted) {
        return;
      }
      _showMessage(
          'Se existir uma conta vinculada a esse e-mail, voce recebera as instrucoes de recuperacao.');
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(mapFirebaseAuthError(error));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(
          'Nao foi possivel solicitar a recuperacao. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => isResetLoading = false);
      }
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim().toLowerCase() ?? '';
    if (email.isEmpty) {
      return 'Informe seu e-mail.';
    }
    final isEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!isEmail) {
      return 'Digite um e-mail valido.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe sua senha.';
    }
    return null;
  }

  String get _normalizedEmail => _emailController.text.trim().toLowerCase();

  String _routeForProfile(AccessProfile profile) {
    return switch (profile) {
      AccessProfile.escola => AppRoutes.dashboard,
      AccessProfile.familia => AppRoutes.family,
      AccessProfile.saude => AppRoutes.health,
      AccessProfile.administracao => AppRoutes.admin,
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.suffixIcon,
    this.onSuffixPressed,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String? hint;
  final TextEditingController controller;
  final IconData? icon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixPressed;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon, size: 19),
            suffixIcon: suffixIcon == null
                ? null
                : IconButton(
                    onPressed: enabled ? onSuffixPressed : null,
                    icon: Icon(suffixIcon, size: 19),
                  ),
          ),
        ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.extension_outlined,
              size: 32, color: AppColors.primary),
        ),
        const SizedBox(height: 10),
        Text(
          'Caminho Azul',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: 5),
        const Text(
          'Plataforma de integracao entre escola, familia e rede de cuidado',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
      ],
    );
  }
}
