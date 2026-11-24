// Auxiliares para operar o app real pela interface (toques e digitação)
// contra o Firebase Emulator Suite. Nenhuma chamada direta a repositórios.
import 'dart:convert';
import 'dart:io';

import 'package:caminho_azul/app/firebase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Senha definida pelos usuários sintéticos na ativação (somente emulador).
const activationPassword = 'Ativacao#Sintetica1';

class UiDriver {
  UiDriver(this.tester);
  final WidgetTester tester;

  /// `evaluate()` seguro para finders com `.last`/`.first` (vazios lançam).
  bool present(Finder finder) {
    try {
      return finder.evaluate().isNotEmpty;
    } on StateError {
      return false;
    }
  }

  Future<void> settle([int ms = 300]) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    await tester.pump();
  }

  /// Textos visíveis, para diagnosticar falhas.
  /// Prioriza o fim da árvore (diálogos, folhas e snackbars ficam por cima).
  String visibleTexts() {
    final texts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .where((t) => t.trim().isNotEmpty)
        .toList();
    final spinners = find.byType(CircularProgressIndicator).evaluate().length;
    final routes = find
        .byType(Scaffold)
        .evaluate()
        .map((e) => ModalRoute.of(e)?.settings.name ?? '-')
        .toSet()
        .join(',');
    final interesting = RegExp(
        r'Navigator|ModalScope|Scaffold|Drawer|Guard|Screen|BottomSheet|Dialog|StreamBuilder|ErrorWidget|Placeholder');
    final tree = <String>[];
    void visit(Element e, int depth) {
      final name = e.widget.runtimeType.toString();
      if (interesting.hasMatch(name) && tree.length < 60) {
        tree.add('${'-' * (depth ~/ 8)}$name');
      }
      e.visitChildren((c) => visit(c, depth + 1));
    }
    final root = WidgetsBinding.instance.rootElement;
    if (root != null) visit(root, 0);
    return '[rotas: $routes; carregando: $spinners]\n[árvore: ${tree.join(' ')}]\n'
        '${texts.skip(texts.length > 50 ? texts.length - 50 : 0).join(' | ')}';
  }

  Future<void> waitFor(Finder finder,
      {Duration timeout = const Duration(seconds: 25), String? reason}) async {
    final end = DateTime.now().add(timeout);
    var tries = 0;
    while (DateTime.now().isBefore(end)) {
      await settle(200);
      if (present(finder)) return;
      // Conteúdo fora da área visível de listas: rola como o usuário faria.
      if (++tries % 10 == 0) await reveal(finder);
    }
    throw TestFailure(
        'Tempo esgotado aguardando ${reason ?? finder}.\nTela: ${visibleTexts()}');
  }

  Future<void> waitGone(Finder finder,
      {Duration timeout = const Duration(seconds: 25), String? reason}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await settle(200);
      if (!present(finder)) return;
    }
    throw TestFailure(
        'Ainda visível: ${reason ?? finder}.\nTela: ${visibleTexts()}');
  }

  /// Rola a tela (para cima e para baixo) até o controle ser construído.
  Future<void> reveal(Finder finder) async {
    if (present(finder)) return;
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isEmpty) return;
    for (final delta in [-400.0, 400.0]) {
      for (var i = 0; i < 12 && !present(finder); i++) {
        final target = scrollables.evaluate().isEmpty ? null : scrollables.last;
        if (target == null) return;
        await tester.drag(target, Offset(0, -delta), warnIfMissed: false);
        await settle(150);
      }
      if (present(finder)) return;
    }
  }

  Future<void> tap(Finder finder, {String? reason}) async {
    final end = DateTime.now().add(const Duration(seconds: 3));
    while (!present(finder) && DateTime.now().isBefore(end)) {
      await settle(200);
    }
    await reveal(finder);
    await waitFor(finder, reason: reason);
    final target = finder.first;
    await tester.ensureVisible(target);
    await settle(150);
    await tester.tap(target, warnIfMissed: false);
    await settle(350);
  }

  Future<void> tapKey(String key) => tap(find.byKey(Key(key)), reason: key);
  Future<void> tapText(String text) => tap(find.text(text), reason: text);

  Future<void> type(String key, String value) async {
    final finder = find.byKey(Key(key));
    await reveal(finder);
    await waitFor(finder, reason: key);
    await tester.ensureVisible(finder.first);
    await tester.enterText(finder.first, value);
    await settle(150);
  }

  /// Espera uma SnackBar contendo [text] e a fecha.
  Future<void> expectSnack(String text,
      {Duration timeout = const Duration(seconds: 25)}) async {
    await waitFor(
      find.descendant(
          of: find.byType(SnackBar), matching: find.textContaining(text)),
      timeout: timeout,
      reason: 'snackbar "$text"',
    );
    ScaffoldMessenger.of(tester.element(find.byType(SnackBar).first))
        .removeCurrentSnackBar();
    await settle(200);
  }

  Future<void> login(String area, String email, String password,
      {required Finder lands}) async {
    await waitFor(find.byKey(const Key('login-submit-button')),
        reason: 'tela de login');
    await tapKey('access-profile-$area');
    await type('login-email-field', email);
    await type('login-password-field', password);
    await tapKey('login-submit-button');
    final end = DateTime.now().add(const Duration(seconds: 25));
    while (DateTime.now().isBefore(end)) {
      await settle(200);
      if (lands.evaluate().isNotEmpty) return;
      final snack = find.descendant(
          of: find.byType(SnackBar), matching: find.byType(Text));
      if (snack.evaluate().isNotEmpty &&
          find.byKey(const Key('login-submit-button')).evaluate().isNotEmpty) {
        throw TestFailure('Login de $email recusado: '
            '${snack.evaluate().map((e) => (e.widget as Text).data).join(' ')}');
      }
    }
    throw TestFailure('Tempo esgotado no login de $email.\nTela: ${visibleTexts()}');
  }

  /// R-06/R-07: abre a geração de PDF por [entryKey], seleciona os grupos
  /// [groups] (botão "Selecionar todos"), gera e espera a pré-visualização com
  /// a página renderizada; depois volta à tela de origem.
  Future<void> generatePdf(String entryKey, List<String> groups) async {
    await tap(find.byKey(Key(entryKey)), reason: entryKey);
    await waitFor(find.byKey(const Key('report-generate')),
        reason: 'tela de geração de PDF');
    for (final group in groups) {
      await tapKey('report-toggle-$group');
    }
    await tapKey('report-generate');
    final preview = find.byKey(const Key('report-preview'));
    await waitFor(preview, timeout: const Duration(seconds: 40), reason: 'pré-visualização');
    await waitFor(find.descendant(of: preview, matching: find.byType(Image)),
        timeout: const Duration(seconds: 40), reason: 'página do PDF renderizada');
    for (var i = 0; i < 2; i++) {
      await tap(find.byType(BackButton).last, reason: 'voltar');
      await settle(800);
    }
  }

  /// Sai pela interface: menu do perfil (admin) ou menu lateral (demais).
  Future<void> logout() async {
    for (var i = 0; i < 4; i++) {
      final back = find.byType(BackButton);
      if (back.evaluate().isEmpty) break;
      await tap(back);
      await settle(800); // espera a animação de saída da rota
    }
    if (find.byKey(const Key('admin-profile-menu')).evaluate().isNotEmpty) {
      await tapKey('admin-profile-menu');
      await tapText('Sair');
    } else {
      await tap(find.byTooltip('Open navigation menu'), reason: 'menu lateral');
      await tapText('Sair');
    }
    await waitFor(find.byKey(const Key('login-submit-button')),
        reason: 'login após sair');
  }

  /// Admin cria uma conta pelo painel (aba Usuários → Novo cadastro).
  Future<void> adminCreateUser({
    required String name,
    required String email,
    required String roleKey,
    List<String> institutions = const [],
    String? student,
  }) async {
    await tapKey('admin-tab-users');
    await tapKey('admin-new-button');
    await type('admin-form-fullName', name);
    await type('admin-form-email', email);
    await tapKey('admin-form-role');
    await tapKey(roleKey);
    if (institutions.isNotEmpty) {
      await tapKey('admin-form-institutions');
      for (final item in institutions) {
        await tester.enterText(
            find.descendant(
                of: find.byType(AlertDialog), matching: find.byType(TextField)),
            item);
        await settle();
        final tile = find.ancestor(
            of: find.descendant(
                of: find.byType(AlertDialog), matching: find.text(item)),
            matching: find.byType(CheckboxListTile));
        await tap(tile, reason: 'opção $item');
        if (tester.widget<CheckboxListTile>(tile).value != true) {
          throw TestFailure('Instituição $item não ficou marcada.');
        }
      }
      await tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Aplicar')));
      await waitGone(find.byType(AlertDialog), reason: 'seletor fechar');
    }
    if (student != null) {
      await tapKey('admin-form-student');
      await tap(find.textContaining(student).last);
    }
    await tapKey('admin-form-submit');
    await waitGone(find.byKey(const Key('admin-form-submit')),
        reason: 'formulário de usuário de $email fechar');
    await type('admin-search-field', email);
    await waitFor(find.textContaining(email),
        reason: '$email na lista de usuários');
  }

  /// Simula o usuário abrindo o link de ativação: lê o código OOB gerado pelo
  /// Auth Emulator e define a própria senha.
  Future<void> activate(String email) async {
    final client = HttpClient();
    try {
      final base = 'http://$firebaseEmulatorHost:9099';
      final list = await client.getUrl(Uri.parse(
          '$base/emulator/v1/projects/$emulatorProjectId/oobCodes'));
      final body =
          await (await list.close()).transform(utf8.decoder).join();
      final codes = (jsonDecode(body)['oobCodes'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .where((c) =>
              c['email'] == email && c['requestType'] == 'PASSWORD_RESET')
          .toList();
      if (codes.isEmpty) throw TestFailure('Sem e-mail de ativação para $email');
      final reset = await client.postUrl(Uri.parse(
          '$base/identitytoolkit.googleapis.com/v1/accounts:resetPassword?key=$emulatorApiKey'));
      reset.headers.contentType = ContentType.json;
      reset.write(jsonEncode({
        'oobCode': codes.last['oobCode'],
        'newPassword': activationPassword,
      }));
      final response = await reset.close();
      final result = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw TestFailure('Ativação de $email falhou: ${response.statusCode} '
            '${result.length > 200 ? result.substring(0, 200) : result}');
      }
    } finally {
      client.close();
    }
  }
}
