import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/student_models.dart';

class StudentRepositoryException implements Exception {
  const StudentRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Estudantes da escola (P1-19). Consultas sempre filtradas por
/// `schoolInstitutionId`, como exigem as regras (docs/MODELO_DADOS.md §5).
abstract interface class StudentRepository {
  /// Paginada por nome (P2-12).
  Stream<List<Student>> watchSchoolStudents(String schoolInstitutionId,
      {int limit = 30});
  Future<Map<String, String>> institutionNames(List<String> ids);
  Future<void> createStudent({
    required String schoolInstitutionId,
    required String name,
    required String actorUid,
    String? grade,
  });
  Future<void> updateStudent(
    Student student, {
    required String name,
    required bool active,
    required String actorUid,
    String? grade,
  });
}

class FirebaseStudentRepository implements StudentRepository {
  FirebaseStudentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _students =>
      _firestore.collection('students');

  @override
  Stream<List<Student>> watchSchoolStudents(String schoolInstitutionId,
          {int limit = 30}) =>
      _students
          .where('schoolInstitutionId', isEqualTo: schoolInstitutionId)
          .orderBy('name')
          .limit(limit)
          .snapshots()
          .map((event) => List.unmodifiable(
                event.docs.map(Student.fromFirestore),
              ));

  @override
  Future<Map<String, String>> institutionNames(List<String> ids) async {
    final result = <String, String>{};
    for (final id in ids) {
      try {
        final doc = await _firestore.doc('institutions/$id').get();
        result[id] = (doc.data()?['name'] as String?) ?? id;
      } on FirebaseException {
        result[id] = id;
      }
    }
    return result;
  }

  @override
  Future<void> createStudent({
    required String schoolInstitutionId,
    required String name,
    required String actorUid,
    String? grade,
  }) async {
    final normalized = _normalizedName(name);
    final existing = await _students
        .where('schoolInstitutionId', isEqualTo: schoolInstitutionId)
        .get();
    final duplicate = existing.docs.any((doc) =>
        _normalizedName(doc.data()['name'] as String? ?? '') == normalized);
    if (duplicate) {
      throw const StudentRepositoryException(
        'Já existe um estudante com este nome nesta escola.',
      );
    }
    await _students.add({
      'name': name.trim(),
      'grade': _optional(grade),
      'schoolInstitutionId': schoolInstitutionId,
      'familyUid': null,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': actorUid,
      'updatedBy': actorUid,
    });
  }

  @override
  Future<void> updateStudent(
    Student student, {
    required String name,
    required bool active,
    required String actorUid,
    String? grade,
  }) {
    return _students.doc(student.id).update({
      'name': name.trim(),
      'grade': _optional(grade),
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
    });
  }

  static String _normalizedName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String? _optional(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
