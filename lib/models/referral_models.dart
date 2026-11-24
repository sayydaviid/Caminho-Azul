import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;
List<String> _list(Object? value) => List<String>.unmodifiable(
    value is List ? value.whereType<String>() : const <String>[]);

/// Estados do encaminhamento (docs/MODELO_DADOS.md §3).
enum ReferralStatus {
  sent('enviado', 'Enviado à UBS', 'warning', active: true),
  received('recebido', 'Recebido pela UBS', 'info', active: true),
  complementRequested('complementacao_solicitada', 'Complementação solicitada',
      'danger', active: true),
  assigned('atribuido', 'Profissional atribuído', 'info', active: true),
  inAttendance('em_atendimento', 'Em atendimento', 'info', active: true),
  returnRegistered('devolutiva_registrada', 'Devolutiva registrada', 'success',
      active: true),
  finalized('finalizado', 'Finalizado', 'success', active: false),
  returned('devolvido', 'Devolvido pela UBS', 'danger', active: false),
  refused('recusado', 'Recusado pela UBS', 'danger', active: false);

  const ReferralStatus(this.value, this.label, this.tone, {required this.active});
  final String value;
  final String label;
  final String tone;
  final bool active;

  static ReferralStatus fromValue(String? value) =>
      values.firstWhere((s) => s.value == value, orElse: () => sent);
}

/// Metadados do encaminhamento (`referrals/{id}`); motivo e resumo ficam em
/// `private/details` (D-13).
class Referral {
  const Referral({
    required this.id,
    required this.caseId,
    required this.studentId,
    required this.studentName,
    required this.originInstitutionId,
    required this.destinationInstitutionId,
    required this.status,
    required this.lastEventId,
    this.previousStatus,
    this.assignedPsychologistUid,
    this.assignedPsychologistName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String caseId;
  final String studentId;
  final String studentName;
  final String originInstitutionId;
  final String destinationInstitutionId;
  final ReferralStatus status;
  final String? previousStatus;
  final String? assignedPsychologistUid;
  final String? assignedPsychologistName;
  final String lastEventId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Referral.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Referral(
      id: doc.id,
      caseId: data['caseId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      originInstitutionId: data['originInstitutionId'] as String? ?? '',
      destinationInstitutionId: data['destinationInstitutionId'] as String? ?? '',
      status: ReferralStatus.fromValue(data['status'] as String?),
      previousStatus: data['previousStatus'] as String?,
      assignedPsychologistUid: data['assignedPsychologistUid'] as String?,
      assignedPsychologistName: data['assignedPsychologistName'] as String?,
      lastEventId: data['lastEventId'] as String? ?? '',
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }
}

class ReferralDetails {
  const ReferralDetails({required this.reason, required this.summary});
  final String reason;
  final String summary;
}

/// Notas restritas do encaminhamento (justificativas, complementação,
/// atualizações do psicólogo).
class ReferralNote {
  const ReferralNote({
    required this.id,
    required this.kind,
    required this.text,
    required this.authorName,
    this.createdAt,
  });

  final String id;
  final String kind;
  final String text;
  final String authorName;
  final DateTime? createdAt;

  factory ReferralNote.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ReferralNote(
      id: doc.id,
      kind: data['kind'] as String? ?? '',
      text: data['text'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      createdAt: _date(data['createdAt']),
    );
  }

  String get kindLabel => switch (kind) {
        'complementRequest' => 'Pedido de complementação da UBS',
        'complementAnswer' => 'Resposta da escola',
        'return' => 'Justificativa da devolução',
        'refusal' => 'Justificativa da recusa',
        'progress' => 'Atualização do acompanhamento',
        _ => kind,
      };
}

/// Devolutiva da saúde (`healthReturns`), com audiência escola e/ou família.
class HealthReturn {
  const HealthReturn({
    required this.id,
    required this.referralId,
    required this.caseId,
    required this.studentId,
    required this.audience,
    required this.content,
    required this.authorName,
    this.createdAt,
  });

  final String id;
  final String referralId;
  final String caseId;
  final String studentId;
  final List<String> audience;
  final String content;
  final String authorName;
  final DateTime? createdAt;

  factory HealthReturn.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return HealthReturn(
      id: doc.id,
      referralId: data['referralId'] as String? ?? '',
      caseId: data['caseId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      audience: _list(data['audience']),
      content: data['content'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      createdAt: _date(data['createdAt']),
    );
  }

  String get audienceLabel => [
        if (audience.contains('school')) 'Escola',
        if (audience.contains('family')) 'Família',
      ].join(' e ');
}

/// Profissional selecionável (psicólogo da UBS, professor da escola).
class StaffOption {
  const StaffOption({required this.uid, required this.name});
  final String uid;
  final String name;
}

class InstitutionOption {
  const InstitutionOption({required this.id, required this.name});
  final String id;
  final String name;
}
