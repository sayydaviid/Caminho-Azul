// Auditoria funcional pela INTERFACE do app real, contra o Firebase Emulator
// Suite (projeto demo-caminhoazul). O admin cria instituições e contas pelo
// painel; cada usuário ativa a conta (código OOB do Auth Emulator), entra pela
// tela de login e opera as próprias telas.
//
// Pré-requisitos: emuladores ativos e seed aplicado (admin inicial).
// Executar:
//   flutter test integration_test/ui_journey_test.dart -d emulator-5554 \
//     --dart-define=USE_FIREBASE_EMULATORS=true
import 'package:caminho_azul/app/app.dart';
import 'package:caminho_azul/app/firebase_config.dart';
import 'package:caminho_azul/firebase_options.dart';
import 'package:caminho_azul/screens/admin_screen.dart';
import 'package:caminho_azul/screens/casos_screen.dart';
import 'package:caminho_azul/screens/encaminhamentos_screen.dart';
import 'package:caminho_azul/screens/estudantes_screen.dart';
import 'package:caminho_azul/screens/familia_acompanhamento_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/ui_driver.dart';

const _seedPassword =
    String.fromEnvironment('SEED_PASSWORD', defaultValue: 'Sintetico#2026');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final s = (DateTime.now().millisecondsSinceEpoch % 100000).toString();
  String mail(String who) => 'aud.$who.$s@caminhoazul.test';

  final schoolA = 'Escola Auditoria A $s';
  final schoolB = 'Escola Auditoria B $s';
  final ubsA = 'UBS Auditoria A $s';
  final ubsB = 'UBS Auditoria B $s';

  setUpAll(() async {
    if (!useFirebaseEmulators) {
      fail('Execute com --dart-define=USE_FIREBASE_EMULATORS=true');
    }
    // Mesma inicialização do main.dart.
    await Firebase.initializeApp(
      options: firebaseOptionsFor(
        DefaultFirebaseOptions.currentPlatform,
        useEmulators: true,
      ),
    );
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: false);
    await configureFirebaseAuth(FirebaseAuth.instance);
    FirebaseFirestore.instance.useFirestoreEmulator(firebaseEmulatorHost, 8080);
  });

  void step(String text) => debugPrint('[ETAPA] $text');

  testWidgets('jornada completa pela interface', (tester) async {
    final ui = UiDriver(tester);
    await tester.pumpWidget(const CaminhoAzulApp());

    // ---------- 1. Admin entra e cadastra instituições ----------
    step('1 admin entra');
    await ui.login('administracao', 'admin@caminhoazul.test', _seedPassword,
        lands: find.byType(AdminScreen));

    Future<void> createInstitution(String name, String typeLabel) async {
      await ui.tapKey('admin-tab-institutions');
      await ui.tapKey('admin-new-button');
      await ui.type('admin-form-name', name);
      await ui.tapKey('admin-form-type');
      await ui.tap(find.text(typeLabel).last);
      await ui.type('admin-form-street', 'Rua Sintética');
      await ui.type('admin-form-number', '10');
      await ui.type('admin-form-district', 'Bairro Fictício');
      await ui.type('admin-form-city', 'Cidade Sintética');
      await ui.type('admin-form-state', 'PA');
      await ui.type('admin-form-zipCode', '66000-000');
      await ui.tapKey('admin-form-submit');
      await ui.waitGone(find.byKey(const Key('admin-form-submit')),
          reason: 'formulário de instituição fechar');
      await ui.type('admin-search-field', name);
      await ui.waitFor(find.text(name), reason: 'instituição $name na lista');
    }

    step('1 cria 2 escolas e 2 UBS');
    await createInstitution(schoolA, 'Escola');
    await createInstitution(schoolB, 'Escola');
    await createInstitution(ubsA, 'UBS');
    await createInstitution(ubsB, 'UBS');

    // ---------- 2. Admin cria as contas operacionais ----------
    Future<void> createUser({
      required String name,
      required String email,
      required String roleKey,
      List<String> institutions = const [],
      String? student,
    }) async {
      await ui.tapKey('admin-tab-users');
      await ui.tapKey('admin-new-button');
      await ui.type('admin-form-fullName', name);
      await ui.type('admin-form-email', email);
      await ui.tapKey('admin-form-role');
      await ui.tapKey(roleKey);
      if (institutions.isNotEmpty) {
        await ui.tapKey('admin-form-institutions');
        for (final item in institutions) {
          await tester.enterText(
              find.descendant(
                  of: find.byType(AlertDialog), matching: find.byType(TextField)),
              item);
          await ui.settle();
          final tile = find.ancestor(
              of: find.descendant(
                  of: find.byType(AlertDialog), matching: find.text(item)),
              matching: find.byType(CheckboxListTile));
          await ui.tap(tile, reason: 'opção $item');
          final checked = tester.widget<CheckboxListTile>(tile).value;
          if (checked != true) {
            throw TestFailure('Instituição $item não ficou marcada. '
                'Tela: ${ui.visibleTexts()}');
          }
        }
        await ui.tap(find.descendant(
            of: find.byType(AlertDialog), matching: find.text('Aplicar')));
        await ui.waitGone(find.byType(AlertDialog), reason: 'seletor fechar');
        for (final item in institutions) {
          await ui.waitFor(find.textContaining(item),
              reason: 'instituição $item no formulário');
        }
      }
      if (student != null) {
        await ui.tapKey('admin-form-student');
        await ui.tap(find.textContaining(student).last);
      }
      await ui.tapKey('admin-form-submit');
      await ui.waitGone(find.byKey(const Key('admin-form-submit')),
          reason: 'formulário de usuário de $email fechar');
      await ui.type('admin-search-field', email);
      await ui.waitFor(find.textContaining(email),
          reason: '$email na lista de usuários');
    }

    final accounts = <String, ({String name, String role})>{
      mail('admin2'): (name: 'Admin Dois $s', role: 'admin-role-option-admin'),
      mail('direcao.a'): (
        name: 'Diretora Escola A $s',
        role: 'admin-school-role-option-director'
      ),
      mail('direcao.b'): (
        name: 'Diretor Escola B $s',
        role: 'admin-school-role-option-director'
      ),
      mail('prof.a'): (
        name: 'Professora Escola A $s',
        role: 'admin-school-role-option-teacher'
      ),
      mail('prof.a2'): (
        name: 'Professor Dois Escola A $s',
        role: 'admin-school-role-option-teacher'
      ),
      mail('prof.b'): (
        name: 'Professor Escola B $s',
        role: 'admin-school-role-option-teacher'
      ),
      mail('ubs.a'): (
        name: 'Diretora UBS A $s',
        role: 'admin-health-role-option-ubs_director'
      ),
      mail('ubs.b'): (
        name: 'Diretor UBS B $s',
        role: 'admin-health-role-option-ubs_director'
      ),
      mail('psi.a'): (
        name: 'Psicóloga UBS A $s',
        role: 'admin-health-role-option-psychologist'
      ),
      mail('psi.a2'): (
        name: 'Psicólogo Dois UBS A $s',
        role: 'admin-health-role-option-psychologist'
      ),
    };
    String institutionOf(String email) => switch (email.split('.')[1]) {
          'direcao' || 'prof' =>
            email.contains('.b.') ? schoolB : schoolA,
          'ubs' => email.contains('.b.') ? ubsB : ubsA,
          'psi' => ubsA,
          _ => '',
        };

    step('2 admin cria ${accounts.length} contas pelo painel');
    for (final entry in accounts.entries) {
      final institution = institutionOf(entry.key);
      await createUser(
        name: entry.value.name,
        email: entry.key,
        roleKey: entry.value.role,
        institutions: institution.isEmpty ? const [] : [institution],
      );
      // Sessão do admin preservada após cada criação.
      expect(find.byType(AdminScreen), findsOneWidget);
    }

    // Persistência: perfis, profissionais e auditoria.
    step('2 confere Firestore e Auth');
    final db = FirebaseFirestore.instance;
    for (final email in accounts.keys) {
      final users =
          await db.collection('users').where('email', isEqualTo: email).get();
      expect(users.docs, hasLength(1), reason: email);
      final data = users.docs.single.data();
      expect(data['active'], isTrue, reason: email);
      expect(data.toString().toLowerCase().contains('senha'), isFalse);
      if (data['role'] == 'school' || data['role'] == 'health') {
        expect((data['institutionIds'] as List), hasLength(1), reason: email);
        final professional =
            await db.doc('professionals/${data['professionalId']}').get();
        expect(professional.get('userId'), users.docs.single.id, reason: email);
      }
      final audit = await db
          .collection('adminAuditLogs')
          .where('targetId', isEqualTo: users.docs.single.id)
          .where('action', isEqualTo: 'user.create')
          .get();
      expect(audit.docs, hasLength(1), reason: 'auditoria de $email');
    }

    // ---------- 3. Ativação e primeiro acesso de cada perfil ----------
    step('3 ativação pelos links OOB');
    for (final email in accounts.keys) {
      await ui.activate(email);
    }
    await ui.logout();

    final landing = <String, (String, Finder)>{
      mail('admin2'): ('administracao', find.byType(AdminScreen)),
      mail('direcao.a'): ('escola', find.byType(CasosScreen)),
      mail('prof.a'): ('escola', find.byType(CasosScreen)),
      mail('ubs.a'): ('saude', find.byType(EncaminhamentosScreen)),
      mail('psi.a'): ('saude', find.byType(EncaminhamentosScreen)),
    };
    for (final entry in landing.entries) {
      step('3 primeiro login: ${entry.key}');
      await ui.login(entry.value.$1, entry.key, activationPassword,
          lands: entry.value.$2);
      await ui.logout();
    }

    // ---------- 4. Direção escolar cadastra estudantes ----------
    step('4 Direção A cadastra estudantes');
    await ui.login('escola', mail('direcao.a'), activationPassword,
        lands: find.byType(CasosScreen));
    await ui.tapText('Estudantes');
    await ui.waitFor(find.byType(EstudantesScreen));
    final studentA = 'Estudante Sintético A $s';
    final studentA2 = 'Estudante Sintético A2 $s';
    for (final name in [studentA, studentA2]) {
      await ui.tapKey('students-new-button');
      await ui.type('student-form-name', name);
      await ui.type('student-form-grade', '3º ano');
      await ui.tapKey('student-form-submit');
      await ui.waitFor(find.text(name), reason: 'estudante $name na lista');
    }
    await ui.logout();

    // ---------- 5. Admin cria as contas familiares vinculadas ----------
    step('5 admin cria famílias vinculadas aos estudantes');
    await ui.login('administracao', 'admin@caminhoazul.test', _seedPassword,
        lands: find.byType(AdminScreen));
    await createUser(
        name: 'Família Sintética A $s',
        email: mail('familia.a'),
        roleKey: 'admin-role-option-family',
        student: studentA);
    await createUser(
        name: 'Família Sintética A2 $s',
        email: mail('familia.a2'),
        roleKey: 'admin-role-option-family',
        student: studentA2);
    await ui.activate(mail('familia.a'));
    await ui.activate(mail('familia.a2'));
    await ui.logout();

    step('5 família entra (sem caso aprovado ainda)');
    await ui.login('familia', mail('familia.a'), activationPassword,
        lands: find.byType(FamiliaAcompanhamentoScreen));
    await ui.waitFor(find.byKey(const Key('family-empty')),
        reason: 'família sem caso aprovado');
    await ui.logout();
    step('FIM fase 1');

    Finder keyPrefix(String prefix) => find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith(prefix));
    Future<void> answer(String text) async {
      await ui.type('ask-text-field', text);
      await ui.tapKey('ask-text-submit');
    }

    // ---------- 6. Professor cria o caso e os registros ----------
    step('6 professor cria caso, observação e registro');
    await ui.login('escola', mail('prof.a'), activationPassword,
        lands: find.byType(CasosScreen));
    await ui.tapKey('cases-new-button');
    await ui.tap(find.descendant(
        of: find.byType(Dialog), matching: find.textContaining(studentA)));
    await ui.expectSnack('Caso registrado.');
    await ui.waitFor(find.byKey(const Key('case-detail-status')),
        reason: 'detalhe do caso');
    const observation = 'Observação sintética de interação em sala';
    await ui.tapKey('case-add-observation');
    await ui.type('observation-context', 'Sala de aula');
    await ui.type('observation-description', observation);
    await ui.tapKey('case-form-submit');
    await ui.expectSnack('Observação registrada.');
    await ui.waitFor(find.text(observation), reason: 'observação na tela');
    await ui.tapKey('case-add-record');
    await ui.type('record-summary', 'Síntese pedagógica sintética');
    await ui.type('record-actions', 'Rotina visual\nPausas programadas');
    await ui.tap(keyPrefix('record-observation-'), reason: 'vincular observação');
    await ui.tapKey('case-form-submit');
    await ui.expectSnack('Registro pedagógico salvo.');
    await ui.waitFor(find.textContaining('1 observação(ões) referenciada(s)'),
        reason: 'registro com observação vinculada');
    await ui.tapKey('case-submit-button');
    await ui.expectSnack('Caso enviado à Direção escolar.');
    await ui.waitGone(find.byKey(const Key('case-add-observation')),
        reason: 'professor sem edição após envio');
    step('6 professor gera o relatório pedagógico (PDF)');
    await ui.generatePdf('case-generate-pdf', ['observations', 'records']);
    await ui.logout();

    step('6 família não vê caso antes da aprovação');
    await ui.login('familia', mail('familia.a'), activationPassword,
        lands: find.byType(FamiliaAcompanhamentoScreen));
    await ui.waitFor(find.byKey(const Key('family-empty')));
    await ui.logout();

    // ---------- 7. Direção aprova e encaminha a duas UBS ----------
    step('7 Direção aprova e encaminha às UBS A e B');
    await ui.login('escola', mail('direcao.a'), activationPassword,
        lands: find.byType(CasosScreen));
    await ui.tap(find.textContaining(studentA), reason: 'caso na lista');
    await ui.waitFor(find.byKey(const Key('case-detail-status')));
    expect(find.byKey(const Key('case-add-observation')), findsNothing,
        reason: 'Direção não registra observação');
    await ui.tapKey('case-approve');
    await ui.tapKey('confirm-action');
    await ui.expectSnack('Caso aprovado');
    for (final ubs in [ubsA, ubsB]) {
      await ui.tapKey('case-send-referral');
      await ui.tapKey('referral-ubs');
      await ui.tap(find.text(ubs).last);
      await ui.type('referral-reason', 'Motivo sintético para $ubs');
      await ui.type('referral-summary', 'Resumo mínimo sintético');
      await ui.tapKey('referral-submit');
      await ui.expectSnack('Encaminhamento enviado à UBS.');
    }
    await ui.waitFor(find.text(ubsA), reason: 'encaminhamento A na escola');
    await ui.waitFor(find.text(ubsB), reason: 'encaminhamento B na escola');
    await ui.logout();

    // ---------- 8. UBS A recebe e atribui; UBS B recusa ----------
    step('8 UBS A recebe e atribui psicóloga');
    await ui.login('saude', mail('ubs.a'), activationPassword,
        lands: find.byType(EncaminhamentosScreen));
    await ui.waitFor(keyPrefix('referral-tile-'));
    expect(keyPrefix('referral-tile-'), findsOneWidget,
        reason: 'UBS A vê só o próprio encaminhamento');
    await ui.tap(keyPrefix('referral-tile-'));
    await ui.tapKey('referral-receive');
    await ui.expectSnack('Recebimento registrado.');
    await ui.tapKey('referral-assign');
    await ui.tap(find.text(accounts[mail('psi.a')]!.name).last);
    await ui.expectSnack('Responsável definido');
    await ui.logout();

    step('8 UBS B vê só o seu e recusa com justificativa');
    await ui.login('saude', mail('ubs.b'), activationPassword,
        lands: find.byType(EncaminhamentosScreen));
    await ui.waitFor(keyPrefix('referral-tile-'));
    expect(keyPrefix('referral-tile-'), findsOneWidget,
        reason: 'UBS B vê só o próprio encaminhamento');
    await ui.tap(keyPrefix('referral-tile-'));
    await ui.tapKey('referral-refuse');
    await answer('Justificativa sintética: fora da área de abrangência');
    await ui.expectSnack('Encaminhamento recusado.');
    await ui.logout();

    // ---------- 9. Psicóloga atende e registra devolutiva ----------
    step('9 psicóloga inicia, registra nota e devolutiva');
    const progress = 'Nota restrita sintética da psicóloga';
    const healthReturn = 'Devolutiva sintética para escola e família';
    await ui.login('saude', mail('psi.a'), activationPassword,
        lands: find.byType(EncaminhamentosScreen));
    await ui.tap(keyPrefix('referral-tile-'));
    await ui.tapKey('referral-start');
    await ui.expectSnack('Atendimento iniciado.');
    await ui.tapKey('referral-progress');
    await answer(progress);
    await ui.expectSnack('Atualização registrada.');
    await ui.tapKey('referral-health-return');
    await ui.type('health-return-content', healthReturn);
    await ui.tapKey('health-return-family');
    await ui.tapKey('health-return-submit');
    await ui.expectSnack('Devolutiva registrada.');
    step('9 psicóloga gera a devolutiva profissional (PDF)');
    await ui.generatePdf('referral-generate-pdf', ['returns']);
    await ui.logout();

    // ---------- 10. Família acompanha ----------
    step('10 família vê caso, histórico e devolutiva; não vê nota restrita');
    await ui.login('familia', mail('familia.a'), activationPassword,
        lands: find.byType(FamiliaAcompanhamentoScreen));
    await ui.waitFor(keyPrefix('family-case-status-'), reason: 'caso aprovado');
    await ui.waitFor(find.textContaining(healthReturn),
        reason: 'devolutiva destinada à família');
    expect(find.textContaining(progress), findsNothing);
    expect(find.textContaining(observation), findsNothing);
    expect(find.byType(FilledButton), findsNothing,
        reason: 'família sem ações de escrita');

    // N-01..N-04: aprovação, 2 envios, recebimento, atribuição, recusa,
    // início do atendimento e devolutiva para a família = 8 notificações.
    step('10 família: contador, abrir notificação e marcar como lida');
    Finder count(String n) => find.descendant(
        of: find.byKey(const Key('notification-bell')), matching: find.text(n));
    await ui.waitFor(count('8'), reason: '8 notificações não lidas');
    await ui.tapKey('notification-bell');
    await ui.waitFor(find.text('Nova devolutiva'), reason: 'central de notificações');
    expect(find.textContaining(healthReturn), findsNothing,
        reason: 'notificação sem o conteúdo da devolutiva');
    expect(find.textContaining('fora da área'), findsNothing,
        reason: 'notificação sem a justificativa da recusa');
    await ui.tap(find.text('Nova devolutiva'), reason: 'abrir notificação');
    await ui.waitFor(keyPrefix('family-case-status-'), reason: 'caso aberto pela notificação');
    await ui.waitFor(count('7'), reason: 'notificação aberta marcada como lida');
    await ui.tapKey('notification-bell');
    await ui.tapKey('notifications-mark-all');
    await ui.waitFor(find.text('Todas lidas'), reason: 'todas lidas');
    await ui.waitGone(find.byKey(const Key('notification-count')), reason: 'contador zerado');
    await ui.tap(find.text('Família').last, reason: 'voltar ao acompanhamento');
    step('10 família gera relatório só com o conteúdo dela (PDF)');
    await ui.generatePdf(
        'family-generate-pdf-${(tester.widget(keyPrefix('family-case-status-')).key as ValueKey<String>).value.replaceFirst('family-case-status-', '')}',
        ['timeline', 'returns']);
    await ui.logout();

    step('10 outra família não vê o estudante A');
    await ui.login('familia', mail('familia.a2'), activationPassword,
        lands: find.byType(FamiliaAcompanhamentoScreen));
    await ui.waitFor(find.byKey(const Key('family-empty')));
    expect(find.textContaining(healthReturn), findsNothing);
    expect(find.byKey(const Key('notification-count')), findsNothing,
        reason: 'outra família sem notificações do estudante A');
    await ui.tapKey('notification-bell');
    await ui.waitFor(find.byKey(const Key('notifications-empty')));
    await ui.logout();

    // ---------- 11. UBS finaliza; Direção vê devolutiva e conclui ----------
    step('11 UBS A finaliza');
    await ui.login('saude', mail('ubs.a'), activationPassword,
        lands: find.byType(EncaminhamentosScreen));
    await ui.tap(keyPrefix('referral-tile-'));
    expect(find.textContaining(progress), findsNothing,
        reason: 'Direção UBS não lê nota restrita da psicóloga');
    await ui.tapKey('referral-finalize');
    await ui.expectSnack('Encaminhamento finalizado.');
    await ui.logout();

    step('11 Direção escolar vê devolutiva e conclui');
    await ui.login('escola', mail('direcao.a'), activationPassword,
        lands: find.byType(CasosScreen));
    await ui.tap(find.textContaining(studentA), reason: 'caso na lista');
    await ui.waitFor(keyPrefix('school-return-'), reason: 'devolutiva à escola');
    step('11 Direção gera o relatório de acompanhamento escolar (PDF)');
    await ui.generatePdf('case-generate-pdf', ['timeline', 'records', 'returns']);
    await ui.tapKey('case-conclude');
    await ui.tapKey('confirm-action');
    await ui.expectSnack('Acompanhamento concluído.');
    await ui.logout();

    // ---------- 12. Persistência após novo login ----------
    step('12 professor e família reabrem e veem o caso concluído');
    await ui.login('escola', mail('prof.a'), activationPassword,
        lands: find.byType(CasosScreen));
    await ui.tap(find.textContaining(studentA), reason: 'caso na lista');
    await ui.waitFor(find.text(observation), reason: 'observação persistida');
    await ui.waitFor(find.text('Concluído'), reason: 'status concluído');
    expect(find.byKey(const Key('case-add-observation')), findsNothing);
    await ui.logout();
    await ui.login('familia', mail('familia.a'), activationPassword,
        lands: find.byType(FamiliaAcompanhamentoScreen));
    await ui.waitFor(find.textContaining(healthReturn));
    // Leitura persistida entre sessões: só finalização e conclusão estão novas.
    await ui.waitFor(count('2'), reason: 'só as 2 notificações novas não lidas');
    await ui.logout();
    step('FIM fase 2');
  });
}
