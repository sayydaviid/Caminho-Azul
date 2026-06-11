import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class CaminhoAzulApp extends StatelessWidget {
  const CaminhoAzulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caminho Azul',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.login,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
