import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/case_models.dart';
import '../models/referral_models.dart';
import '../models/student_models.dart';
import '../services/auth_service.dart';
import 'notification_repository.dart';

class CaseRepositoryException implements Exception {
  const CaseRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Casos (P1-01). Toda alteração grava `lastEventId` e o evento imutável no
/// mesmo batch, como exigem as regras (docs/MODELO_DADOS.md §4).
abstract interface class CaseRepository {
  /// Listas paginadas (P2-12): os [limit] casos atualizados mais recentemente.
  Stream<List<StudentCase>> watchTeacherCases(AppUser teacher, String schoolId,
      {int limit = 30});
  Stream<List<StudentCase>> watchSchoolCases(String schoolId, {int limit = 30});
  Stream<StudentCase?> watchCase(String caseId);
  Stream<List<TimelineEvent>> watchSchoolTimeline(String caseId);
  Future<String> createCase(AppUser teacher, Student student);
  Future<void> submitCase(AppUser teacher, StudentCase value);

  // P1-03 / P1-04 — conteúdo pedagógico interno.
  Stream<List<Observation>> watchObservations(String caseId);
  Future<void> addObservation(
    AppUser teacher,
    StudentCase value, {
    required String context,
    required String description,
    required DateTime observedAt,
  });
  Stream<List<PedagogicalRecord>> watchRecords(String caseId);
  Future<void> addRecord(
    AppUser teacher,
    StudentCase value, {
    required String summary,
    required List<String> actions,
    required List<String> observationIds,
  });

  // P1-02 — professores vinculados ao caso (Direção escolar).
  Future<List<StaffOption>> teachersOf(String schoolId);
  Future<void> updateTeachers(
    AppUser director,
    StudentCase value, {
    required List<String> teacherUids,
    required String primaryTeacherUid,
  });
}

class FirebaseCaseRepository implements CaseRepository {
  FirebaseCaseRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _cases =>
      _firestore.collection('cases');

  List<StudentCase> _map(QuerySnapshot<Map<String, dynamic>> event) =>
      List.unmodifiable(event.docs.map(StudentCase.fromFirestore));

  @override
  Stream<List<StudentCase>> watchTeacherCases(
          AppUser teacher, String schoolId, {int limit = 30}) =>
      _cases
          .where('schoolInstitutionId', isEqualTo: schoolId)
          .where('teacherUids', arrayContains: teacher.uid)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(_map);

  @override
  Stream<List<StudentCase>> watchSchoolCases(String schoolId, {int limit = 30}) =>
      _cases
          .where('schoolInstitutionId', isEqualTo: schoolId)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(_map);

  @override
  Stream<StudentCase?> watchCase(String caseId) => _cases
      .doc(caseId)
      .snapshots()
      .map((doc) => doc.exists ? StudentCase.fromFirestore(doc) : null);

  /// Linha do tempo da escola: eventos `familia` e `interno`, mais os
  /// `restrito` destinados à escola (duas consultas, como exigem as regras).
  @override
  Stream<List<TimelineEvent>> watchSchoolTimeline(String caseId) {
    final events = _cases.doc(caseId).collection('timelineEvents');
    return mergeTimelines([
      events
          .where('visibility', whereIn: ['familia', 'interno'])
          .orderBy('createdAt', descending: true)
          .limit(timelineLimit)
          .snapshots(),
      events
          .where('visibility', isEqualTo: 'restrito')
          .where('audience', arrayContains: 'school')
          .orderBy('createdAt', descending: true)
          .limit(timelineLimit)
          .snapshots(),
    ]);
  }

  @override
  Future<String> createCase(AppUser teacher, Student student) async {
    if (teacher.schoolRole != SchoolRole.teacher) {
      throw const CaseRepositoryException(
          'Somente professores registram novos casos.');
    }
    if (!student.active) {
      throw const CaseRepositoryException('O estudante está inativo.');
    }
    final caseRef = _cases.doc();
    final eventRef = caseRef.collection('timelineEvents').doc();
    final batch = _firestore.batch()
      ..set(caseRef, {
        'studentId': student.id,
        'studentName': student.name,
        'schoolInstitutionId': student.schoolInstitutionId,
        'primaryTeacherUid': teacher.uid,
        'teacherUids': [teacher.uid],
        'status': CaseStatus.draft.value,
        'familyVisible': false,
        'complementOpen': false,
        'approvedAt': null,
        'approvedBy': null,
        'activeReferrals': <String, String>{},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': teacher.uid,
        'updatedBy': teacher.uid,
        'lastEventId': eventRef.id,
      })
      ..set(eventRef, eventData(teacher, TimelineEventType.caseCreated))
      // P2-06 (RN-20): trava de um caso em andamento por estudante. As regras
      // só aceitam o caso junto da trava e só a reocupam após a conclusão.
      ..set(_firestore.collection('caseLocks').doc(student.id), {
        'caseId': caseRef.id,
        'schoolInstitutionId': student.schoolInstitutionId,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': teacher.uid,
      });
    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' && await _hasOpenCase(student.id)) {
        throw const CaseRepositoryException(
            'Este estudante já possui um caso em andamento.');
      }
      rethrow;
    }
    return caseRef.id;
  }

  /// A trava existe e aponta para um caso não concluído (ou ilegível).
  Future<bool> _hasOpenCase(String studentId) async {
    try {
      final lock =
          await _firestore.collection('caseLocks').doc(studentId).get();
      final caseId = lock.data()?['caseId'];
      if (caseId is! String) return false;
      try {
        final existing = await _cases.doc(caseId).get();
        return existing.data()?['status'] != CaseStatus.concluded.value;
      } on FirebaseException {
        return true; // caso de outro professor: existe e não é legível
      }
    } on FirebaseException {
      return false;
    }
  }

  @override
  Future<void> submitCase(AppUser teacher, StudentCase value) async {
    final type = switch (value.status) {
      CaseStatus.draft => TimelineEventType.caseSubmitted,
      CaseStatus.complementRequested => TimelineEventType.caseComplemented,
      _ => throw const CaseRepositoryException(
          'Este caso não está aguardando envio pelo professor.'),
    };
    await transition(
      teacher,
      value,
      {'status': CaseStatus.awaitingReview.value},
      type,
    );
  }

  @override
  Stream<List<Observation>> watchObservations(String caseId) => _cases
      .doc(caseId)
      .collection('observations')
      .orderBy('observedAt', descending: true)
      .snapshots()
      .map((event) =>
          List.unmodifiable(event.docs.map(Observation.fromFirestore)));

  @override
  Future<void> addObservation(
    AppUser teacher,
    StudentCase value, {
    required String context,
    required String description,
    required DateTime observedAt,
  }) async {
    _requireSchoolContent(value);
    final caseRef = _cases.doc(value.id);
    final ref = caseRef.collection('observations').doc();
    final batch = _firestore.batch()
      ..set(ref, {
        'authorUid': teacher.uid,
        'authorName': teacher.name ?? '',
        'context': context.trim(),
        'description': description.trim(),
        'observedAt': Timestamp.fromDate(observedAt),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..set(caseRef.collection('timelineEvents').doc(),
          eventData(teacher, TimelineEventType.observationCreated, refId: ref.id));
    await batch.commit();
  }

  @override
  Stream<List<PedagogicalRecord>> watchRecords(String caseId) => _cases
      .doc(caseId)
      .collection('pedagogicalRecords')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((event) =>
          List.unmodifiable(event.docs.map(PedagogicalRecord.fromFirestore)));

  @override
  Future<void> addRecord(
    AppUser teacher,
    StudentCase value, {
    required String summary,
    required List<String> actions,
    required List<String> observationIds,
  }) async {
    _requireSchoolContent(value);
    final cleanActions = actions
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .take(20)
        .toList();
    final caseRef = _cases.doc(value.id);
    final ref = caseRef.collection('pedagogicalRecords').doc();
    final batch = _firestore.batch()
      ..set(ref, {
        'authorUid': teacher.uid,
        'authorName': teacher.name ?? '',
        'summary': summary.trim(),
        'actions': cleanActions,
        'observationIds': observationIds.take(50).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..set(caseRef.collection('timelineEvents').doc(),
          eventData(teacher, TimelineEventType.pedagogicalRecordCreated, refId: ref.id));
    await batch.commit();
  }

  @override
  Future<List<StaffOption>> teachersOf(String schoolId) async {
    final snapshot = await _firestore
        .collection('professionals')
        .where('active', isEqualTo: true)
        .where('institutionIds', arrayContains: schoolId)
        .where('subrole', isEqualTo: 'teacher')
        .get();
    return snapshot.docs
        .where((d) => d.data()['userId'] is String)
        .map((d) => StaffOption(
              uid: d.data()['userId'] as String,
              name: d.data()['name'] as String? ?? '',
            ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<void> updateTeachers(
    AppUser director,
    StudentCase value, {
    required List<String> teacherUids,
    required String primaryTeacherUid,
  }) async {
    if (director.schoolRole != SchoolRole.director) {
      throw const CaseRepositoryException(
          'Somente a Direção escolar altera os professores do caso.');
    }
    if (value.status == CaseStatus.concluded) {
      throw const CaseRepositoryException('O caso já foi concluído.');
    }
    final unique = teacherUids.toSet().toList();
    if (unique.isEmpty || unique.length > 10) {
      throw const CaseRepositoryException(
          'Vincule de 1 a 10 professores ao caso.');
    }
    if (!unique.contains(primaryTeacherUid)) {
      throw const CaseRepositoryException(
          'O responsável principal precisa estar entre os vinculados.');
    }
    await transition(
      director,
      value,
      {'teacherUids': unique, 'primaryTeacherUid': primaryTeacherUid},
      TimelineEventType.caseTeachersUpdated,
    );
  }

  void _requireSchoolContent(StudentCase value) {
    if (!value.acceptsSchoolContent) {
      throw const CaseRepositoryException(
        'O caso não está aberto para novos registros pedagógicos.',
      );
    }
  }

  /// Atualiza o caso e grava o evento correspondente no mesmo batch.
  Future<void> transition(
    AppUser actor,
    StudentCase value,
    Map<String, Object?> changes,
    String type, {
    WriteBatch? batch,
    String? referralId,
    String? eventId,
  }) async {
    final caseRef = _cases.doc(value.id);
    final eventRef =
        caseRef.collection('timelineEvents').doc(eventId ?? caseRef.collection('timelineEvents').doc().id);
    final effectiveBatch = batch ?? _firestore.batch();
    effectiveBatch
      ..update(caseRef, {
        ...changes,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actor.uid,
        'lastEventId': eventRef.id,
      })
      ..set(eventRef, eventData(actor, type, referralId: referralId));
    // N-03: notificação da família no mesmo batch do evento.
    addFamilyNotification(effectiveBatch, _firestore,
        caseId: value.id,
        studentId: value.studentId,
        eventId: eventRef.id,
        type: type,
        visibility: TimelineEventType.visibilityOf(type),
        actorUid: actor.uid,
        referralId: referralId);
    if (batch == null) await effectiveBatch.commit();
  }
}

/// Documento de evento no formato validado pelas regras.
Map<String, Object?> eventData(
  AppUser actor,
  String type, {
  String? referralId,
  String? refId,
  String? visibility,
  List<String> audience = const [],
}) =>
    {
      'type': type,
      'visibility': visibility ?? TimelineEventType.visibilityOf(type),
      'audience': audience,
      'referralId': referralId,
      'refId': refId,
      'actorUid': actor.uid,
      'actorName': actor.name ?? '',
      'actorRole': actorRoleOf(actor),
      'createdAt': FieldValue.serverTimestamp(),
    };

/// Limite de eventos por consulta (RNF10).
const timelineLimit = 200;

/// Junta consultas de eventos em uma lista única, ordenada do mais recente.
Stream<List<TimelineEvent>> mergeTimelines(
    List<Stream<QuerySnapshot<Map<String, dynamic>>>> sources) {
  final latest = List<List<TimelineEvent>?>.filled(sources.length, null);
  final subscriptions = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
  late final StreamController<List<TimelineEvent>> controller;
  void emit() {
    if (latest.any((l) => l == null)) return;
    final byId = <String, TimelineEvent>{
      for (final list in latest)
        for (final event in list!) event.id: event,
    };
    final all = byId.values.toList()
      ..sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    controller.add(List.unmodifiable(all));
  }

  controller = StreamController<List<TimelineEvent>>(
    onListen: () {
      for (var i = 0; i < sources.length; i++) {
        subscriptions.add(sources[i].listen(
          (snapshot) {
            latest[i] = snapshot.docs.map(TimelineEvent.fromFirestore).toList();
            emit();
          },
          onError: controller.addError,
        ));
      }
    },
    onCancel: () async {
      for (final s in subscriptions) {
        await s.cancel();
      }
    },
  );
  return controller.stream;
}
