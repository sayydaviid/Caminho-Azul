import 'package:flutter/material.dart';

import '../app/router.dart';
import '../app/theme.dart';
import 'bottom_nav.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.currentRoute,
    required this.child,
    super.key,
  });

  final String currentRoute;
  final Widget child;

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
    (AppRoutes.admin, Icons.admin_panel_settings_outlined, 'Administracao'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ola,', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            Text('Dra. Ana Silva', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, tooltip: 'Buscar', icon: const Icon(Icons.search)),
          Badge(
            smallSize: 8,
            child: IconButton(onPressed: () {}, tooltip: 'Notificacoes', icon: const Icon(Icons.notifications_outlined)),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: Color(0xFFDBEAFE),
              child: Text('AS', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      drawer: Drawer(
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
                        Text('Caminho Azul', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        Text('Plataforma TEA', style: TextStyle(color: Color(0xFFAFC0D4), fontSize: 12)),
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
                    for (final item in menuItems)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: ListTile(
                          selected: _isSelected(item.$1),
                          selectedTileColor: AppColors.sidebarAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          leading: Icon(item.$2, color: const Color(0xFFD4DEEA), size: 20),
                          title: Text(item.$3, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14)),
                          onTap: () => Navigator.pushReplacementNamed(context, item.$1),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(color: AppColors.sidebarAccent, height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFD4DEEA)),
                title: const Text('Sair', style: TextStyle(color: Color(0xFFE2E8F0))),
                onTap: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: child,
      ),
      bottomNavigationBar: BottomNav(currentRoute: currentRoute),
    );
  }

  bool _isSelected(String route) {
    return currentRoute == route;
  }
}
