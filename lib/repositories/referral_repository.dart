import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/case_models.dart';
import '../models/referral_models.dart';
import '../services/auth_service.dart';
import 'case_repository.dart';
import 'notification_repository.dart';

class ReferralRepositoryException implements Exception {
  const ReferralRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Encaminhamentos, notas restritas e devolutivas (P1-05, P1-16, P1-06).
/// Cada transição grava encaminhamento + evento (+ nota/caso) no mesmo batch,
/// conforme docs/MODELO_DADOS.md §4. Consultas seguem o §5.
abstract interface class ReferralRepository {
  // Leituras.
  Stream<List<Referral>> watchSchoolCaseReferrals(String caseId, String schoolId);
  /// Listas paginadas (P2-12): os [limit] mais recentes.
  Stream<List<Referral>> watchUbsReferrals(String ubsId, {int limit = 30});
  Stream<List<Referral>> watchPsychologistReferrals(String uid, {int limit = 30});
  Stream<Referral?> watchReferral(String referralId);
  Future<ReferralDetails?> getDetails(String referralId);
  Stream<List<ReferralNote>> watchNotes(String referralId, String audience);
  /// Com [caseId], a consulta também serve ao professor vinculado (a regra
  /// do professor depende do caso).
  Stream<List<HealthReturn>> watchReturnsForReferral(
      String referralId, {String? audience, String? caseId});
  Stream<List<TimelineEvent>> watchReferralTimeline(String caseId, String referralId);
  Future<List<InstitutionOption>> activeUbs();
  Future<List<StaffOption>> psychologistsOf(String ubsId);
  Future<Map<String, String>> institutionNames(Iterable<String> ids);

  // Direção escolar (P1-05).
  Future<void> requestSchoolComplement(AppUser director, StudentCase value);
  Future<void> approve(AppUser director, StudentCase value);
  Future<String> send(
    AppUser director,
    StudentCase value, {
    required String ubsId,
    required String reason,
    required String summary,
  });
  Future<void> conclude(AppUser director, StudentCase value);
  Future<void> forwardComplementToTeacher(AppUser director, StudentCase value);
  Future<void> answerUbsComplement(
    AppUser director,
    StudentCase value,
    Referral referral,
    String text,
  );

  // Direção da UBS (P1-16).
  Future<void> receive(AppUser ubsDirector, Referral referral);
  Future<void> assign(AppUser ubsDirector, Referral referral, StaffOption psychologist,
      {required bool caseNeedsFollowUp});
  Future<void> requestUbsComplement(AppUser ubsDirector, Referral referral, String text);
  Future<void> returnReferral(AppUser ubsDirector, Referral referral, String text);
  Future<void> refuse(AppUser ubsDirector, Referral referral, String text);
  Future<void> finalize(AppUser ubsDirector, Referral referral);

  // Psicólogo (P1-06).
  Future<void> startAttendance(AppUser psychologist, Referral referral);
  Future<void> addProgressNote(AppUser psychologist, Referral referral, String text);
  Future<void> registerReturn(
    AppUser psychologist,
    Referral referral, {
    required String content,
    required List<String> audience,
  });
}

class FirebaseReferralRepository implements ReferralRepository {
  FirebaseReferralRepository({
    FirebaseFirestore? firestore,
    FirebaseCaseRepository? cases,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _cases = cases ?? FirebaseCaseRepository(firestore: firestore);

  final FirebaseFirestore _firestore;
  final FirebaseCaseRepository _cases;

  CollectionReference<Map<String, dynamic>> get _referrals =>
      _firestore.collection('referrals');

  List<Referral> _map(QuerySnapshot<Map<String, dynamic>> e) =>
      List.unmodifiable(e.docs.map(Referral.fromFirestore));

  // ------------------------------------------------------------- leituras

  @override
  Stream<List<Referral>> watchSchoolCaseReferrals(String caseId, String schoolId) =>
      _referrals
          .where('caseId', isEqualTo: caseId)
          .where('originInstitutionId', isEqualTo: schoolId)
          .snapshots()
          .map(_map);

  @override
  Stream<List<Referral>> watchUbsReferrals(String ubsId, {int limit = 30}) => _referrals
      .where('destinationInstitutionId', isEqualTo: ubsId)
      .orderBy('updatedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(_map);

  @override
  Stream<List<Referral>> watchPsychologistReferrals(String uid, {int limit = 30}) =>
      _referrals
          .where('assignedPsychologistUid', isEqualTo: uid)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(_map);

  @override
  Stream<Referral?> watchReferral(String referralId) => _referrals
      .doc(referralId)
      .snapshots()
      .map((d) => d.exists ? Referral.fromFirestore(d) : null);

  @override
  Future<ReferralDetails?> getDetails(String referralId) async {
    final doc = await _referrals.doc(referralId).collection('private').doc('details').get();
    final data = doc.data();
    if (data == null) return null;
    return ReferralDetails(
      reason: data['reason'] as String? ?? '',
      summary: data['summary'] as String? ?? '',
    );
  }

  @override
  Stream<List<ReferralNote>> watchNotes(String referralId, String audience) =>
      _referrals
          .doc(referralId)
          .collection('notes')
          .where('audience', arrayContains: audience)
          .snapshots()
          .map((e) {
        final notes = e.docs.map(ReferralNote.fromFirestore).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        return List.unmodifiable(notes);
      });

  @override
  Stream<List<HealthReturn>> watchReturnsForReferral(String referralId,
      {String? audience, String? caseId}) {
    Query<Map<String, dynamic>> query =
        _firestore.collection('healthReturns').where('referralId', isEqualTo: referralId);
    if (caseId != null) query = query.where('caseId', isEqualTo: caseId);
    if (audience != null) query = query.where('audience', arrayContains: audience);
    return query.snapshots().map((e) {
      final items = e.docs.map(HealthReturn.fromFirestore).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return List.unmodifiable(items);
    });
  }

  @override
  Stream<List<TimelineEvent>> watchReferralTimeline(String caseId, String referralId) =>
      _firestore
          .collection('cases')
          .doc(caseId)
          .collection('timelineEvents')
          .where('referralId', isEqualTo: referralId)
          .where('visibility', isEqualTo: 'familia')
          .orderBy('createdAt', descending: true)
          .limit(timelineLimit)
          .snapshots()
          .map((e) => List.unmodifiable(e.docs.map(TimelineEvent.fromFirestore)));

  @override
  Future<List<InstitutionOption>> activeUbs() async {
    final snapshot = await _firestore
        .collection('institutions')
        .where('active', isEqualTo: true)
        .where('type', isEqualTo: 'ubs')
        .get();
    final list = snapshot.docs
        .map((d) => InstitutionOption(id: d.id, name: d.data()['name'] as String? ?? d.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<List<StaffOption>> psychologistsOf(String ubsId) async {
    final snapshot = await _firestore
        .collection('professionals')
        .where('active', isEqualTo: true)
        .where('institutionIds', arrayContains: ubsId)
        .where('subrole', isEqualTo: 'psychologist')
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
  Future<Map<String, String>> institutionNames(Iterable<String> ids) async {
    final result = <String, String>{};
    for (final id in ids.toSet()) {
      try {
        final doc = await _firestore.doc('institutions/$id').get();
        result[id] = doc.data()?['name'] as String? ?? id;
      } on FirebaseException {
        result[id] = id;
      }
    }
    return result;
  }

  // ------------------------------------------------------ Direção escolar

  @override
  Future<void> requestSchoolComplement(AppUser director, StudentCase value) =>
      _cases.transition(director, value,
          {'status': CaseStatus.complementRequested.value},
          TimelineEventType.caseComplementRequested);

  @override
  Future<void> approve(AppUser director, StudentCase value) async {
    if (value.status != CaseStatus.awaitingReview) {
      throw const ReferralRepositoryException('O caso não está aguardando análise.');
    }
    await _cases.transition(director, value, {
      'status': CaseStatus.approved.value,
      'familyVisible': true,
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': director.uid,
    }, TimelineEventType.caseApproved);
  }

  @override
  Future<String> send(
    AppUser director,
    StudentCase value, {
    required String ubsId,
    required String reason,
    required String summary,
  }) async {
    const allowed = {CaseStatus.approved, CaseStatus.referred, CaseStatus.inFollowUp};
    if (!allowed.contains(value.status)) {
      throw const ReferralRepositoryException(
          'Aprove o caso antes de encaminhá-lo à UBS.');
    }
    if (value.activeReferrals.containsValue(ubsId)) {
      throw const ReferralRepositoryException(
          'Já existe um encaminhamento ativo para esta UBS.');
    }
    final ref = _referrals.doc();
    final eventId = _firestore.collection('cases').doc(value.id)
        .collection('timelineEvents').doc().id;
    final batch = _firestore.batch()
      ..set(ref, {
        'caseId': value.id,
        'studentId': value.studentId,
        'studentName': value.studentName,
        'originInstitutionId': value.schoolInstitutionId,
        'destinationInstitutionId': ubsId,
        'status': ReferralStatus.sent.value,
        'previousStatus': null,
        'assignedPsychologistUid': null,
        'assignedPsychologistName': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': director.uid,
        'updatedBy': director.uid,
        'lastEventId': eventId,
      })
      ..set(ref.collection('private').doc('details'), {
        'reason': reason.trim(),
        'summary': summary.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': director.uid,
      });
    await _cases.transition(
      director,
      value,
      {
        'activeReferrals.${ref.id}': ubsId,
        if (value.status == CaseStatus.approved) 'status': CaseStatus.referred.value,
      },
      TimelineEventType.referralSent,
      batch: batch,
      referralId: ref.id,
      eventId: eventId,
    );
    await batch.commit();
    return ref.id;
  }

  @override
  Future<void> conclude(AppUser director, StudentCase value) async {
    if (value.activeReferrals.isNotEmpty) {
      throw const ReferralRepositoryException(
          'Há encaminhamentos ativos. Aguarde a finalização pela UBS.');
    }
    await _cases.transition(director, value,
        {'status': CaseStatus.concluded.value}, TimelineEventType.caseConcluded);
  }

  @override
  Future<void> forwardComplementToTeacher(AppUser director, StudentCase value) =>
      _cases.transition(director, value, {'complementOpen': true},
          TimelineEventType.caseUbsComplementForwarded);

  @override
  Future<void> answerUbsComplement(
    AppUser director,
    StudentCase value,
    Referral referral,
    String text,
  ) async {
    await _referralTransition(
      director,
      referral,
      {'status': referral.previousStatus, 'previousStatus': null},
      TimelineEventType.referralComplementAnswered,
      note: (kind: 'complementAnswer', text: text, audience: const ['school', 'ubs', 'psychologist']),
    );
    if (value.complementOpen) {
      await _cases.transition(director, value, {'complementOpen': false},
          TimelineEventType.caseUbsComplementClosed);
    }
  }

  // ------------------------------------------------------- Direção da UBS

  @override
  Future<void> receive(AppUser ubsDirector, Referral referral) => _referralTransition(
      ubsDirector, referral, {'status': ReferralStatus.received.value},
      TimelineEventType.referralReceived);

  @override
  Future<void> assign(AppUser ubsDirector, Referral referral, StaffOption psychologist,
      {required bool caseNeedsFollowUp}) {
    final transfer = referral.status == ReferralStatus.assigned ||
        referral.status == ReferralStatus.inAttendance;
    return _referralTransition(
      ubsDirector,
      referral,
      {
        if (!transfer) 'status': ReferralStatus.assigned.value,
        'assignedPsychologistUid': psychologist.uid,
        'assignedPsychologistName': psychologist.name,
      },
      transfer ? TimelineEventType.referralTransferred : TimelineEventType.referralAssigned,
      caseChanges: !transfer && caseNeedsFollowUp
          ? {'status': CaseStatus.inFollowUp.value}
          : null,
    );
  }

  @override
  Future<void> requestUbsComplement(AppUser ubsDirector, Referral referral, String text) =>
      _referralTransition(
        ubsDirector,
        referral,
        {
          'status': ReferralStatus.complementRequested.value,
          'previousStatus': referral.status.value,
        },
        TimelineEventType.referralComplementRequested,
        note: (kind: 'complementRequest', text: text, audience: const ['school', 'ubs']),
      );

  @override
  Future<void> returnReferral(AppUser ubsDirector, Referral referral, String text) =>
      _referralTransition(
        ubsDirector,
        referral,
        {'status': ReferralStatus.returned.value},
        TimelineEventType.referralReturned,
        note: (kind: 'return', text: text, audience: const ['school', 'ubs']),
        caseChanges: {'activeReferrals.${referral.id}': FieldValue.delete()},
      );

  @override
  Future<void> refuse(AppUser ubsDirector, Referral referral, String text) =>
      _referralTransition(
        ubsDirector,
        referral,
        {'status': ReferralStatus.refused.value},
        TimelineEventType.referralRefused,
        note: (kind: 'refusal', text: text, audience: const ['school', 'ubs']),
        caseChanges: {'activeReferrals.${referral.id}': FieldValue.delete()},
      );

  @override
  Future<void> finalize(AppUser ubsDirector, Referral referral) => _referralTransition(
        ubsDirector,
        referral,
        {'status': ReferralStatus.finalized.value},
        TimelineEventType.referralFinalized,
        caseChanges: {'activeReferrals.${referral.id}': FieldValue.delete()},
      );

  // ----------------------------------------------------------- Psicólogo

  @override
  Future<void> startAttendance(AppUser psychologist, Referral referral) =>
      _referralTransition(psychologist, referral,
          {'status': ReferralStatus.inAttendance.value},
          TimelineEventType.referralStatusChanged);

  @override
  Future<void> addProgressNote(AppUser psychologist, Referral referral, String text) {
    return _referrals.doc(referral.id).collection('notes').add({
      'kind': 'progress',
      'text': text.trim(),
      'audience': const ['psychologist'],
      'authorUid': psychologist.uid,
      'authorName': psychologist.name ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> registerReturn(
    AppUser psychologist,
    Referral referral, {
    required String content,
    required List<String> audience,
  }) async {
    if (audience.isEmpty) {
      throw const ReferralRepositoryException(
          'Indique se a devolutiva é para a escola, para a família ou para ambas.');
    }
    final caseRef = _firestore.collection('cases').doc(referral.caseId);
    final eventRef = caseRef.collection('timelineEvents').doc();
    final toFamily = audience.contains('family');
    final batch = _firestore.batch()
      ..set(_firestore.collection('healthReturns').doc(eventRef.id), {
        'referralId': referral.id,
        'caseId': referral.caseId,
        'studentId': referral.studentId,
        'audience': audience,
        'content': content.trim(),
        'authorUid': psychologist.uid,
        'authorName': psychologist.name ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..update(_referrals.doc(referral.id), {
        'status': ReferralStatus.returnRegistered.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': psychologist.uid,
        'lastEventId': eventRef.id,
      })
      ..set(
        eventRef,
        eventData(
          psychologist,
          TimelineEventType.healthReturnCreated,
          referralId: referral.id,
          refId: eventRef.id,
          visibility: toFamily ? 'familia' : 'restrito',
          audience: toFamily ? const [] : const ['school'],
        ),
      );
    addFamilyNotification(batch, _firestore,
        caseId: referral.caseId,
        studentId: referral.studentId,
        eventId: eventRef.id,
        type: TimelineEventType.healthReturnCreated,
        visibility: toFamily ? 'familia' : 'restrito',
        actorUid: psychologist.uid,
        referralId: referral.id);
    await batch.commit();
  }

  // --------------------------------------------------------------- base

  Future<void> _referralTransition(
    AppUser actor,
    Referral referral,
    Map<String, Object?> changes,
    String type, {
    ({String kind, String text, List<String> audience})? note,
    Map<String, Object?>? caseChanges,
  }) async {
    final caseRef = _firestore.collection('cases').doc(referral.caseId);
    final eventRef = caseRef.collection('timelineEvents').doc();
    final batch = _firestore.batch()
      ..update(_referrals.doc(referral.id), {
        ...changes,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actor.uid,
        'lastEventId': eventRef.id,
      })
      ..set(eventRef, eventData(actor, type, referralId: referral.id));
    addFamilyNotification(batch, _firestore,
        caseId: referral.caseId,
        studentId: referral.studentId,
        eventId: eventRef.id,
        type: type,
        visibility: TimelineEventType.visibilityOf(type),
        actorUid: actor.uid,
        referralId: referral.id);
    if (note != null) {
      batch.set(_referrals.doc(referral.id).collection('notes').doc(eventRef.id), {
        'kind': note.kind,
        'text': note.text.trim(),
        'audience': note.audience,
        'authorUid': actor.uid,
        'authorName': actor.name ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    if (caseChanges != null) {
      batch.update(caseRef, {
        ...caseChanges,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actor.uid,
        'lastEventId': eventRef.id,
      });
    }
    await batch.commit();
  }
}
