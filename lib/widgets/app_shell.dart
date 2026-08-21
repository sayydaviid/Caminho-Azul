import 'package:flutter/material.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../services/auth_service.dart';
import 'bottom_nav.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.currentRoute,
    required this.child,
    this.authService,
    this.displayName,
    this.role,
    super.key,
  });

  final String currentRoute;
  final Widget child;
  final AuthService? authService;
  final String? displayName;
  final UserRole? role;

  static const menuItems = [
    (AppRoutes.dashboard, Icons.dashboard_outlined, 'Dashboard'),
    (AppRoutes.cases, Icons.people_outline, 'Casos'),
    (AppRoutes.observation, Icons.assignment_outlined, 'Ficha de Observacao'),
    (AppRoutes.reports, Icons.description_outlined, 'Relatorios'),
    (AppRoutes.referrals, Icons.send_outlined, 'Encaminhamentos'),
    (AppRoutes.timeline, Icons.timeline_outlined, 'Linha do Tempo'),
    (AppRoutes.documents, Icons.folder_outlined, 'Documentos'),
    (AppRoutes.family, Icons.favorite_outline, 'Familia'),
    (AppRoutes.health, Icons.medical_services_outlined, 'Saude'),
    (AppRoutes.admin, Icons.admin_panel_settings_outlined, 'Administração'),
  ];

  @override
  Widget build(BuildContext context) {
    final isAdminScreen = currentRoute == AppRoutes.admin;
    final effectiveDisplayName = displayName ?? 'Dra. Ana Silva';
    final initials = _initialsFor(effectiveDisplayName);
    final visibleMenuItems = menuItems.where((item) => _canAccess(item.$1));

    return Scaffold(
      resizeToAvoidBottomInset: !isAdminScreen,
      appBar: AppBar(
        titleSpacing: isAdminScreen ? 20 : 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Olá,',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
            Text(effectiveDisplayName,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          if (!isAdminScreen) ...[
            IconButton(
                onPressed: () {},
                tooltip: 'Buscar',
                icon: const Icon(Icons.search)),
            Badge(
              smallSize: 8,
              child: IconButton(
                  onPressed: () {},
                  tooltip: 'Notificacoes',
                  icon: const Icon(Icons.notifications_outlined)),
            ),
          ],
          if (isAdminScreen)
            PopupMenuButton<String>(
              key: const Key('admin-profile-menu'),
              tooltip: 'Menu do perfil',
              position: PopupMenuPosition.under,
              onSelected: (value) {
                if (value == 'logout') _handleLogout(context);
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 10),
                      Text('Sair'),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                child: _ProfileAvatar(initials: initials),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _ProfileAvatar(initials: initials),
            ),
        ],
      ),
      drawer: isAdminScreen
          ? null
          : Drawer(
              backgroundColor: AppColors.sidebar,
              child: SafeArea(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            child: Icon(Icons.extension_outlined),
                          ),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Caminho Azul',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                              Text('Plataforma TEA',
                                  style: TextStyle(
                                      color: Color(0xFFAFC0D4), fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: AppColors.sidebarAccent, height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(10),
                        children: [
                          for (final item in visibleMenuItems)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: ListTile(
                                selected: _isSelected(item.$1),
                                selectedTileColor: AppColors.sidebarAccent,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                leading: Icon(item.$2,
                                    color: const Color(0xFFD4DEEA), size: 20),
                                title: Text(item.$3,
                                    style: const TextStyle(
                                        color: Color(0xFFE2E8F0),
                                        fontSize: 14)),
                                onTap: () => Navigator.pushReplacementNamed(
                                    context, item.$1),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(color: AppColors.sidebarAccent, height: 1),
                    ListTile(
                      leading:
                          const Icon(Icons.logout, color: Color(0xFFD4DEEA)),
                      title: const Text('Sair',
                          style: TextStyle(color: Color(0xFFE2E8F0))),
                      onTap: () => _handleLogout(context),
                    ),
                  ],
                ),
              ),
            ),
      body: SafeArea(
        top: false,
        child: child,
      ),
      bottomNavigationBar: BottomNav(currentRoute: currentRoute, role: role),
    );
  }

  bool _isSelected(String route) {
    return currentRoute == route;
  }

  bool _canAccess(String route) {
    final currentRole = role;
    if (currentRole == null || currentRole == UserRole.administration) {
      return true;
    }
    return switch (currentRole) {
      UserRole.school => {
          AppRoutes.dashboard,
          AppRoutes.cases,
          AppRoutes.observation,
          AppRoutes.reports,
          AppRoutes.timeline,
          AppRoutes.documents,
        }.contains(route),
      UserRole.family => {
          AppRoutes.family,
          AppRoutes.timeline,
          AppRoutes.documents,
        }.contains(route),
      UserRole.health => {
          AppRoutes.health,
          AppRoutes.referrals,
          AppRoutes.timeline,
          AppRoutes.documents,
        }.contains(route),
      UserRole.administration => true,
    };
  }

  Future<void> _handleLogout(BuildContext context) async {
    await authService?.signOut();

    if (!context.mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  String _initialsFor(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'CA';
    }

    final first = parts.first.characters.first.toUpperCase();
    final second =
        parts.length > 1 ? parts.last.characters.first.toUpperCase() : '';
    return '$first$second';
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 17,
        backgroundColor: const Color(0xFFDBEAFE),
        child: Text(
          initials,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
