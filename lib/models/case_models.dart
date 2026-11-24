import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';

/// Estados do caso (docs/MODELO_DADOS.md). `concluido` é o único terminal (D-12).
enum CaseStatus {
  draft('rascunho', 'Registro inicial', 'Novo'),
  awaitingReview('aguardando_analise', 'Aguardando análise da Direção', 'warning'),
  complementRequested(
      'complementacao_solicitada', 'Complementação solicitada', 'danger'),
  approved('aprovado', 'Aprovado', 'success'),
  referred('encaminhado', 'Encaminhado à UBS', 'info'),
  inFollowUp('em_acompanhamento', 'Em acompanhamento', 'info'),
  concluded('concluido', 'Concluído', 'success');

  const CaseStatus(this.value, this.label, this.tone);
  final String value;
  final String label;
  final String tone;

  static CaseStatus fromValue(String? value) =>
      values.firstWhere((s) => s.value == value, orElse: () => draft);
}

DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;
List<String> _ids(Object? value) => List<String>.unmodifiable(
    value is List ? value.whereType<String>() : const <String>[]);

/// Metadados administrativos do caso (`cases/{id}`): sem conteúdo sensível.
class StudentCase {
  const StudentCase({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.schoolInstitutionId,
    required this.primaryTeacherUid,
    required this.teacherUids,
    required this.status,
    required this.familyVisible,
    required this.complementOpen,
    required this.activeReferrals,
    required this.lastEventId,
    this.approvedAt,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String schoolInstitutionId;
  final String primaryTeacherUid;
  final List<String> teacherUids;
  final CaseStatus status;
  final bool familyVisible;
  final bool complementOpen;

  /// Encaminhamentos ativos: `{referralId: ubsId}`.
  final Map<String, String> activeReferrals;
  final String lastEventId;
  final DateTime? approvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  factory StudentCase.fromFirestore(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      StudentCase.fromMap(doc.id, doc.data() ?? const <String, dynamic>{});

  factory StudentCase.fromMap(String id, Map<String, dynamic> data) {
    final active = data['activeReferrals'];
    return StudentCase(
      id: id,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      schoolInstitutionId: data['schoolInstitutionId'] as String? ?? '',
      primaryTeacherUid: data['primaryTeacherUid'] as String? ?? '',
      teacherUids: _ids(data['teacherUids']),
      status: CaseStatus.fromValue(data['status'] as String?),
      familyVisible: data['familyVisible'] == true,
      complementOpen: data['complementOpen'] == true,
      activeReferrals: active is Map
          ? Map<String, String>.unmodifiable(
              active.map((k, v) => MapEntry('$k', '$v')))
          : const {},
      lastEventId: data['lastEventId'] as String? ?? '',
      approvedAt: _date(data['approvedAt']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      createdBy: data['createdBy'] as String?,
    );
  }

  /// Professor vinculado pode registrar conteúdo (RN-32).
  bool get acceptsSchoolContent =>
      status == CaseStatus.draft ||
      status == CaseStatus.complementRequested ||
      complementOpen;
}

/// Tipos de evento (fixos por tipo; ver docs/MODELO_DADOS.md §3).
abstract final class TimelineEventType {
  static const caseCreated = 'case.created';
  static const caseSubmitted = 'case.submitted';
  static const caseComplemented = 'case.complemented';
  static const caseComplementRequested = 'case.complementRequested';
  static const caseApproved = 'case.approved';
  static const caseConcluded = 'case.concluded';
  static const caseTeachersUpdated = 'case.teachersUpdated';
  static const caseUbsComplementForwarded = 'case.ubsComplementForwarded';
  static const caseUbsComplementClosed = 'case.ubsComplementClosed';
  static const observationCreated = 'observation.created';
  static const pedagogicalRecordCreated = 'pedagogicalRecord.created';
  static const referralSent = 'referral.sent';
  static const referralReceived = 'referral.received';
  static const referralAssigned = 'referral.assigned';
  static const referralTransferred = 'referral.transferred';
  static const referralComplementRequested = 'referral.complementRequested';
  static const referralComplementAnswered = 'referral.complementAnswered';
  static const referralReturned = 'referral.returned';
  static const referralRefused = 'referral.refused';
  static const referralFinalized = 'referral.finalized';
  static const referralStatusChanged = 'referral.statusChanged';
  static const healthReturnCreated = 'healthReturn.created';

  static const internal = {
    observationCreated,
    pedagogicalRecordCreated,
    caseTeachersUpdated,
    caseUbsComplementForwarded,
    caseUbsComplementClosed,
  };

  /// Visibilidade fixa por tipo (a devolutiva depende da audiência).
  static String visibilityOf(String type) =>
      internal.contains(type) ? 'interno' : 'familia';

  static const _labels = {
    caseCreated: 'Caso registrado',
    caseSubmitted: 'Caso enviado à Direção escolar',
    caseComplemented: 'Complementação enviada pelo professor',
    caseComplementRequested: 'Direção solicitou complementação',
    caseApproved: 'Caso aprovado pela Direção escolar',
    caseConcluded: 'Acompanhamento concluído',
    caseTeachersUpdated: 'Professores vinculados atualizados',
    caseUbsComplementForwarded: 'Pedido da UBS repassado ao professor',
    caseUbsComplementClosed: 'Complementação para a UBS encerrada',
    observationCreated: 'Observação pedagógica registrada',
    pedagogicalRecordCreated: 'Registro pedagógico registrado',
    referralSent: 'Encaminhado à UBS',
    referralReceived: 'Encaminhamento recebido pela UBS',
    referralAssigned: 'Profissional responsável atribuído',
    referralTransferred: 'Profissional responsável transferido',
    referralComplementRequested: 'UBS solicitou complementação',
    referralComplementAnswered: 'Escola respondeu à complementação',
    referralReturned: 'Encaminhamento devolvido pela UBS',
    referralRefused: 'Encaminhamento recusado pela UBS',
    referralFinalized: 'Encaminhamento finalizado pela UBS',
    referralStatusChanged: 'Atendimento iniciado',
    healthReturnCreated: 'Devolutiva da saúde registrada',
  };

  static String labelOf(String type) => _labels[type] ?? type;
}

class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.type,
    required this.visibility,
    required this.actorName,
    required this.actorRole,
    this.referralId,
    this.refId,
    this.createdAt,
  });

  final String id;
  final String type;
  final String visibility;
  final String actorName;
  final String actorRole;
  final String? referralId;
  final String? refId;
  final DateTime? createdAt;

  factory TimelineEvent.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TimelineEvent(
      id: doc.id,
      type: data['type'] as String? ?? '',
      visibility: data['visibility'] as String? ?? 'familia',
      actorName: data['actorName'] as String? ?? '',
      actorRole: data['actorRole'] as String? ?? '',
      referralId: data['referralId'] as String?,
      refId: data['refId'] as String?,
      createdAt: _date(data['createdAt']),
    );
  }

  String get label => TimelineEventType.labelOf(type);
}

/// `actorRole` gravado nos eventos (verificado pelas regras).
String actorRoleOf(AppUser user) => switch (user.role) {
      UserRole.school => 'school/${user.schoolRole?.value}',
      UserRole.health => 'health/${user.healthRole?.value}',
      _ => user.role.value,
    };

/// Observação pedagógica interna (RF08): fatos observáveis, sem diagnóstico.
class Observation {
  const Observation({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.context,
    required this.description,
    this.observedAt,
    this.createdAt,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String context;
  final String description;
  final DateTime? observedAt;
  final DateTime? createdAt;

  factory Observation.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Observation(
      id: doc.id,
      authorUid: data['authorUid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      context: data['context'] as String? ?? '',
      description: data['description'] as String? ?? '',
      observedAt: _date(data['observedAt']),
      createdAt: _date(data['createdAt']),
    );
  }
}

/// Registro pedagógico estruturado (RF09): reúne observações e ações.
class PedagogicalRecord {
  const PedagogicalRecord({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.summary,
    required this.actions,
    required this.observationIds,
    this.createdAt,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String summary;
  final List<String> actions;
  final List<String> observationIds;
  final DateTime? createdAt;

  factory PedagogicalRecord.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return PedagogicalRecord(
      id: doc.id,
      authorUid: data['authorUid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      summary: data['summary'] as String? ?? '',
      actions: _ids(data['actions']),
      observationIds: _ids(data['observationIds']),
      createdAt: _date(data['createdAt']),
    );
  }
}
