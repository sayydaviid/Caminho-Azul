// N-01..N-04 — central de notificações da família (widgets, com fakes).
// As regras de segurança das notificações estão em
// scripts/test/domain.rules.test.js ("notifications: ...").
import 'dart:async';

import 'package:caminho_azul/app/router.dart';
import 'package:caminho_azul/app/theme.dart';
import 'package:caminho_azul/models/case_models.dart';
import 'package:caminho_azul/models/notification_models.dart';
import 'package:caminho_azul/repositories/notification_repository.dart';
import 'package:caminho_azul/screens/familia_acompanhamento_screen.dart';
import 'package:caminho_azul/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'referral_family_screens_test.dart' show FakeFamilyRepository;
import 'support/empty_referral_repository.dart';
import 'widget_test.dart'
    show EmptyCaseRepository, EmptyStudentRepository, FakeAuthService;

class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository(List<FamilyNotification> initial)
      : _items = [...initial];

  List<FamilyNotification> _items;
  final _changes = StreamController<void>.broadcast();
  final calls = <String>[];
  final limits = <int>[];

  void push(FamilyNotification value) {
    _items = [value, ..._items];
    _changes.add(null);
  }

  Stream<T> _live<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  Stream<List<FamilyNotification>> watchNotifications(String studentId,
      {int limit = notificationPageSize}) {
    limits.add(limit);
    return _live(() => _items
        .where((n) => n.studentId == studentId)
        .take(limit)
        .toList());
  }

  @override
  Stream<int> watchUnreadCount(String studentId) => _live(() =>
      _items.where((n) => n.studentId == studentId && n.unread).length);

  FamilyNotification _read(FamilyNotification n) => FamilyNotification(
        id: n.id,
        studentId: n.studentId,
        caseId: n.caseId,
        eventId: n.eventId,
        type: n.type,
        referralId: n.referralId,
        createdAt: n.createdAt,
        readAt: DateTime(2026, 11, 24, 10),
      );

  @override
  Future<void> markRead(FamilyNotification notification) async {
    calls.add('read:${notification.id}');
    _items = [
      for (final n in _items) n.id == notification.id ? _read(n) : n,
    ];
    _changes.add(null);
  }

  @override
  Future<void> markAllRead(String studentId) async {
    calls.add('readAll:$studentId');
    _items = [for (final n in _items) n.studentId == studentId ? _read(n) : n];
    _changes.add(null);
  }
}

FamilyNotification notification(String id, String type,
        {bool read = false, String? referralId, int minute = 0}) =>
    FamilyNotification(
      id: 'c1_$id',
      studentId: 's1',
      caseId: 'c1',
      eventId: id,
      type: type,
      referralId: referralId,
      createdAt: DateTime(2026, 11, 24, 9, minute),
      readAt: read ? DateTime(2026, 11, 24, 9, 30) : null,
    );

const _family = AppUser(
  uid: 'fam',
  email: 'familia@caminhoazul.test',
  name: 'Família Sintética',
  role: UserRole.family,
  studentIds: ['s1'],
);

Widget _app(FakeNotificationRepository repository,
        {AppUser user = _family, String route = AppRoutes.notifications}) =>
    MaterialApp(
      key: ValueKey('${user.uid}$route'),
      theme: AppTheme.light,
      initialRoute: route,
      onGenerateRoute: (settings) => AppRouter.generateRoute(
        settings,
        authService: FakeAuthService(appUser: user),
        familyRepository: FakeFamilyRepository(),
        notificationRepository: repository,
        caseRepository: EmptyCaseRepository(),
        studentRepository: EmptyStudentRepository(),
        referralRepository: EmptyReferralRepository(),
      ),
    );

void main() {
  testWidgets('N-02: contador, lista, abrir o caso e estado de leitura',
      (tester) async {
    final repository = FakeNotificationRepository([
      notification('e3', TimelineEventType.healthReturnCreated,
          referralId: 'r1', minute: 3),
      notification('e2', TimelineEventType.referralSent, referralId: 'r1', minute: 2),
      notification('e1', TimelineEventType.caseApproved, read: true, minute: 1),
    ]);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Notificações'), findsWidgets);
    expect(find.byKey(const Key('notification-count')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('2 não lidas'), findsOneWidget);
    expect(find.text('Nova devolutiva'), findsOneWidget);
    expect(find.text('Encaminhamento à saúde'), findsWidgets);
    expect(find.text('Acompanhamento aprovado'), findsOneWidget);
    // Mensagem administrativa, sem conteúdo do caso.
    expect(find.text('Uma nova devolutiva está disponível no acompanhamento.'),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-read-c1_e2')));
    await tester.pumpAndSettle();
    expect(repository.calls, ['read:c1_e2']);
    expect(find.text('1 não lida'), findsOneWidget);

    // Abrir: marca como lida e leva ao acompanhamento destacado.
    await tester.tap(find.text('Nova devolutiva'));
    await tester.pumpAndSettle();
    expect(repository.calls.last, 'read:c1_e3');
    final screen = tester.widget<FamiliaAcompanhamentoScreen>(
        find.byType(FamiliaAcompanhamentoScreen));
    expect(screen.focusCaseId, 'c1');
    expect(find.byKey(const Key('family-case-c1')), findsOneWidget);
    expect(find.byKey(const Key('notification-count')), findsNothing);
  });

  testWidgets('N-02: marcar todas como lidas e atualização em tempo real',
      (tester) async {
    final repository = FakeNotificationRepository([
      notification('e2', TimelineEventType.referralReceived, referralId: 'r1', minute: 2),
      notification('e1', TimelineEventType.caseApproved, minute: 1),
    ]);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notifications-mark-all')));
    await tester.pumpAndSettle();
    expect(repository.calls, ['readAll:s1']);
    expect(find.text('Todas lidas'), findsOneWidget);
    expect(find.byKey(const Key('notification-count')), findsNothing);

    // Chega uma notificação com a tela aberta: lista, contador e aviso.
    repository.push(notification('e4', TimelineEventType.caseConcluded, minute: 4));
    await tester.pumpAndSettle();
    expect(find.text('Acompanhamento concluído'), findsOneWidget);
    expect(find.text('1 não lida'), findsOneWidget);
    expect(find.text('Uma nova atualização está disponível no acompanhamento.'),
        findsOneWidget);
  });

  testWidgets('N-02: paginação carrega mais notificações (P2-12)',
      (tester) async {
    final repository = FakeNotificationRepository([
      for (var i = 0; i < notificationPageSize + 5; i++)
        notification('e$i', TimelineEventType.referralStatusChanged,
            referralId: 'r1', read: true, minute: i % 60),
    ]);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('notifications-load-more')), 300);
    await tester.tap(find.byKey(const Key('notifications-load-more')));
    await tester.pumpAndSettle();
    expect(repository.limits.last, notificationPageSize * 2);
  });

  testWidgets('N-04: sem notificações vazia; ícone só para a família',
      (tester) async {
    final repository = FakeNotificationRepository(const []);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notifications-empty')), findsOneWidget);
    expect(find.byKey(const Key('notification-bell')), findsOneWidget);

    // Outro perfil não vê o ícone e é devolvido da rota de notificações.
    const teacher = AppUser(
      uid: 't',
      email: 'prof@caminhoazul.test',
      role: UserRole.school,
      schoolRole: SchoolRole.teacher,
      institutionIds: ['escola-a'],
    );
    await tester.pumpWidget(
        _app(repository, user: teacher, route: AppRoutes.notifications));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notification-bell')), findsNothing);
    expect(find.text('Você não possui acesso a esta área.'), findsOneWidget);
  });

  test('N-03: só eventos relevantes e visíveis à família notificam', () {
    expect(FamilyNotificationKind.notifies(TimelineEventType.caseApproved, 'familia'), isTrue);
    expect(FamilyNotificationKind.notifies(TimelineEventType.healthReturnCreated, 'restrito'), isFalse);
    expect(FamilyNotificationKind.notifies(TimelineEventType.observationCreated, 'interno'), isFalse);
    expect(FamilyNotificationKind.notifies(TimelineEventType.caseCreated, 'familia'), isFalse);
    expect(FamilyNotificationKind.notifies(TimelineEventType.referralComplementAnswered, 'familia'), isFalse);
    expect(FamilyNotification.idFor('c1', 'e1'), 'c1_e1');
    // Textos fixos e administrativos para todos os tipos.
    for (final kind in FamilyNotificationKind.values) {
      expect(kind.title, isNotEmpty);
      expect(kind.message.length, lessThan(90));
    }
  });
}
