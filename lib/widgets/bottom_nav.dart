import 'package:flutter/material.dart';

import '../app/router.dart';
import '../services/auth_service.dart';
import 'demo_only.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({required this.currentRoute, this.role, super.key});

  final String currentRoute;
  final UserRole? role;

  static const _schoolRoutes = [
    AppRoutes.dashboard,
    AppRoutes.observation,
    AppRoutes.timeline,
    AppRoutes.documents,
  ];

  @override
  Widget build(BuildContext context) {
    if (currentRoute == AppRoutes.admin) {
      // O painel é o início do admin: volta ao estado inicial do painel, e não
      // para `/app`, que é a área da Escola.
      return _AdminHomeNavigation(
        onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.admin),
      );
    }
    final routes = _visibleRoutes;
    // Com uma única área real, a barra inferior não é necessária.
    if (routes.length < 2) return const SizedBox.shrink();
    final index = routes.indexOf(
        currentRoute == AppRoutes.dashboard ? AppRoutes.cases : currentRoute);
    return NavigationBar(
      selectedIndex: index < 0 ? 0 : index,
      onDestinationSelected: (next) {
        if (routes[next] != currentRoute) {
          Navigator.pushReplacementNamed(context, routes[next]);
        }
      },
      destinations: [for (final route in routes) _destination(route)],
    );
  }

  List<String> get _visibleRoutes {
    if (!demoMode) {
      return switch (role) {
        UserRole.family => const [AppRoutes.family, AppRoutes.notifications],
        UserRole.health => const [AppRoutes.health],
        _ => const [AppRoutes.cases, AppRoutes.students],
      };
    }
    if (role == UserRole.family) {
      return const [AppRoutes.family, AppRoutes.timeline, AppRoutes.documents];
    }
    if (role == UserRole.health) {
      return const [AppRoutes.health, AppRoutes.timeline, AppRoutes.documents];
    }
    return _schoolRoutes;
  }

  NavigationDestination _destination(String route) => switch (route) {
        AppRoutes.family => const NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Família'),
        AppRoutes.notifications => const NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notificações'),
        AppRoutes.health => const NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services),
            label: 'Saúde'),
        AppRoutes.cases => const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Casos'),
        AppRoutes.students => const NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge),
            label: 'Estudantes'),
        AppRoutes.observation => const NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Ficha'),
        AppRoutes.timeline => const NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'Linha do tempo'),
        AppRoutes.documents => const NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Documentos'),
        _ => const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Início'),
      };
}

class _AdminHomeNavigation extends StatelessWidget {
  const _AdminHomeNavigation({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color:
          theme.navigationBarTheme.backgroundColor ?? theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Center(
            child: InkWell(
              key: const Key('admin-home-navigation'),
              borderRadius: BorderRadius.circular(24),
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.dashboard,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Início',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
