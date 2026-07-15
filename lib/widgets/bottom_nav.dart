import 'package:flutter/material.dart';

import '../app/router.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({required this.currentRoute, super.key});

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    const routes = [
      AppRoutes.dashboard,
      AppRoutes.observation,
      AppRoutes.timeline,
      AppRoutes.documents,
    ];
    final index = routes.indexOf(currentRoute);

    return NavigationBar(
      selectedIndex: index < 0 ? 0 : index,
      onDestinationSelected: (next) {
        if (routes[next] != currentRoute) {
          Navigator.pushReplacementNamed(context, routes[next]);
        }
      },
      destinations: const [
        NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Inicio'),
        NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Ficha'),
        NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'Linha do tempo'),
        NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Documentos'),
      ],
    );
  }
}
