import 'dart:async';

import 'package:caminho_azul/models/student_models.dart';
import 'package:caminho_azul/repositories/student_repository.dart';
import 'package:caminho_azul/screens/estudantes_screen.dart';
import 'package:caminho_azul/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStudentRepository implements StudentRepository {
  final students = <Student>[];
  final _controller = StreamController<List<Student>>.broadcast();
  Object? error;
  int createCalls = 0;

  void _emit() => _controller.add(List.unmodifiable(students));

  @override
  Stream<List<Student>> watchSchoolStudents(String schoolInstitutionId,
      {int limit = 30}) async* {
    if (error != null) throw error!;
    yield List.unmodifiable(students);
    yield* _controller.stream;
  }

  @override
  Future<Map<String, String>> institutionNames(List<String> ids) async =>
      {for (final id in ids) id: 'Escola Sintética'};

  @override
  Future<void> createStudent({
    required String schoolInstitutionId,
    required String name,
    required String actorUid,
    String? grade,
  }) async {
    createCalls++;
    if (students.any((s) => s.name.toLowerCase() == name.trim().toLowerCase())) {
      throw const StudentRepositoryException(
          'Já existe um estudante com este nome nesta escola.');
    }
    students.add(Student(
      id: 's${students.length + 1}',
      name: name.trim(),
      grade: grade,
      schoolInstitutionId: schoolInstitutionId,
      active: true,
    ));
    _emit();
  }

  @override
  Future<void> updateStudent(
    Student student, {
    required String name,
    required bool active,
    required String actorUid,
    String? grade,
  }) async {
    final index = students.indexWhere((s) => s.id == student.id);
    students[index] = Student(
      id: student.id,
      name: name.trim(),
      grade: grade,
      schoolInstitutionId: student.schoolInstitutionId,
      active: active,
    );
    _emit();
  }
}

AppUser _user(SchoolRole role) => AppUser(
      uid: 'u1',
      email: 'u1@caminhoazul.test',
      name: 'Pessoa Sintética',
      role: UserRole.school,
      schoolRole: role,
      professionalId: 'p1',
      institutionIds: const ['escola-a'],
    );

Future<void> _pump(WidgetTester tester, AppUser user, StudentRepository repo) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(body: EstudantesScreen(user: user, repository: repo)),
  ));
}

void main() {
  testWidgets('Direção cadastra, edita e não duplica estudantes',
      (tester) async {
    final repo = FakeStudentRepository();
    await _pump(tester, _user(SchoolRole.director), repo);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('students-empty')), findsOneWidget);

    Future<void> create(String name) async {
      await tester.tap(find.byKey(const Key('students-new-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('student-form-name')), name);
      await tester.enterText(
          find.byKey(const Key('student-form-grade')), '3º ano A');
      await tester.tap(find.byKey(const Key('student-form-submit')));
      await tester.pumpAndSettle();
    }

    await create('Estudante Sintético');
    expect(find.text('Estudante cadastrado com sucesso.'), findsOneWidget);
    expect(find.text('Estudante Sintético'), findsOneWidget);

    await create('estudante sintético');
    expect(find.text('Já existe um estudante com este nome nesta escola.'),
        findsOneWidget);
    expect(repo.students, hasLength(1));
    Navigator.of(tester.element(find.byKey(const Key('student-form-name'))))
        .pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('students-edit-s1')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('student-form-name')), 'Estudante Renomeado');
    await tester.tap(find.byKey(const Key('student-form-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Estudante Renomeado'), findsOneWidget);
  });

  testWidgets('nome obrigatório e envio único', (tester) async {
    final repo = FakeStudentRepository();
    await _pump(tester, _user(SchoolRole.director), repo);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('students-new-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-form-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Informe o nome do estudante.'), findsOneWidget);
    expect(repo.createCalls, 0);
  });

  testWidgets('professor só consulta e busca', (tester) async {
    final repo = FakeStudentRepository()
      ..students.addAll(const [
        Student(id: 's1', name: 'Ana Sintética', schoolInstitutionId: 'escola-a', active: true),
        Student(id: 's2', name: 'Bruno Sintético', schoolInstitutionId: 'escola-a', active: true),
      ]);
    await _pump(tester, _user(SchoolRole.teacher), repo);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('students-new-button')), findsNothing);
    expect(find.byTooltip('Editar estudante'), findsNothing);
    await tester.enterText(find.byKey(const Key('students-search')), 'bruno');
    await tester.pumpAndSettle();
    expect(find.text('Bruno Sintético'), findsOneWidget);
    expect(find.text('Ana Sintética'), findsNothing);
  });

  testWidgets('erro de carregamento oferece nova tentativa', (tester) async {
    final repo = FakeStudentRepository()..error = Exception('falha');
    await _pump(tester, _user(SchoolRole.director), repo);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('students-error')), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}
