import 'package:flutter/material.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';
import '../widgets/dashboard_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String selectedProfile = 'escola';
  bool showPassword = false;
  bool remember = false;

  static const profiles = [
    ('escola', 'Escola', Icons.school_outlined),
    ('familia', 'Familia', Icons.favorite_outline),
    ('saude', 'Saude', Icons.medical_services_outlined),
    ('admin', 'Administracao', Icons.admin_panel_settings_outlined),
  ];

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
                      const CustomInput(
                        label: 'E-mail ou CPF',
                        hint: 'Digite seu e-mail ou CPF',
                        icon: Icons.mail_outline,
                      ),
                      const SizedBox(height: 16),
                      CustomInput(
                        label: 'Senha',
                        hint: 'Digite sua senha',
                        icon: Icons.lock_outline,
                        suffixIcon: showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        obscureText: !showPassword,
                        onSuffixPressed: () =>
                            setState(() => showPassword = !showPassword),
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
                                onChanged: (value) =>
                                    setState(() => remember = value ?? false),
                              ),
                              const Text('Lembrar acesso',
                                  style: TextStyle(color: AppColors.muted)),
                            ],
                          ),
                          TextButton(
                              onPressed: () {},
                              child: const Text('Esqueci minha senha')),
                        ],
                      ),
                      const SizedBox(height: 14),
                      CustomButton(
                        label: 'Entrar',
                        primary: true,
                        fullWidth: true,
                        onPressed: _enter,
                      ),
                      const SizedBox(height: 10),
                      CustomButton(
                          label: 'Primeiro acesso',
                          fullWidth: true,
                          onPressed: () {}),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileButton((String, String, IconData) profile) {
    final selected = selectedProfile == profile.$1;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => selectedProfile = profile.$1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF4F8FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(profile.$3,
                size: 20,
                color: selected ? AppColors.primary : AppColors.muted),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                profile.$2,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: selected ? AppColors.primary : AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _enter() {
    final route = switch (selectedProfile) {
      'familia' => AppRoutes.family,
      'saude' => AppRoutes.health,
      'admin' => AppRoutes.admin,
      _ => AppRoutes.dashboard,
    };
    Navigator.pushReplacementNamed(context, route);
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
