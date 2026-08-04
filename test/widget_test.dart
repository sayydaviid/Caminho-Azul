import 'dart:async';

import 'package:caminho_azul/app/router.dart';
import 'package:caminho_azul/app/theme.dart';
import 'package:caminho_azul/screens/login_screen.dart';
import 'package:caminho_azul/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('abre a tela de login sem botao de primeiro acesso',
      (tester) async {
    await _pumpLogin(tester, FakeAuthService());

    expect(find.text('Caminho Azul'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Primeiro acesso'), findsNothing);
    expect(find.text('Escola'), findsOneWidget);
    expect(find.text('Familia'), findsOneWidget);
    expect(find.text('Saude'), findsOneWidget);
    expect(find.text('Administracao'), findsOneWidget);
  });

  testWidgets('mantem apenas um perfil selecionado por vez', (tester) async {
    await _pumpLogin(tester, FakeAuthService());

    await tester.tap(find.text('Escola'));
    await tester.pumpAndSettle();

    expect(_profileBorderWidth(tester, AccessProfile.escola), 2);
    expect(_profileBorderWidth(tester, AccessProfile.familia), 1);

    await tester.tap(find.text('Familia'));
    await tester.pumpAndSettle();

    expect(_profileBorderWidth(tester, AccessProfile.escola), 1);
    expect(_profileBorderWidth(tester, AccessProfile.familia), 2);
  });

  testWidgets('nao autentica com e-mail vazio', (tester) async {
    final authService = FakeAuthService();
    await _pumpLogin(tester, authService);

    await tester.tap(find.text('Escola'));
    await tester.enterText(
        find.byKey(const Key('login-password-field')), 'senha-segura');
    await _tapSubmit(tester);
    await tester.pump();

    expect(authService.signInCalls, 0);
    expect(find.text('Informe seu e-mail.'), findsOneWidget);
  });

  testWidgets('nao autentica com e-mail invalido', (tester) async {
    final authService = FakeAuthService();
    await _pumpLogin(tester, authService);

    await tester.tap(find.text('Escola'));
    await tester.enterText(
        find.byKey(const Key('login-email-field')), 'email-invalido');
    await tester.enterText(
        find.byKey(const Key('login-password-field')), 'senha-segura');
    await _tapSubmit(tester);
    await tester.pump();

    expect(authService.signInCalls, 0);
    expect(find.text('Digite um e-mail valido.'), findsOneWidget);
  });

  testWidgets('nao autentica com senha vazia', (tester) async {
    final authService = FakeAuthService();
    await _pumpLogin(tester, authService);

    await tester.tap(find.text('Escola'));
    await tester.enterText(
        find.byKey(const Key('login-email-field')), 'usuario@exemplo.com');
    await _tapSubmit(tester);
    await tester.pump();

    expect(authService.signInCalls, 0);
    expect(find.text('Informe sua senha.'), findsOneWidget);
  });

  testWidgets('nao autentica sem perfil selecionado', (tester) async {
    final authService = FakeAuthService();
    await _pumpLogin(tester, authService);

    await tester.enterText(
        find.byKey(const Key('login-email-field')), 'usuario@exemplo.com');
    await tester.enterText(
        find.byKey(const Key('login-password-field')), 'senha-segura');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(authService.signInCalls, 0);
    expect(find.text('Selecione um perfil de acesso.'), findsOneWidget);
  });

  testWidgets('mostra carregamento e evita multiplas requisicoes',
      (tester) async {
    final completer = Completer<AppUser>();
    final authService = FakeAuthService(signInCompleter: completer);
    await _pumpLogin(tester, authService);

    await _fillLogin(tester, profile: 'Escola');
    await _tapSubmit(tester);
    await tester.pump();
    await _tapSubmit(tester);

    expect(authService.signInCalls, 1);
    expect(find.byKey(const Key('login-loading-indicator')), findsOneWidget);

    completer.complete(const AppUser(
        uid: '1', email: 'usuario@exemplo.com', role: UserRole.school));
    await tester.pumpAndSettle();
  });

  testWidgets('exibe mensagem amigavel para credenciais invalidas',
      (tester) async {
    final authService = FakeAuthService(
      signInError: FirebaseAuthException(code: 'invalid-credential'),
    );
    await _pumpLogin(tester, authService);

    await _fillLogin(tester, profile: 'Escola');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('E-mail ou senha invalidos.'), findsOneWidget);
  });

  testWidgets('bloqueia acesso quando perfil selecionado diverge do cadastrado',
      (tester) async {
    final authService = FakeAuthService(
      appUser: const AppUser(
          uid: '1', email: 'usuario@exemplo.com', role: UserRole.school),
    );
    await _pumpLogin(tester, authService);

    await _fillLogin(tester, profile: 'Administracao');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(authService.signInCalls, 1);
    expect(authService.signOutCalls, 1);
    expect(
      find.text(
          'O perfil selecionado nao corresponde ao perfil cadastrado para este usuario.'),
      findsOneWidget,
    );
  });

  testWidgets('login bem-sucedido navega para a rota do perfil',
      (tester) async {
    final authService = FakeAuthService(
      appUser: const AppUser(
          uid: '1', email: 'usuario@exemplo.com', role: UserRole.family),
    );
    await _pumpLogin(tester, authService);

    await _fillLogin(tester, profile: 'Familia');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(authService.signInCalls, 1);
    expect(find.text('Status do acompanhamento'), findsOneWidget);
  });

  testWidgets('login administrativo valida sessao antes de exibir a area',
      (tester) async {
    const adminUser = AppUser(
      uid: '1',
      email: 'admin@exemplo.com',
      role: UserRole.administration,
      name: 'Admin Teste',
    );
    final authService = FakeAuthService(
      appUser: adminUser,
      adminSessionUser: adminUser,
    );
    await _pumpLogin(tester, authService);

    await _fillLogin(tester, profile: 'Administracao');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(authService.signInCalls, 1);
    expect(authService.adminSessionCalls, 1);
    expect(find.text('Area administrativa'), findsOneWidget);
    expect(find.text('Admin Teste'), findsWidgets);
  });

  testWidgets('rota administrativa direta fica bloqueada sem sessao valida',
      (tester) async {
    final authService = FakeAuthService(adminSessionUser: null);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        initialRoute: AppRoutes.admin,
        onGenerateRoute: (settings) => AppRouter.generateRoute(
          settings,
          authService: authService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(authService.adminSessionCalls, 1);
    expect(find.text('Area administrativa'), findsNothing);
    expect(find.text('Caminho Azul'), findsOneWidget);
  });

  testWidgets('recuperacao de senha exige e-mail valido', (tester) async {
    final authService = FakeAuthService();
    await _pumpLogin(tester, authService);

    await _tapPasswordReset(tester);
    await tester.pumpAndSettle();

    expect(authService.resetCalls, 0);
    expect(find.text('Digite um e-mail valido para recuperar a senha.'),
        findsOneWidget);
  });
}

Future<void> _pumpLogin(WidgetTester tester, AuthService authService) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      onGenerateRoute: (settings) => AppRouter.generateRoute(
        settings,
        authService: authService,
      ),
      home: LoginScreen(authService: authService),
    ),
  );
}

Future<void> _fillLogin(
  WidgetTester tester, {
  required String profile,
}) async {
  await tester.tap(find.text(profile));
  await tester.enterText(
      find.byKey(const Key('login-email-field')), 'usuario@exemplo.com');
  await tester.enterText(
      find.byKey(const Key('login-password-field')), 'senha-segura');
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final button = find.byKey(const Key('login-submit-button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
}

Future<void> _tapPasswordReset(WidgetTester tester) async {
  final button = find.text('Esqueci minha senha');
  await tester.ensureVisible(button);
  await tester.tap(button);
}

double _profileBorderWidth(WidgetTester tester, AccessProfile profile) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byKey(Key('access-profile-${profile.name}')),
      matching: find.byType(AnimatedContainer),
    ),
  );
  final decoration = container.decoration! as BoxDecoration;
  final border = decoration.border! as Border;
  return border.top.width;
}

class FakeAuthService implements AuthService {
  FakeAuthService({
    this.signInCompleter,
    this.signInError,
    this.resetError,
    this.adminSessionUser,
    this.adminSessionError,
    this.appUser = const AppUser(
        uid: '1', email: 'usuario@exemplo.com', role: UserRole.school),
  });

  final Completer<AppUser>? signInCompleter;
  final Object? signInError;
  final Object? resetError;
  final AppUser? adminSessionUser;
  final Object? adminSessionError;
  final AppUser appUser;

  int signInCalls = 0;
  int resetCalls = 0;
  int signOutCalls = 0;
  int adminSessionCalls = 0;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) {
    signInCalls++;
    if (signInCompleter != null) {
      return signInCompleter!.future;
    }
    if (signInError != null) {
      return Future<AppUser>.error(signInError!);
    }
    return Future.value(appUser);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
  }) {
    resetCalls++;
    if (resetError != null) {
      return Future<void>.error(resetError!);
    }
    return Future.value();
  }

  @override
  Stream<AppUser?> adminSessionChanges() {
    adminSessionCalls++;
    if (adminSessionError != null) {
      return Stream<AppUser?>.error(adminSessionError!);
    }
    return Stream<AppUser?>.value(adminSessionUser);
  }

  @override
  Future<void> signOut() {
    signOutCalls++;
    return Future.value();
  }
}
