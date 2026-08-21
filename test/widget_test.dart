import 'dart:async';

import 'package:caminho_azul/app/router.dart';
import 'package:caminho_azul/app/theme.dart';
import 'package:caminho_azul/models/admin_models.dart';
import 'package:caminho_azul/repositories/admin_repository.dart';
import 'package:caminho_azul/screens/admin_screen.dart';
import 'package:caminho_azul/screens/login_screen.dart';
import 'package:caminho_azul/services/admin_user_service.dart';
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
    expect(find.text('Professor'), findsNothing);
    expect(find.text('Direção'), findsNothing);
    expect(find.text('Família'), findsOneWidget);
    expect(find.text('Saúde'), findsOneWidget);
    expect(find.text('Administração'), findsOneWidget);
  });

  testWidgets('mantem apenas um perfil selecionado por vez', (tester) async {
    await _pumpLogin(tester, FakeAuthService());

    await tester.tap(find.text('Escola'));
    await tester.pumpAndSettle();

    expect(_profileBorderWidth(tester, AccessProfile.escola), 2);
    expect(_profileBorderWidth(tester, AccessProfile.familia), 1);

    await tester.tap(find.text('Família'));
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
      uid: '1',
      email: 'usuario@exemplo.com',
      role: UserRole.school,
      schoolRole: SchoolRole.teacher,
    ));
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

    await _fillLogin(tester, profile: 'Administração');
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

  testWidgets('login da escola usa a subrole cadastrada sem nova escolha',
      (tester) async {
    final authService = FakeAuthService(
      appUser: const AppUser(
        uid: '1',
        email: 'professor@exemplo.com',
        role: UserRole.school,
        schoolRole: SchoolRole.teacher,
      ),
    );
    await _pumpLogin(tester, authService);

    await _fillLogin(tester, profile: 'Escola');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(authService.signOutCalls, 0);
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('login bem-sucedido navega para a rota do perfil',
      (tester) async {
    final authService = FakeAuthService(
      appUser: const AppUser(
          uid: '1', email: 'usuario@exemplo.com', role: UserRole.family),
    );
    await _pumpLogin(tester, authService);

    await _fillLogin(tester, profile: 'Família');
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

    await _fillLogin(tester, profile: 'Administração');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(authService.signInCalls, 1);
    expect(authService.adminSessionCalls, 1);
    expect(find.text('Administração'), findsOneWidget);
    expect(find.text('Admin Teste'), findsWidgets);
    expect(find.text('Olá,'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byKey(const Key('admin-home-navigation')), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNothing);
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Ficha'), findsNothing);
    expect(find.byTooltip('Buscar'), findsNothing);
    expect(find.byTooltip('Notificacoes'), findsNothing);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.resizeToAvoidBottomInset, isFalse);

    await tester.tap(find.byKey(const Key('admin-profile-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Sair'), findsOneWidget);
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(authService.signOutCalls, 1);
    expect(find.text('Caminho Azul'), findsOneWidget);
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
    expect(find.byKey(const Key('admin-screen')), findsNothing);
    expect(find.text('Caminho Azul'), findsOneWidget);
  });

  testWidgets('administracao alterna secoes e filtra profissionais',
      (tester) async {
    await _pumpAdmin(tester);

    expect(find.text('Administração'), findsOneWidget);
    expect(find.text('EM Monteiro Lobato'), findsOneWidget);

    await tester.tap(find.byKey(const Key('admin-tab-professionals')));
    await tester.pumpAndSettle();
    expect(find.text('Dra. Ana Silva'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('admin-search-field')),
      'Marcos',
    );
    await tester.pump();

    expect(find.text('Dr. Marcos Pereira'), findsOneWidget);
    expect(find.text('Dra. Ana Silva'), findsNothing);
  });

  testWidgets('administracao permite cadastrar uma instituicao',
      (tester) async {
    await _pumpAdmin(tester);

    await tester.tap(find.byKey(const Key('admin-new-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('admin-form-name')),
      'Centro Azul',
    );
    await tester.enterText(
      find.byKey(const Key('admin-form-type')),
      'Centro de apoio',
    );
    await tester.enterText(
      find.byKey(const Key('admin-form-street')),
      'Rua Principal',
    );
    await tester.enterText(
      find.byKey(const Key('admin-form-number')),
      '10',
    );
    await tester.enterText(
      find.byKey(const Key('admin-form-district')),
      'Centro',
    );
    await tester.enterText(
      find.byKey(const Key('admin-form-city')),
      'Belém',
    );
    await tester.enterText(find.byKey(const Key('admin-form-state')), 'PA');
    await tester.enterText(
      find.byKey(const Key('admin-form-zipCode')),
      '66000-000',
    );
    await tester.ensureVisible(find.byKey(const Key('admin-form-submit')));
    await tester.tap(find.byKey(const Key('admin-form-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Centro Azul'), findsOneWidget);
    expect(find.text('Instituição criada com sucesso.'), findsOneWidget);
  });

  testWidgets('novo cadastro abre formulario conforme a secao', (tester) async {
    await _pumpAdmin(tester);

    await tester.tap(find.byKey(const Key('admin-tab-professionals')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-new-button')));
    await tester.pumpAndSettle();
    expect(find.text('Novo profissional'), findsOneWidget);
    Navigator.of(tester.element(find.text('Novo profissional'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('admin-tab-users')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-new-button')));
    await tester.pumpAndSettle();
    expect(find.text('Novo usuário'), findsOneWidget);
    expect(find.textContaining('Senha'), findsNothing);
  });

  testWidgets('icone de caneta abre formulario preenchido', (tester) async {
    await _pumpAdmin(tester);

    await tester.tap(find.byTooltip('Editar').first);
    await tester.pumpAndSettle();

    expect(find.text('Editar instituição'), findsOneWidget);
    final nameField = tester.widget<TextFormField>(
      find.byKey(const Key('admin-form-name')),
    );
    expect(nameField.controller?.text, 'EM Monteiro Lobato');
  });

  testWidgets('administracao cria usuario sem trocar a sessao atual',
      (tester) async {
    final repository = FakeAdminRepository();
    final userService = FakeAdminUserService();
    await _pumpAdmin(
      tester,
      repository: repository,
      userService: userService,
    );
    await tester.tap(find.byKey(const Key('admin-tab-users')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-new-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('admin-form-fullName')),
      'Maria Silva',
    );
    await tester.enterText(
      find.byKey(const Key('admin-form-email')),
      'MARIA@EXEMPLO.COM ',
    );
    await tester.tap(find.byKey(const Key('admin-form-role')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('admin-school-role-option-professor')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('admin-school-role-option-direcao')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('admin-school-role-option-professor')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('admin-form-submit')));
    await tester.tap(find.byKey(const Key('admin-form-submit')));
    await tester.pumpAndSettle();

    expect(userService.createCalls, 1);
    expect(repository.users.single.email, 'maria@exemplo.com');
    expect(repository.users.single.role, UserRole.school);
    expect(repository.users.single.schoolRole, SchoolRole.teacher);
    expect(find.text('Maria Silva'), findsOneWidget);
    expect(
      find.text(
        'Usuário criado. Um e-mail para definição de senha foi enviado.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('profissional herda nome e e-mail do usuario vinculado',
      (tester) async {
    final repository = FakeAdminRepository()
      ..addUser(const AdminUser(
        id: 'user-professional',
        firstName: 'Maria',
        lastName: 'Profissional',
        name: 'Maria Profissional',
        email: 'maria@exemplo.com',
        role: UserRole.health,
        active: true,
      ));
    await _pumpAdmin(tester, repository: repository);
    await tester.tap(find.byKey(const Key('admin-tab-professionals')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-new-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('admin-form-firstName')), findsNothing);
    expect(find.byKey(const Key('admin-form-lastName')), findsNothing);
    expect(find.byKey(const Key('admin-form-email')), findsNothing);
    expect(find.byKey(const Key('admin-form-specialty')), findsNothing);

    await tester.tap(find.byKey(const Key('admin-form-user')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Maria Profissional • maria@exemplo.com').last,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('admin-form-registrationNumber')),
      'CRP 1234',
    );
    await tester.ensureVisible(find.byKey(const Key('admin-form-submit')));
    await tester.tap(find.byKey(const Key('admin-form-submit')));
    await tester.pumpAndSettle();

    final professional = repository.professionals
        .firstWhere((item) => item.userId == 'user-professional');
    expect(professional.name, 'Maria Profissional');
    expect(professional.email, 'maria@exemplo.com');
    expect(professional.specialty, isNull);
    expect(professional.registrationNumber, 'CRP 1234');
    expect(find.text('Profissional criado com sucesso.'), findsOneWidget);
  });

  testWidgets('administracao edita a role de outro usuario', (tester) async {
    final repository = FakeAdminRepository()
      ..addUser(const AdminUser(
        id: 'user-1',
        firstName: 'Usuário',
        lastName: 'Teste',
        name: 'Usuário Teste',
        email: 'usuario@exemplo.com',
        role: UserRole.family,
        active: true,
      ));
    await _pumpAdmin(tester, repository: repository);
    await tester.tap(find.byKey(const Key('admin-tab-users')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();

    final emailField = tester.widget<TextFormField>(
      find.byKey(const Key('admin-form-email')),
    );
    expect(emailField.enabled, isFalse);
    expect(
      find.text('O e-mail de login não pode ser alterado pelo aplicativo.'),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('admin-form-role')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('admin-role-option-saude')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const Key('admin-role-option-saude')),
    );
    await tester.tap(find.byKey(const Key('admin-role-option-saude')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('admin-form-submit')));
    await tester.tap(find.byKey(const Key('admin-form-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar alteração'), findsOneWidget);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(repository.users.single.role, UserRole.health);
    expect(find.text('Usuário atualizado com sucesso.'), findsOneWidget);
  });

  testWidgets('administracao exclui outro usuario apos confirmacao',
      (tester) async {
    final repository = FakeAdminRepository()
      ..addUser(const AdminUser(
        id: 'user-1',
        firstName: 'Usuário',
        lastName: 'Excluível',
        name: 'Usuário Excluível',
        email: 'excluir@exemplo.com',
        role: UserRole.family,
        active: true,
      ));
    await _pumpAdmin(tester, repository: repository);
    await tester.tap(find.byKey(const Key('admin-tab-users')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('admin-form-delete-user')),
    );
    await tester.tap(find.byKey(const Key('admin-form-delete-user')));
    await tester.pumpAndSettle();
    expect(find.text('Excluir usuário?'), findsOneWidget);
    expect(repository.users, hasLength(1));

    await tester.tap(find.byKey(const Key('admin-confirm-delete-user')));
    await tester.pumpAndSettle();

    expect(repository.users, isEmpty);
    expect(find.text('Usuário Excluível'), findsNothing);
    expect(
      find.text('Usuário excluído e acesso removido com sucesso.'),
      findsOneWidget,
    );
  });

  test('roles persistidas aceitam valores atuais e legados', () {
    expect(UserRole.fromValue('escola'), UserRole.school);
    expect(UserRole.fromValue('school'), UserRole.school);
    expect(UserRole.fromValue('familia'), UserRole.family);
    expect(UserRole.fromValue('saude'), UserRole.health);
    expect(UserRole.fromValue('admin'), UserRole.administration);
    expect(SchoolRole.fromValue('professor'), SchoolRole.teacher);
    expect(SchoolRole.fromValue('direcao'), SchoolRole.leadership);
    expect(SchoolRole.fromValue('coordenacao'), isNull);
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
  final repository = FakeAdminRepository();
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      onGenerateRoute: (settings) => AppRouter.generateRoute(
        settings,
        authService: authService,
        adminRepository: repository,
      ),
      home: LoginScreen(authService: authService),
    ),
  );
}

Future<void> _pumpAdmin(
  WidgetTester tester, {
  FakeAdminRepository? repository,
  AdminUserService? userService,
}) async {
  final authService = FakeAuthService();
  final effectiveRepository = repository ?? FakeAdminRepository();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: AdminScreen(
          user: const AppUser(
            uid: 'admin',
            email: 'admin@caminhoazul.com',
            role: UserRole.administration,
            name: 'Admin Teste',
          ),
          authService: authService,
          repository: effectiveRepository,
          userService: userService ?? FakeAdminUserService(),
        ),
      ),
    ),
  );
  await tester.pump();
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
      uid: '1',
      email: 'usuario@exemplo.com',
      role: UserRole.school,
      schoolRole: SchoolRole.teacher,
    ),
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
  Stream<AppUser?> sessionChanges() {
    return Stream<AppUser?>.value(appUser);
  }

  @override
  Future<void> signOut() {
    signOutCalls++;
    return Future.value();
  }
}

class FakeAdminUserService implements AdminUserService {
  int createCalls = 0;

  @override
  Future<AdminAccountCreationResult> createAccount({
    required String email,
    required String displayName,
    required Future<void> Function(String uid) createProfile,
  }) async {
    createCalls++;
    await createProfile('created-user-$createCalls');
    return AdminAccountCreationResult(
      uid: 'created-user-$createCalls',
      invitationSent: true,
    );
  }
}

class FakeAdminRepository implements AdminRepository {
  final institutions = <Institution>[
    const Institution(
      id: 'inst-1',
      name: 'EM Monteiro Lobato',
      type: 'Escola',
      address: Address(
        street: 'Rua Azul',
        number: '10',
        district: 'Centro',
        city: 'Belém',
        state: 'PA',
        zipCode: '66000-000',
      ),
      active: true,
    ),
  ];
  final professionals = <Professional>[
    const Professional(
      id: 'pro-1',
      firstName: 'Dra. Ana',
      lastName: 'Silva',
      name: 'Dra. Ana Silva',
      specialty: 'Psicologia',
      institutionIds: ['inst-1'],
      active: true,
    ),
    const Professional(
      id: 'pro-2',
      firstName: 'Dr. Marcos',
      lastName: 'Pereira',
      name: 'Dr. Marcos Pereira',
      specialty: 'Neurologia',
      registrationNumber: 'CRM 123',
      institutionIds: ['inst-1'],
      active: true,
    ),
  ];
  final users = <AdminUser>[];
  final networks = <LocalNetwork>[];
  final parameters = <AdminParameter>[];

  final _institutions = StreamController<List<Institution>>.broadcast();
  final _professionals = StreamController<List<Professional>>.broadcast();
  final _users = StreamController<List<AdminUser>>.broadcast();
  final _networks = StreamController<List<LocalNetwork>>.broadcast();
  final _parameters = StreamController<List<AdminParameter>>.broadcast();

  @override
  Stream<List<Institution>> watchInstitutions() async* {
    yield List.unmodifiable(institutions);
    yield* _institutions.stream;
  }

  @override
  Stream<List<Professional>> watchProfessionals() async* {
    yield List.unmodifiable(professionals);
    yield* _professionals.stream;
  }

  @override
  Stream<List<AdminUser>> watchUsers() async* {
    yield List.unmodifiable(users);
    yield* _users.stream;
  }

  @override
  Stream<List<LocalNetwork>> watchLocalNetworks() async* {
    yield List.unmodifiable(networks);
    yield* _networks.stream;
  }

  @override
  Stream<List<AdminParameter>> watchParameters() async* {
    yield List.unmodifiable(parameters);
    yield* _parameters.stream;
  }

  @override
  Future<List<Institution>> getActiveInstitutions() async =>
      institutions.where((item) => item.active).toList();

  @override
  Future<List<Institution>> getInstitutions() async => List.of(institutions);

  @override
  Future<List<Professional>> getProfessionals() async => List.of(professionals);

  @override
  Future<List<AdminUser>> getUsers() async => List.of(users);

  @override
  Future<void> createUserProfile(
    String uid,
    UserFormData value, {
    required String actorUid,
  }) async {
    addUser(AdminUser(
      id: uid,
      firstName: value.firstName.trim(),
      lastName: value.lastName.trim(),
      name: value.fullName,
      email: value.normalizedEmail,
      role: value.role,
      schoolRole: value.schoolRole,
      active: value.active,
      professionalId: value.professionalId,
      createdBy: actorUid,
    ));
  }

  @override
  Future<void> updateUser(
    AdminUser user,
    UserFormData value, {
    required String actorUid,
  }) async {
    users.removeWhere((item) => item.id == user.id);
    addUser(AdminUser(
      id: user.id,
      firstName: value.firstName.trim(),
      lastName: value.lastName.trim(),
      name: value.fullName,
      email: user.email,
      role: value.role,
      schoolRole: value.schoolRole,
      active: value.active,
      professionalId: value.professionalId,
      createdAt: user.createdAt,
      updatedAt: DateTime.now(),
      lastAccessAt: user.lastAccessAt,
      createdBy: user.createdBy,
    ));
  }

  @override
  Future<void> deleteUser(
    AdminUser user, {
    required String actorUid,
  }) async {
    if (user.id == actorUid) {
      throw const AdminRepositoryException(
        'Você não pode excluir a própria conta administrativa.',
      );
    }
    users.removeWhere((item) => item.id == user.id);
    _users.add(List.unmodifiable(users));
  }

  @override
  Future<void> saveInstitution(Institution value,
      {required String actorUid}) async {
    final saved = Institution(
      id: value.id.isEmpty ? 'inst-${institutions.length + 1}' : value.id,
      name: value.name,
      type: value.type,
      address: value.address,
      active: value.active,
      cnpj: value.cnpj,
      email: value.email,
      phone: value.phone,
    );
    institutions.removeWhere((item) => item.id == saved.id);
    institutions.add(saved);
    _institutions.add(List.unmodifiable(institutions));
  }

  @override
  Future<void> saveProfessional(Professional value,
      {required String actorUid}) async {
    upsertProfessional(value);
  }

  void upsertProfessional(Professional value) {
    final saved = Professional(
      id: value.id.isEmpty ? 'pro-${professionals.length + 1}' : value.id,
      firstName: value.firstName,
      lastName: value.lastName,
      name: value.name,
      institutionIds: value.institutionIds,
      active: value.active,
      email: value.email,
      phone: value.phone,
      specialty: value.specialty,
      registrationNumber: value.registrationNumber,
      userId: value.userId,
    );
    professionals.removeWhere((item) => item.id == saved.id);
    professionals.add(saved);
    _professionals.add(List.unmodifiable(professionals));
  }

  @override
  Future<void> saveLocalNetwork(LocalNetwork value,
      {required String actorUid}) async {
    final saved = LocalNetwork(
      id: value.id.isEmpty ? 'network-${networks.length + 1}' : value.id,
      name: value.name,
      institutionIds: value.institutionIds,
      active: value.active,
      description: value.description,
    );
    networks.removeWhere((item) => item.id == saved.id);
    networks.add(saved);
    _networks.add(List.unmodifiable(networks));
  }

  @override
  Future<void> saveParameter(AdminParameter value,
      {required String actorUid}) async {
    final saved = AdminParameter(
      id: value.id.isEmpty ? 'parameter-${parameters.length + 1}' : value.id,
      title: value.title,
      items: value.items,
      active: value.active,
    );
    parameters.removeWhere((item) => item.id == saved.id);
    parameters.add(saved);
    _parameters.add(List.unmodifiable(parameters));
  }

  void addUser(AdminUser value) {
    users.add(value);
    _users.add(List.unmodifiable(users));
  }
}
