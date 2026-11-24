// Jornadas alternativas pela INTERFACE do app real, contra o Firebase Emulator
// Suite (demo-caminhoazul). Usa as instituições e contas do seed e cria pelo
// painel as contas extras (2º professor, 2º psicólogo e família).
//
// Executar (emuladores + seed):
//   flutter test integration_test/ui_alternatives_test.dart -d emulator-5554 \
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

const _seed =
    String.fromEnvironment('SEED_PASSWORD', defaultValue: 'Sintetico#2026');
const _schoolA = 'Escola Municipal Azul (sintética)';
const _ubsA = 'UBS Horizonte (sintética)';
const _ubsB = 'UBS Aurora (sintética)';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final s = (DateTime.now().millisecondsSinceEpoch % 100000).toString();

  setUpAll(() async {
    if (!useFirebaseEmulators) {
      fail('Execute com --dart-define=USE_FIREBASE_EMULATORS=true');
    }
    await Firebase.initializeApp(
      options: firebaseOptionsFor(DefaultFirebaseOptions.currentPlatform,
          useEmulators: true),
    );
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: false);
    await configureFirebaseAuth(FirebaseAuth.instance);
    FirebaseFirestore.instance.useFirestoreEmulator(firebaseEmulatorHost, 8080);
  });

  void step(String text) => debugPrint('[ETAPA] $text');
  Finder keyPrefix(String prefix) => find.byWidgetPredicate((w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith(prefix));

  testWidgets('jornadas alternativas pela interface', (tester) async {
    final ui = UiDriver(tester);
    Future<void> answer(String text) async {
      await ui.type('ask-text-field', text);
      await ui.tapKey('ask-text-submit');
    }

    Future<void> openCase(String student) async {
      await ui.tap(find.textContaining(student), reason: 'caso de $student');
      await ui.waitFor(find.byKey(const Key('case-detail-status')));
    }

    Future<void> openReferralOf(String student) async {
      await ui.tap(
          find.ancestor(
              of: find.textContaining(student),
              matching: keyPrefix('referral-tile-')),
          reason: 'encaminhamento de $student');
      await ui.waitFor(find.text('Encaminhamento'));
    }

    await tester.pumpWidget(const CaminhoAzulApp());
    final student = 'Estudante Alternativo $s';
    final prof2 = 'Professora Alternativa $s';
    final psi2 = 'Psicólogo Alternativo $s';
    final prof2Mail = 'aud.alt.prof2.$s@caminhoazul.test';
    final psi2Mail = 'aud.alt.psi2.$s@caminhoazul.test';
    final familyMail = 'aud.alt.familia.$s@caminhoazul.test';

    // ---------- Preparação pelo painel ----------
    step('A0 admin cria 2º professor e 2º psicólogo; Direção cadastra estudante');
    await ui.login('administracao', 'admin@caminhoazul.test', _seed,
        lands: find.byType(AdminScreen));
    await ui.adminCreateUser(
        name: prof2,
        email: prof2Mail,
        roleKey: 'admin-school-role-option-teacher',
        institutions: const [_schoolA]);
    await ui.adminCreateUser(
        name: psi2,
        email: psi2Mail,
        roleKey: 'admin-health-role-option-psychologist',
        institutions: const [_ubsA]);
    await ui.activate(prof2Mail);
    await ui.activate(psi2Mail);
    await ui.logout();

    await ui.login('escola', 'direcao.escola@caminhoazul.test', _seed,
        lands: find.byType(CasosScreen));
    await ui.tapText('Estudantes');
    await ui.waitFor(find.byType(EstudantesScreen));
    await ui.tapKey('students-new-button');
    await ui.type('student-form-name', student);
    await ui.tapKey('student-form-submit');
    await ui.expectSnack('Estudante cadastrado');
    await ui.logout();

    await ui.login('administracao', 'admin@caminhoazul.test', _seed,
        lands: find.byType(AdminScreen));
    await ui.adminCreateUser(
        name: 'Família Alternativa $s',
        email: familyMail,
        roleKey: 'admin-role-option-family',
        student: student);
    await ui.activate(familyMail);
    await ui.logout();

    // ---------- Complementação escolar ----------
    step('A1 professor abre caso e envia; Direção pede complementação');
    await ui.login('escola', 'professor@caminhoazul.test', _seed,
        lands: find.byType(CasosScreen));
    await ui.tapKey('cases-new-button');
    await ui.tap(find.descendant(
        of: find.byType(Dialog), matching: find.textContaining(student)));
    await ui.expectSnack('Caso registrado.');
    await ui.tapKey('case-add-observation');
    await ui.type('observation-context', 'Recreio');
    await ui.type('observation-description', 'Observação inicial alternativa');
    await ui.tapKey('case-form-submit');
    await ui.expectSnack('Observação registrada.');
    await ui.tapKey('case-submit-button');
    await ui.expectSnack('Caso enviado à Direção escolar.');
    await ui.logout();

    await ui.login('escola', 'direcao.escola@caminhoazul.test', _seed,
        lands: find.byType(CasosScreen));
    await openCase(student);
    await ui.tapKey('case-request-complement');
    await ui.tapKey('confirm-action');
    await ui.expectSnack('Complementação solicitada ao professor.');
    await ui.waitFor(find.text('Complementação solicitada'));
    await ui.logout();

    step('A1 professor complementa; Direção revisa e aprova');
    await ui.login('escola', 'professor@caminhoazul.test', _seed,
        lands: find.byType(CasosScreen));
    await openCase(student);
    await ui.tapKey('case-add-observation');
    await ui.type('observation-context', 'Sala de aula');
    await ui.type('observation-description', 'Complemento solicitado pela Direção');
    await ui.tapKey('case-form-submit');
    await ui.expectSnack('Observação registrada.');
    await ui.waitFor(find.text('Enviar complementação'));
    await ui.tapKey('case-submit-button');
    await ui.expectSnack('Caso enviado à Direção escolar.');
    await ui.logout();

    await ui.login('escola', 'direcao.escola@caminhoazul.test', _seed,
        lands: find.byType(CasosScreen));
    await openCase(student);
    await ui.waitFor(find.text('Complemento solicitado pela Direção'),
        reason: 'Direção revisa a complementação');
    await ui.waitFor(find.text('Complementação enviada pelo professor'),
        reason: 'evento de complementação na linha do tempo');
    await ui.tapKey('case-approve');
    await ui.tapKey('confirm-action');
    await ui.expectSnack('Caso aprovado');

    // ---------- Múltiplos professores ----------
    step('A2 Direção vincula 2º professor e desvincula o original');
    await ui.tapKey('case-teachers-edit');
    await ui.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text(prof2)));
    await ui.tapKey('case-teacher-primary');
    await ui.tap(find.text(prof2).last);
    await ui.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Professor Sintético')));
    await ui.tapKey('case-teachers-save');
    await ui.expectSnack('Professores do caso atualizados.');
    await ui.waitFor(find.text('$prof2 (principal)'));

    // ---------- Múltiplas UBS ----------
    step('A3 Direção encaminha às UBS A e B');
    for (final ubs in [_ubsA, _ubsB]) {
      await ui.tapKey('case-send-referral');
      await ui.tapKey('referral-ubs');
      await ui.tap(find.text(ubs).last);
      await ui.type('referral-reason', 'Motivo alternativo');
      await ui.type('referral-summary', 'Resumo alternativo');
      await ui.tapKey('referral-submit');
      await ui.expectSnack('Encaminhamento enviado à UBS.');
    }
    await ui.logout();

    step('A2 professor desvinculado não vê o caso; 2º professor vê');
    await ui.login('escola', 'professor@caminhoazul.test', _seed,
        lands: find.byType(CasosScreen));
    await ui.settle(2000);
    expect(find.textContaining(student), findsNothing,
        reason: 'professor desvinculado perdeu o acesso');
    await ui.logout();
    await ui.login('escola', prof2Mail, activationPassword,
        lands: find.byType(CasosScreen));
    await openCase(student);
    await ui.logout();

    // ---------- Recusa administrativa ----------
    step('A4 UBS B recusa; escola vê; família vê só o status');
    const refusal = 'Justificativa alternativa da recusa';
    await ui.login('saude', 'direcao.ubs.b@caminhoazul.test', _seed,
        lands: find.byType(EncaminhamentosScreen));
    await openReferralOf(student);
    await ui.tapKey('referral-refuse');
    await answer(refusal);
    await ui.expectSnack('Encaminhamento recusado.');
    await ui.logout();

    await ui.login('escola', 'direcao.escola@caminhoazul.test', _seed,
        lands: find.byType(CasosScreen));
    await openCase(student);
    await ui.waitFor(find.text('Recusado pela UBS'), reason: 'status na escola');
    await ui.waitFor(find.textContaining(refusal),
        reason: 'Direção vê a justificativa');
    await ui.logout();

    await ui.login('familia', familyMail, activationPassword,
        lands: find.byType(FamiliaAcompanhamentoScreen));
    await ui.waitFor(find.text('Recusado pela UBS'), reason: 'status na família');
    expect(find.textContaining(refusal), findsNothing,
        reason: 'família não vê a justificativa interna');
    await ui.logout();

    // ---------- Complementação pedida pela UBS ----------
    step('A5 UBS A recebe, atribui e pede complementação');
    await ui.login('saude', 'direcao.ubs@caminhoazul.test', _seed,
        lands: find.byType(EncaminhamentosScreen));
    await openReferralOf(student);
    await ui.tapKey('referral-receive');
    await ui.expectSnack('Recebimento registrado.');
    await ui.tapKey('referral-assign');
    await ui.tap(find.text('Psicóloga Sintética').last);
    await ui.expectSnack('Responsável definido');
    await ui.tapKey('referral-request-complement');
    await answer('Pedido alternativo de complementação');
    await ui.expectSnack('Complementação solicitada à Direção escolar.');
    await ui.logout();

    step('A5 Direção repassa ao professor; professor complementa');
    await ui.login('escola', 'direcao.escola@caminhoazul.test', _seed,
        lands: find.byType(CasosScreen));
    await openCase(student);
    await ui.waitFor(find.textContaining('Pedido alternativo de complementação'));
    await ui.tapKey('referral-forward-teacher');
    await ui.expectSnack('Pedido repassado ao professor.');
    await ui.logout();

    await ui.login('escola', prof2Mail, activationPassword,
        lands: find.byType(CasosScreen));
    await openCase(student);
    await ui.waitFor(find.byKey(const Key('case-complement-open')));
    await ui.tapKey('case-add-observation');
    await ui.type('observation-context', 'Pátio');
    await ui.type('observation-description', 'Informação complementar para a UBS');
    await ui.tapKey('case-form-submit');
    await ui.expectSnack('Observação registrada.');
    await ui.logout();

    step('A5 Direção revisa e responde à UBS; UBS recebe');
    const answerText = 'Resposta autorizada da escola para a UBS';
    await ui.login('escola', 'direcao.escola@caminhoazul.test', _seed,
        lands: find.byType(CasosScreen));
    await openCase(student);
    await ui.waitFor(find.text('Informação complementar para a UBS'));
    await ui.tapKey('referral-answer-ubs');
    await answer(answerText);
    await ui.expectSnack('Complementação enviada à UBS.');
    await ui.logout();

    await ui.login('saude', 'direcao.ubs@caminhoazul.test', _seed,
        lands: find.byType(EncaminhamentosScreen));
    await openReferralOf(student);
    await ui.waitFor(find.textContaining(answerText),
        reason: 'UBS recebe a resposta autorizada');
    expect(find.text('Informação complementar para a UBS'), findsNothing,
        reason: 'UBS não lê observação interna da escola');

    // ---------- Transferência de psicólogo ----------
    step('A6 UBS transfere para o 2º psicólogo');
    await ui.tapKey('referral-assign');
    await ui.tap(find.text(psi2).last);
    await ui.expectSnack('Responsável definido: $psi2');
    await ui.logout();

    await ui.login('saude', 'psicologo@caminhoazul.test', _seed,
        lands: find.byType(EncaminhamentosScreen));
    await ui.settle(2000);
    expect(find.textContaining(student), findsNothing,
        reason: 'psicóloga anterior perdeu o acesso');
    await ui.logout();

    await ui.login('saude', psi2Mail, activationPassword,
        lands: find.byType(EncaminhamentosScreen));
    await openReferralOf(student);
    await ui.tapKey('referral-start');
    await ui.expectSnack('Atendimento iniciado.');
    await ui.logout();

    // ---------- Desativação ----------
    step('A7 admin desativa o 2º psicólogo; login bloqueado; histórico mantido');
    await ui.login('administracao', 'admin@caminhoazul.test', _seed,
        lands: find.byType(AdminScreen));
    await ui.tapKey('admin-tab-users');
    await ui.type('admin-search-field', psi2Mail);
    await ui.tap(find.byTooltip('Editar'));
    await ui.tapKey('admin-form-delete-user');
    await ui.tapKey('admin-confirm-delete-user');
    await ui.waitGone(find.byKey(const Key('admin-form-submit')));
    await ui.waitFor(find.text('Inativo'), reason: 'conta marcada como inativa');
    step('A7 admin consulta a auditoria (P1-12)');
    await ui.tapKey('admin-tab-audit');
    await ui.type('admin-search-field', psi2);
    await ui.waitFor(find.text('Usuário desativado'),
        reason: 'desativação registrada na auditoria');
    await ui.waitFor(find.text('Usuário criado'),
        reason: 'criação registrada na auditoria');
    await ui.logout();

    await ui.tapKey('access-profile-saude');
    await ui.type('login-email-field', psi2Mail);
    await ui.type('login-password-field', activationPassword);
    await ui.tapKey('login-submit-button');
    await ui.expectSnack('desativado');
    expect(find.byType(EncaminhamentosScreen), findsNothing);

    await ui.login('saude', 'direcao.ubs@caminhoazul.test', _seed,
        lands: find.byType(EncaminhamentosScreen));
    await openReferralOf(student);
    await ui.waitFor(find.text('Atendimento iniciado'),
        reason: 'histórico preservado após desativação');
    await ui.logout();
    step('FIM alternativas');
  });
}
