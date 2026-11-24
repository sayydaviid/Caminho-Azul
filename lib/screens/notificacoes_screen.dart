import 'package:flutter/material.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../models/notification_models.dart';
import '../repositories/family_repository.dart';
import '../repositories/notification_repository.dart';
import '../services/auth_service.dart';
import '../widgets/admin_forms.dart' show formatDate;
import '../widgets/dashboard_card.dart';
import '../widgets/page_header.dart';
import '../widgets/section_error.dart';

/// Central de notificações da família (N-02): lista em tempo real, contador,
/// marcar como lida, marcar todas e abrir o acompanhamento correspondente.
/// A tela de destino consulta o Firestore de novo, sob as regras da família.
class NotificacoesScreen extends StatefulWidget {
  const NotificacoesScreen({
    required this.user,
    this.repository,
    this.familyRepository,
    super.key,
  });

  final AppUser user;
  final NotificationRepository? repository;
  final FamilyRepository? familyRepository;

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  late final NotificationRepository _repository =
      widget.repository ?? FirebaseNotificationRepository();
  late final FamilyRepository _family =
      widget.familyRepository ?? FirebaseFamilyRepository();
  late final String? _studentId =
      widget.user.studentIds.isEmpty ? null : widget.user.studentIds.first;
  int _limit = notificationPageSize;
  late Stream<List<FamilyNotification>> _stream = _watch();
  String? _studentLabel;
  bool _markingAll = false;

  Stream<List<FamilyNotification>> _watch() {
    final id = _studentId;
    return id == null
        ? Stream.value(const [])
        : _repository.watchNotifications(id, limit: _limit);
  }

  @override
  void initState() {
    super.initState();
    final id = _studentId;
    if (id != null) {
      _family.student(id).then((student) {
        if (mounted && student != null) {
          setState(() => _studentLabel = student.label);
        }
      }, onError: (_) {});
    }
  }

  void _loadMore() => setState(() {
        _limit += notificationPageSize;
        _stream = _watch();
      });

  Future<void> _open(FamilyNotification item) async {
    try {
      await _repository.markRead(item);
    } catch (_) {
      // A leitura do caso não depende da marcação.
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.family,
        arguments: FamilyRouteArguments(caseId: item.caseId));
  }

  Future<void> _markRead(FamilyNotification item) async {
    try {
      await _repository.markRead(item);
    } catch (_) {
      _snack('Não foi possível marcar a notificação como lida.');
    }
  }

  Future<void> _markAll() async {
    final id = _studentId;
    if (id == null || _markingAll) return;
    setState(() => _markingAll = true);
    try {
      await _repository.markAllRead(id);
      _snack('Todas as notificações foram marcadas como lidas.');
    } catch (_) {
      _snack('Não foi possível marcar as notificações como lidas.');
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FamilyNotification>>(
      stream: _stream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <FamilyNotification>[];
        final unread = items.where((n) => n.unread).length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageHeader(
              title: 'Notificações',
              subtitle: _studentLabel == null
                  ? 'Atualizações do acompanhamento do estudante'
                  : 'Estudante: $_studentLabel',
              trailing: OutlinedButton.icon(
                key: const Key('notifications-mark-all'),
                onPressed: unread == 0 || _markingAll ? null : _markAll,
                icon: const Icon(Icons.done_all),
                label: const Text('Marcar todas como lidas'),
              ),
            ),
            const SizedBox(height: 12),
            if (snapshot.hasError)
              const SectionError('Não foi possível carregar as notificações.')
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (items.isEmpty)
              const AppCard(
                key: Key('notifications-empty'),
                child: Text(
                  'Nenhuma notificação por enquanto. Você será avisado aqui '
                  'quando houver atualização no acompanhamento.',
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  unread == 0
                      ? 'Todas lidas'
                      : unread == 1
                          ? '1 não lida'
                          : '$unread não lidas',
                  key: const Key('notifications-unread-summary'),
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 8),
              for (final item in items) _tile(item),
              if (items.length >= _limit)
                Center(
                  child: TextButton(
                    key: const Key('notifications-load-more'),
                    onPressed: _loadMore,
                    child: const Text('Carregar mais'),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _tile(FamilyNotification item) {
    final when = formatDate(item.createdAt);
    final reference = item.referralId == null
        ? 'Acompanhamento escolar'
        : 'Encaminhamento à saúde';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label: '${item.unread ? 'Não lida. ' : ''}${item.title}. '
            '${item.message} $reference, $when.',
        excludeSemantics: true,
        onTap: () => _open(item),
        child: Card(
          key: Key('notification-${item.id}'),
          margin: EdgeInsets.zero,
          color: item.unread ? const Color(0xFFEFF6FF) : AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
                color: item.unread ? AppColors.primary : AppColors.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _open(item),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 10),
                    child: Icon(
                      item.unread
                          ? Icons.mark_email_unread_outlined
                          : Icons.drafts_outlined,
                      color: item.unread ? AppColors.primary : AppColors.muted,
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: TextStyle(
                                fontWeight: item.unread
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(item.message),
                        const SizedBox(height: 4),
                        Text('$reference • $when',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (item.unread)
                    IconButton(
                      key: Key('notification-read-${item.id}'),
                      tooltip: 'Marcar como lida',
                      onPressed: () => _markRead(item),
                      icon: const Icon(Icons.check, size: 20),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Argumentos da área da família: abre (e destaca) um acompanhamento.
class FamilyRouteArguments {
  const FamilyRouteArguments({this.caseId});
  final String? caseId;
}
