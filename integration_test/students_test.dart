// P1-19 — Cadastro de estudantes pela Direção escolar, contra o Emulator Suite.
// Executar com emuladores + seed:
//   flutter test integration_test/students_test.dart -d emulator-5554 \
//     --dart-define=USE_FIREBASE_EMULATORS=true
import 'package:caminho_azul/app/firebase_config.dart';
import 'package:caminho_azul/firebase_options.dart';
import 'package:caminho_azul/repositories/student_repository.dart';
import 'package:caminho_azul/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _password =
    String.fromEnvironment('SEED_PASSWORD', defaultValue: 'Sintetico#2026');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  late FirebaseStudentRepository repository;

  setUpAll(() async {
    if (!useFirebaseEmulators) {
      fail('Execute com --dart-define=USE_FIREBASE_EMULATORS=true');
    }
    await Firebase.initializeApp(
      options: firebaseOptionsFor(
        DefaultFirebaseOptions.currentPlatform,
        useEmulators: true,
      ),
    );
    await FirebaseAuth.instance.useAuthEmulator(firebaseEmulatorHost, 9099);
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: false);
    FirebaseFirestore.instance.useFirestoreEmulator(firebaseEmulatorHost, 8080);
    repository = FirebaseStudentRepository();
  });

  // Logout real do app (limpa o cache local do Firestore entre usuários).
  Future<AppUser> signInAs(String email) async {
    await FirebaseAuthService().signOut();
    return FirebaseAuthService().signIn(email: email, password: _password);
  }

  Matcher permissionDenied() => isA<FirebaseException>()
      .having((e) => e.code, 'code', 'permission-denied');

  testWidgets('Direção cadastra e edita; professor consulta; outra escola é '
      'negada', (tester) async {
    final name = 'Estudante Integração $stamp';

    final director = await signInAs('direcao.escola@caminhoazul.test');
    expect(director.schoolRole, SchoolRole.director);
    await repository.createStudent(
      schoolInstitutionId: 'seed-escola-a',
      name: name,
      grade: '4º ano',
      actorUid: director.uid,
    );
    var list = await repository.watchSchoolStudents('seed-escola-a').first;
    final created = list.singleWhere((s) => s.name == name);
    expect(created.familyUid, isNull);
    expect(created.active, isTrue);

    await expectLater(
      repository.createStudent(
        schoolInstitutionId: 'seed-escola-a',
        name: '  estudante integração $stamp ',
        actorUid: director.uid,
      ),
      throwsA(isA<StudentRepositoryException>()),
    );

    await repository.updateStudent(created,
        name: '$name (editado)', grade: '5º ano', active: true, actorUid: director.uid);
    list = await repository.watchSchoolStudents('seed-escola-a').first;
    expect(list.any((s) => s.name == '$name (editado)'), isTrue);

    // Professor da mesma escola: consulta, mas não cadastra.
    final teacher = await signInAs('professor@caminhoazul.test');
    list = await repository.watchSchoolStudents('seed-escola-a').first;
    expect(list.any((s) => s.id == created.id), isTrue);
    await expectLater(
      repository.createStudent(
        schoolInstitutionId: 'seed-escola-a',
        name: 'Não Permitido $stamp',
        actorUid: teacher.uid,
      ),
      throwsA(permissionDenied()),
    );

    // Professor e Direção de outra escola: negados.
    await signInAs('professor.b@caminhoazul.test');
    await expectLater(
      repository.watchSchoolStudents('seed-escola-a').first,
      throwsA(permissionDenied()),
    );
    final directorB = await signInAs('direcao.escola.b@caminhoazul.test');
    await expectLater(
      repository.createStudent(
        schoolInstitutionId: 'seed-escola-a',
        name: 'Outra Escola $stamp',
        actorUid: directorB.uid,
      ),
      throwsA(permissionDenied()),
    );
    await FirebaseAuthService().signOut();
  });
}
