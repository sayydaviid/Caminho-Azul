# Documentação técnica

Este documento é para desenvolvedores. O guia para quem usa o aplicativo está
em [GUIA_DE_USO.md](GUIA_DE_USO.md).

**Stack:**
- Flutter 3.29 (Android e Web);
- Firebase Authentication e Cloud Firestore, no plano **Spark** (gratuito);
- sem Cloud Functions, sem backend próprio e sem Admin SDK no app.

## Estrutura

```text
lib/
  app/            roteamento, tema e configuração do Firebase (modo emulador, idioma dos e-mails)
  models/         usuários, estudantes, casos, encaminhamentos, notificações, auditoria
  repositories/   acesso ao Firestore (batches com evento na linha do tempo)
  services/       autenticação e criação de contas pelo admin
  screens/        login, administração, casos, estudantes, encaminhamentos, família
  widgets/        shell, guards de rota, seções do caso, formulários
  reports/        relatórios PDF gerados no aparelho
  utils/          utilitários
firestore.rules, firestore.indexes.json   regras de segurança e índices (publicados)
scripts/          seed sintético (somente emuladores), testes das regras, bootstrap do 1º admin
integration_test/ testes no app real contra os emuladores
test/             unidade, widgets, acessibilidade, PDF e notificações
docs/             guias, modelo de dados e marca
```

## Ambiente local (somente emuladores)

**Pré-requisitos:** Flutter 3.29, Node 22, Java 21 e Firebase CLI.

Os emuladores usam o projeto `demo-caminhoazul`, de modo que nada grava no
projeto real.

```bash
npm --prefix scripts install
npm --prefix scripts run emulators                     # Auth 9099 + Firestore 8080
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
  npm --prefix scripts run seed:emulator               # contas e dados sintéticos
flutter run --dart-define=USE_FIREBASE_EMULATORS=true  # Android Emulator ou Chrome
```

Sem `--dart-define=USE_FIREBASE_EMULATORS=true`, o app aponta para o projeto
real `caminhoazul`.

O seed (`scripts/seed_emulator.js`) recusa executar nestes casos:
- sem as variáveis de emulador;
- com host que não seja local;
- com projeto que não seja `demo-*`;
- com `GOOGLE_APPLICATION_CREDENTIALS` definido.

**Dispositivo físico com emuladores:**
1. Passe `--dart-define=FIREBASE_EMULATOR_HOST=<IP da máquina>`.
2. Acrescente esse IP em `android/app/src/debug/res/xml/network_security_config.xml`. Esse arquivo libera HTTP só no build debug.

**Telas de protótipo:** as telas antigas que usam dados fictícios só aparecem
com `--dart-define=CAMINHO_AZUL_DEMO=true`. Fora desse modo, a navegação mostra
apenas as telas reais.

## Testes

```bash
flutter analyze
flutter test                 # unidade, widgets, acessibilidade, PDF, notificações
npm --prefix scripts test    # seed + Security Rules (emulador isolado na porta 8180)
# Integração no Android Emulator, com emuladores ativos e seed recém-aplicado:
flutter test integration_test/<arquivo>.dart -d emulator-5554 --dart-define=USE_FIREBASE_EMULATORS=true
```

**Roteiros pela interface** (`integration_test/ui_*`): operam o app só por
toques e digitação, numa jornada completa e em alternativas.

**Resultado em 24/11/2026:**

| Verificação | Resultado |
|---|---|
| `flutter analyze` | 0 problemas |
| `flutter test` | 91 testes passando |
| Seed | 8 testes passando |
| Security Rules | 42 testes passando |

## Gerar o APK

```bash
flutter build apk --release
# saída: build/app/outputs/flutter-apk/app-release.apk
```

| Item | Valor |
|---|---|
| Pacote | `com.caminhoazul.caminho_azul` |
| Versão | `pubspec.yaml` (`version`) |
| Android mínimo | 6.0 (API 23) |
| Firebase | Projeto real (`lib/firebase_options.dart`) |

O release é assinado com a **chave de depuração**. Isso serve para instalar o
APK diretamente no celular, mas não serve para a Play Store.

Antes de publicar na loja:
1. gere uma chave de upload própria e guarde-a fora do repositório;
2. configure `signingConfigs` em `android/app/build.gradle.kts`;
3. suba o `versionCode` a cada envio.

## Firebase (projeto `caminhoazul`)

### Regras e índices

As regras e os índices **estão publicados** desde 24/11/2026: 20 índices
compostos. Para publicar de novo, depois de passar nos testes locais:

```bash
firebase deploy --only "firestore:rules,firestore:indexes" --project caminhoazul
```

Não há Functions para publicar, porque o plano Spark não as oferece.

### Contas e e-mails

- **Criação de contas pelo admin:**
  - a conta é criada numa instância secundária do Auth, de modo que a sessão do admin não muda;
  - uma senha temporária aleatória existe só em memória;
  - em seguida, o app envia o e-mail de redefinição de senha, que funciona como ativação.
- **Idioma dos e-mails:** é `pt-BR`, definido em `lib/app/firebase_config.dart`. O idioma padrão do projeto no Console continua `en`.
- **Nome que aparece no e-mail:** vem do **nome público do projeto**, em Console → Configurações do projeto.
- **Primeiro administrador:** quando não houver nenhum, use o script de bootstrap com uma conta de serviço guardada fora do repositório:

  ```bash
  export GOOGLE_APPLICATION_CREDENTIALS="/caminho/fora/do/repo/caminhoazul-admin.json"
  export ADMIN_UID="UID_JA_EXISTENTE"   # ou ADMIN_EMAIL + ADMIN_PASSWORD para criar
  export ADMIN_NAME="Nome do administrador"
  npm --prefix scripts run create:first-admin
  ```

### Limitações do plano Spark (sem backend privilegiado)

- O e-mail de outra conta não pode ser alterado. A conta também não pode ser desabilitada nem apagada no Authentication.
  - Por isso, "Excluir usuário" grava `active: false`, e as regras bloqueiam tudo para essa conta.
  - A exclusão definitiva é manual, no Console.
- O endpoint público do Auth permite criar uma identidade sem perfil. Ela não tem acesso a nada: sem `users/{uid}` criado por um admin, as regras negam todos os dados.
- Não há push com o app fechado. Exigiria credencial do FCM num backend, que é pago (Blaze) ou próprio.
- Toda gravação do painel exige o log de auditoria no mesmo batch, e as regras recusam a gravação sem ele.

Os detalhes das coleções, campos e permissões estão em
[MODELO_DADOS.md](MODELO_DADOS.md).

## Web

```bash
flutter clean && flutter build web --release   # saída em build/web (Hosting configurado em firebase.json)
```

O Hosting **não** foi publicado.

Na Web, a sessão fica só em memória: recarregar a página volta ao login.

## Regras do projeto

- Somente o plano Spark gratuito.
- Dados reais de estudantes só com governança LGPD definida.
- Nenhuma credencial ou chave no repositório.
- Senhas nunca são gravadas no Firestore.
