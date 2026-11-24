import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/case_models.dart';
import '../models/referral_models.dart';
import '../models/student_models.dart';
import 'case_repository.dart' show timelineLimit;

/// Consultas da família (P1-08), somente leitura e sempre filtradas pelo
/// estudante vinculado, como exigem as regras (docs/MODELO_DADOS.md §5).
abstract interface class FamilyRepository {
  Future<Student?> student(String studentId);
  Stream<List<StudentCase>> watchCases(String studentId);
  Stream<List<TimelineEvent>> watchTimeline(String caseId);
  Stream<List<Referral>> watchReferrals(String studentId);
  Stream<List<HealthReturn>> watchReturns(String studentId);
  Future<Map<String, String>> institutionNames(Iterable<String> ids);
}

class FirebaseFamilyRepository implements FamilyRepository {
  FirebaseFamilyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<Student?> student(String studentId) async {
    final doc = await _firestore.doc('students/$studentId').get();
    return doc.exists ? Student.fromFirestore(doc) : null;
  }

  @override
  Stream<List<StudentCase>> watchCases(String studentId) => _firestore
      .collection('cases')
      .where('studentId', isEqualTo: studentId)
      .where('familyVisible', isEqualTo: true)
      .snapshots()
      .map((e) {
        final list = e.docs.map(StudentCase.fromFirestore).toList()
          ..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
        return List.unmodifiable(list);
      });

  @override
  Stream<List<TimelineEvent>> watchTimeline(String caseId) => _firestore
      .collection('cases/$caseId/timelineEvents')
      .where('visibility', isEqualTo: 'familia')
      .orderBy('createdAt', descending: true)
      .limit(timelineLimit)
      .snapshots()
      .map((e) => List.unmodifiable(e.docs.map(TimelineEvent.fromFirestore)));

  @override
  Stream<List<Referral>> watchReferrals(String studentId) => _firestore
      .collection('referrals')
      .where('studentId', isEqualTo: studentId)
      .snapshots()
      .map((e) => List.unmodifiable(e.docs.map(Referral.fromFirestore)));

  @override
  Stream<List<HealthReturn>> watchReturns(String studentId) => _firestore
      .collection('healthReturns')
      .where('studentId', isEqualTo: studentId)
      .where('audience', arrayContains: 'family')
      .snapshots()
      .map((e) {
        final list = e.docs.map(HealthReturn.fromFirestore).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        return List.unmodifiable(list);
      });

  @override
  Future<Map<String, String>> institutionNames(Iterable<String> ids) async {
    final result = <String, String>{};
    for (final id in ids.toSet()) {
      try {
        final doc = await _firestore.doc('institutions/$id').get();
        result[id] = doc.data()?['name'] as String? ?? 'Instituição';
      } on FirebaseException {
        result[id] = 'Instituição';
      }
    }
    return result;
  }
}
