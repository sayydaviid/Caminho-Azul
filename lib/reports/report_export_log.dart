import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import 'report_models.dart';

/// Ação registrada: gerar não é compartilhar; abrir o menu do sistema não
/// comprova a entrega ao destinatário (R-07).
enum ReportExportAction {
  generated('generated'),
  shareSheetOpened('share_opened'),
  printOrSaveOpened('print_opened'),
  downloaded('downloaded');

  const ReportExportAction(this.value);
  final String value;
}

/// Registro mínimo (somente metadados, sem conteúdo) de cada exportação.
abstract interface class ReportExportLog {
  Future<void> record({
    required AppUser actor,
    required ReportKind kind,
    required ReportExportAction action,
    required String caseId,
    String? referralId,
    required int itemCount,
  });
}

class FirebaseReportExportLog implements ReportExportLog {
  FirebaseReportExportLog({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<void> record({
    required AppUser actor,
    required ReportKind kind,
    required ReportExportAction action,
    required String caseId,
    String? referralId,
    required int itemCount,
  }) =>
      _firestore.collection('documentExports').add({
        'kind': kind.value,
        'action': action.value,
        'caseId': caseId,
        'referralId': referralId,
        'actorUid': actor.uid,
        'itemCount': itemCount,
        'createdAt': FieldValue.serverTimestamp(),
      });
}
