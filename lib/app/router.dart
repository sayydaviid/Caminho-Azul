import 'package:flutter/material.dart';

import '../screens/admin_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/documentos_screen.dart';
import '../screens/familia_screen.dart';
import '../screens/ficha_observacao_screen.dart';
import '../screens/linha_tempo_screen.dart';
import '../screens/login_screen.dart';
import '../screens/relatorio_screen.dart';
import '../screens/saude_screen.dart';
import '../widgets/app_shell.dart';

abstract final class AppRoutes {
  static const login = '/';
  static const dashboard = '/app';
  static const cases = '/app/casos';
  static const observation = '/app/ficha-observacao';
  static const reports = '/app/relatorios';
  static const referrals = '/app/encaminhamentos';
  static const timeline = '/app/linha-do-tempo';
  static const documents = '/app/documentos';
  static const family = '/app/familia';
  static const health = '/app/saude';
  static const admin = '/app/administracao';
}

abstract final class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    if (settings.name == AppRoutes.login) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const LoginScreen(),
      );
    }

    final child = switch (settings.name) {
      AppRoutes.observation => const FichaObservacaoScreen(),
      AppRoutes.reports => const RelatorioScreen(),
      AppRoutes.referrals || AppRoutes.health => const SaudeScreen(),
      AppRoutes.timeline => const LinhaTempoScreen(),
      AppRoutes.documents => const DocumentosScreen(),
      AppRoutes.family => const FamiliaScreen(),
      AppRoutes.admin => const AdminScreen(),
      _ => const DashboardScreen(),
    };

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => AppShell(
        currentRoute: settings.name ?? AppRoutes.dashboard,
        child: child,
      ),
    );
  }
}
