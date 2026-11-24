import 'package:cloud_firestore/cloud_firestore.dart';

/// Estudante (`students/{id}`, D-09). Sem conta no Authentication.
class Student {
  const Student({
    required this.id,
    required this.name,
    required this.schoolInstitutionId,
    required this.active,
    this.grade,
    this.familyUid,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? grade;
  final String schoolInstitutionId;
  final String? familyUid;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Student.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Student.fromMap(doc.id, doc.data() ?? const <String, dynamic>{});

  factory Student.fromMap(String id, Map<String, dynamic> data) {
    String? text(Object? value) {
      final result = value is String ? value.trim() : '';
      return result.isEmpty ? null : result;
    }

    DateTime? date(Object? value) => value is Timestamp ? value.toDate() : null;

    return Student(
      id: id,
      name: text(data['name']) ?? '',
      grade: text(data['grade']),
      schoolInstitutionId: text(data['schoolInstitutionId']) ?? '',
      familyUid: text(data['familyUid']),
      active: data['active'] == true,
      createdAt: date(data['createdAt']),
      updatedAt: date(data['updatedAt']),
    );
  }

  String get label => grade == null ? name : '$name • $grade';
}
