import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification_models.dart';

/// Central de notificações da família (N-01, N-02). As consultas sempre
/// filtram pelo estudante vinculado, como exigem as regras.
abstract interface class NotificationRepository {
  /// Notificações mais recentes primeiro, em páginas de [limit] (P2-12).
  Stream<List<FamilyNotification>> watchNotifications(String studentId,
      {int limit = notificationPageSize});

  /// Não lidas (até [unreadCountCap]) para o contador do ícone.
  Stream<int> watchUnreadCount(String studentId);
  Future<void> markRead(FamilyNotification notification);
  Future<void> markAllRead(String studentId);
}

const notificationPageSize = 20;
const unreadCountCap = 99;

class FirebaseNotificationRepository implements NotificationRepository {
  FirebaseNotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('notifications');

  @override
  Stream<List<FamilyNotification>> watchNotifications(String studentId,
          {int limit = notificationPageSize}) =>
      _collection
          .where('studentId', isEqualTo: studentId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => List.unmodifiable(
              snapshot.docs.map(FamilyNotification.fromFirestore)));

  @override
  Stream<int> watchUnreadCount(String studentId) => _collection
      .where('studentId', isEqualTo: studentId)
      .where('readAt', isNull: true)
      .limit(unreadCountCap + 1)
      .snapshots()
      .map((snapshot) => snapshot.size);

  @override
  Future<void> markRead(FamilyNotification notification) async {
    if (!notification.unread) return;
    await _collection
        .doc(notification.id)
        .update({'readAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> markAllRead(String studentId) async {
    // Em lotes, até não restar nenhuma não lida (limite de 500 por batch).
    while (true) {
      final unread = await _collection
          .where('studentId', isEqualTo: studentId)
          .where('readAt', isNull: true)
          .limit(200)
          .get();
      if (unread.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'readAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
      if (unread.docs.length < 200) return;
    }
  }
}

/// Acrescenta ao [batch] a notificação da família para o evento [eventId],
/// quando o tipo e a visibilidade do evento justificam (N-03). Chamado pelas
/// transições que gravam o evento: as regras exigem a notificação nesses
/// casos e conferem autor, estudante, caso e evento.
void addFamilyNotification(
  WriteBatch batch,
  FirebaseFirestore firestore, {
  required String caseId,
  required String studentId,
  required String eventId,
  required String type,
  required String visibility,
  required String actorUid,
  String? referralId,
}) {
  if (!FamilyNotificationKind.notifies(type, visibility)) return;
  batch.set(
    firestore
        .collection('notifications')
        .doc(FamilyNotification.idFor(caseId, eventId)),
    {
      'studentId': studentId,
      'caseId': caseId,
      'eventId': eventId,
      'referralId': referralId,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': actorUid,
      'readAt': null,
    },
  );
}
