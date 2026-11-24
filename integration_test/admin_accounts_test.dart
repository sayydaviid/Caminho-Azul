// P1-18 / P1-15 — Criação e ativação de contas pelo painel, contra o
// Firebase Emulator Suite (projeto demo-caminhoazul), usando os serviços reais.
//
// Pré-requisitos: emuladores ativos e seed recém-aplicado (scripts/seed_emulator.js).
// Executar:
//   flutter test integration_test/admin_accounts_test.dart -d emulator-5554 \
//     --dart-define=USE_FIREBASE_EMULATORS=true
import 'dart:convert';
import 'dart:io';

import 'package:caminho_azul/app/firebase_config.dart';
import 'package:caminho_azul/firebase_options.dart';
import 'package:caminho_azul/models/admin_models.dart';
import 'package:caminho_azul/repositories/admin_repository.dart';
import 'package:caminho_azul/services/admin_user_service.dart';
import 'package:caminho_azul/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _seedPassword =
    String.fromEnvironment('SEED_PASSWORD', defaultValue: 'Sintetico#2026');
const _newPassword = 'NovaSenha#Sintetica1';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  late String adminUid;
  late FirebaseAdminRepository repository;
  final userService = FirebaseAdminUserService();

  setUpAll(() async {
    // Trava de segurança: sem o modo emulador, a instância secundária do
    // Auth apontaria para o projeto remoto.
    if (!useFirebaseEmulators) {
      fail('Execute com --dart-define=USE_FIREBASE_EMULATORS=true');
    }
    final options = firebaseOptionsFor(
      DefaultFirebaseOptions.currentPlatform,
      useEmulators: true,
    );
    expect(options.projectId, emulatorProjectId);
    await Firebase.initializeApp(options: options);
    await FirebaseAuth.instance.useAuthEmulator(firebaseEmulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(firebaseEmulatorHost, 8080);
    repository = FirebaseAdminRepository();
    final admin = await FirebaseAuthService().signIn(
      email: 'admin@caminhoazul.test',
      password: _seedPassword,
    );
    expect(admin.role, UserRole.administration);
    adminUid = admin.uid;
  });

  Future<AdminAccountCreationResult> create(UserFormData value) {
    return userService.createAccount(
      email: value.normalizedEmail,
      displayName: value.fullName,
      createProfile: (uid) =>
          repository.createUserProfile(uid, value, actorUid: adminUid),
    );
  }

  UserFormData form(
    String key,
    UserRole role, {
    SchoolRole? schoolRole,
    HealthRole? healthRole,
    List<String> institutionIds = const [],
    String? studentId,
  }) {
    return UserFormData(
      firstName: 'Conta',
      lastName: 'Sintética $key',
      email: 'nova.$key.$stamp@caminhoazul.test',
      role: role,
      schoolRole: schoolRole,
      healthRole: healthRole,
      institutionIds: institutionIds,
      studentId: studentId,
      active: true,
    );
  }

  Future<List<Map<String, dynamic>>> oobCodes() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(
        'http://$firebaseEmulatorHost:9099/emulator/v1/projects/$emulatorProjectId/oobCodes',
      ));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      return (jsonDecode(body)['oobCodes'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
    } finally {
      client.close();
    }
  }

  // Instância separada para simular o novo usuário entrando (reutilizada).
  ({FirebaseAuth auth, FirebaseAuthService service})? verifyCache;
  Future<({FirebaseAuth auth, FirebaseAuthService service})>
      verifySession() async {
    final cached = verifyCache;
    if (cached != null) return cached;
    final app = await Firebase.initializeApp(
      name: 'verify-new-user',
      options: Firebase.app().options,
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator(firebaseEmulatorHost, 9099);
    final firestore = FirebaseFirestore.instanceFor(app: app);
    firestore.useFirestoreEmulator(firebaseEmulatorHost, 8080);
    return verifyCache = (
      auth: auth,
      service: FirebaseAuthService(firebaseAuth: auth, firestore: firestore),
    );
  }

  /// Usuário recebe o link (OOB), define a própria senha e entra.
  Future<AppUser> activateAndSignIn(String email) async {
    final code = (await oobCodes()).lastWhere(
      (item) => item['email'] == email && item['requestType'] == 'PASSWORD_RESET',
    )['oobCode'] as String;
    await FirebaseAuth.instance.confirmPasswordReset(
      code: code,
      newPassword: _newPassword,
    );
    final session = await verifySession();
    try {
      return await session.service.signIn(email: email, password: _newPassword);
    } finally {
      await session.auth.signOut();
    }
  }

  void expectNoSecrets(Map<String, dynamic>? data) {
    final keys = (data ?? const {}).toString().toLowerCase();
    expect(keys.contains('password'), isFalse);
    expect(keys.contains('senha'), isFalse);
    expect(keys.contains(_newPassword.toLowerCase()), isFalse);
  }

  testWidgets('admin cria os seis perfis sem perder a sessão; cada usuário '
      'ativa a conta definindo a própria senha', (tester) async {
    final cases = [
      form('admin', UserRole.administration),
      form('direcao', UserRole.school,
          schoolRole: SchoolRole.director, institutionIds: ['seed-escola-a']),
      form('professor', UserRole.school,
          schoolRole: SchoolRole.teacher, institutionIds: ['seed-escola-a']),
      form('direcao-ubs', UserRole.health,
          healthRole: HealthRole.ubsDirector, institutionIds: ['seed-ubs-a']),
      form('psicologo', UserRole.health,
          healthRole: HealthRole.psychologist, institutionIds: ['seed-ubs-a']),
      form('familia', UserRole.family, studentId: 'seed-estudante-2'),
    ];
    final firestore = FirebaseFirestore.instance;

    for (final value in cases) {
      final result = await create(value);
      expect(result.invitationSent, isTrue, reason: value.email);
      // Sessão do administrador preservada.
      expect(FirebaseAuth.instance.currentUser?.uid, adminUid);

      final user = await firestore.doc('users/${result.uid}').get();
      expect(user.exists, isTrue);
      expect(user.get('role'), value.role.value);
      expect(user.get('schoolRole'), value.schoolRoleValue);
      expect(user.get('healthRole'), value.healthRoleValue);
      expect(user.get('createdBy'), adminUid);
      expectNoSecrets(user.data());
      if (value.isOperational) {
        expect(user.get('institutionIds'), value.institutionIds);
        final professional = await firestore
            .doc('professionals/${user.get('professionalId')}')
            .get();
        expect(professional.get('userId'), result.uid);
        expect(professional.get('institutionIds'), value.institutionIds);
      }
      if (value.role == UserRole.family) {
        expect(user.get('studentIds'), [value.studentId]);
        final student = await firestore.doc('students/${value.studentId}').get();
        expect(student.get('familyUid'), result.uid);
      }
      final audit = await firestore
          .collection('adminAuditLogs')
          .where('targetId', isEqualTo: result.uid)
          .get();
      expect(audit.docs, isNotEmpty);
      for (final log in audit.docs) {
        expectNoSecrets(log.data());
      }

      final activated = await activateAndSignIn(value.normalizedEmail);
      expect(activated.uid, result.uid);
      expect(activated.role, value.role);
      expect(FirebaseAuth.instance.currentUser?.uid, adminUid);
    }
  });

  testWidgets('e-mail duplicado é recusado', (tester) async {
    const value = UserFormData(
      firstName: 'Duplicado',
      lastName: 'Sintético',
      email: 'professor@caminhoazul.test',
      role: UserRole.school,
      schoolRole: SchoolRole.teacher,
      institutionIds: ['seed-escola-a'],
      active: true,
    );
    await expectLater(create(value), throwsA(isA<AdminUserServiceException>()));
    expect(FirebaseAuth.instance.currentUser?.uid, adminUid);
  });

  testWidgets('falha ao gravar o perfil desfaz a identidade criada no Auth',
      (tester) async {
    final email = 'rollback.$stamp@caminhoazul.test';
    // Estudante já vinculado a outra família: o perfil não pode ser gravado.
    final invalid = UserFormData(
      firstName: 'Rollback',
      lastName: 'Sintético',
      email: email,
      role: UserRole.family,
      studentId: 'seed-estudante-1',
      active: true,
    );
    await expectLater(create(invalid), throwsA(isA<AdminRepositoryException>()));
    expect(FirebaseAuth.instance.currentUser?.uid, adminUid);
    // A identidade foi removida: o mesmo e-mail pode ser cadastrado de novo.
    final valid = UserFormData(
      firstName: 'Rollback',
      lastName: 'Sintético',
      email: email,
      role: UserRole.school,
      schoolRole: SchoolRole.teacher,
      institutionIds: const ['seed-escola-a'],
      active: true,
    );
    final result = await create(valid);
    expect(result.uid, isNotEmpty);
  });

  testWidgets('reenvio da ativação gera novo link sem trocar a sessão',
      (tester) async {
    final before = (await oobCodes())
        .where((item) => item['email'] == 'professor@caminhoazul.test')
        .length;
    await userService.sendActivation('professor@caminhoazul.test');
    final after = (await oobCodes())
        .where((item) => item['email'] == 'professor@caminhoazul.test')
        .length;
    expect(after, before + 1);
    expect(FirebaseAuth.instance.currentUser?.uid, adminUid);
  });

  testWidgets('"Excluir usuário" desativa a conta: login bloqueado, histórico preservado',
      (tester) async {
    final value = form('desativar', UserRole.school,
        schoolRole: SchoolRole.teacher, institutionIds: ['seed-escola-a']);
    final result = await create(value);
    await activateAndSignIn(value.normalizedEmail);
    final user = (await repository.getUsers()).firstWhere((u) => u.id == result.uid);
    await repository.deleteUser(user, actorUid: adminUid);

    final doc = await FirebaseFirestore.instance.doc('users/${result.uid}').get();
    expect(doc.exists, isTrue);
    expect(doc.get('active'), isFalse);
    expect(doc.get('professionalId'), isNotNull);
    // D-A06: o profissional sai das listas de atribuição/vínculo.
    final professional = await FirebaseFirestore.instance
        .doc('professionals/${doc.get('professionalId')}')
        .get();
    expect(professional.get('active'), isFalse);
    final audit = await FirebaseFirestore.instance
        .collection('adminAuditLogs')
        .where('targetId', isEqualTo: result.uid)
        .where('action', isEqualTo: 'user.deactivate')
        .get();
    expect(audit.docs, hasLength(1));
    await expectLater(
      (await verifySession()).service.signIn(
          email: value.normalizedEmail, password: _newPassword),
      throwsA(isA<AuthException>()),
    );
    expect(FirebaseAuth.instance.currentUser?.uid, adminUid);
  });
}
