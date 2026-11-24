import 'package:cloud_firestore/cloud_firestore.dart';

import 'case_models.dart';

/// Notificações internas da família (N-01). Cada notificação nasce no mesmo
/// batch de um evento da linha do tempo visível à família, com id
/// determinístico `{caseId}_{eventId}` (sem duplicação em novas tentativas).
///
/// O documento guarda só referências e o tipo do evento: título e mensagem
/// são textos administrativos fixos, derivados do tipo, para que nenhuma
/// justificativa, observação ou conteúdo clínico chegue à notificação.
enum FamilyNotificationKind {
  caseApproved(TimelineEventType.caseApproved, 'Acompanhamento aprovado',
      'A Direção escolar aprovou o acompanhamento do estudante.'),
  referralSent(TimelineEventType.referralSent, 'Encaminhamento à saúde',
      'O caso foi encaminhado a uma unidade de saúde.'),
  referralReceived(TimelineEventType.referralReceived, 'Encaminhamento recebido',
      'A unidade de saúde recebeu o encaminhamento.'),
  referralAssigned(TimelineEventType.referralAssigned, 'Profissional definido',
      'Um profissional da unidade de saúde foi designado para o acompanhamento.'),
  referralTransferred(TimelineEventType.referralTransferred,
      'Profissional alterado',
      'O acompanhamento passou para outro profissional da unidade de saúde.'),
  referralStatusChanged(TimelineEventType.referralStatusChanged,
      'Atendimento em andamento',
      'Há uma atualização no atendimento da unidade de saúde.'),
  referralComplementRequested(TimelineEventType.referralComplementRequested,
      'Complementação solicitada',
      'A unidade de saúde pediu informações complementares à escola.'),
  referralReturned(TimelineEventType.referralReturned, 'Encaminhamento devolvido',
      'A unidade de saúde devolveu o encaminhamento à escola.'),
  referralRefused(TimelineEventType.referralRefused, 'Encaminhamento não aceito',
      'A unidade de saúde não aceitou o encaminhamento. A escola foi informada.'),
  healthReturnCreated(TimelineEventType.healthReturnCreated, 'Nova devolutiva',
      'Uma nova devolutiva está disponível no acompanhamento.'),
  referralFinalized(TimelineEventType.referralFinalized, 'Atendimento finalizado',
      'A unidade de saúde finalizou o atendimento.'),
  caseConcluded(TimelineEventType.caseConcluded, 'Acompanhamento concluído',
      'A Direção escolar concluiu o acompanhamento.');

  const FamilyNotificationKind(this.eventType, this.title, this.message);

  final String eventType;
  final String title;
  final String message;

  static FamilyNotificationKind? ofEvent(String? type) {
    for (final kind in values) {
      if (kind.eventType == type) return kind;
    }
    return null;
  }

  /// O evento gera notificação: tipo da lista e visível à família (uma
  /// devolutiva só para a escola é `restrito` e não notifica).
  static bool notifies(String type, String visibility) =>
      visibility == 'familia' && ofEvent(type) != null;
}

class FamilyNotification {
  const FamilyNotification({
    required this.id,
    required this.studentId,
    required this.caseId,
    required this.eventId,
    required this.type,
    this.referralId,
    this.createdAt,
    this.readAt,
  });

  factory FamilyNotification.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    DateTime? date(Object? value) =>
        value is Timestamp ? value.toDate() : null;
    return FamilyNotification(
      id: doc.id,
      studentId: data['studentId'] as String? ?? '',
      caseId: data['caseId'] as String? ?? '',
      eventId: data['eventId'] as String? ?? '',
      type: data['type'] as String? ?? '',
      referralId: data['referralId'] as String?,
      createdAt: date(data['createdAt']),
      readAt: date(data['readAt']),
    );
  }

  final String id;
  final String studentId;
  final String caseId;
  final String eventId;
  final String type;
  final String? referralId;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;
  FamilyNotificationKind? get kind => FamilyNotificationKind.ofEvent(type);
  String get title => kind?.title ?? 'Atualização no acompanhamento';
  String get message =>
      kind?.message ?? 'Uma nova atualização está disponível no acompanhamento.';

  static String idFor(String caseId, String eventId) => '${caseId}_$eventId';
}
