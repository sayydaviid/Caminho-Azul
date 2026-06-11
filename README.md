# Caminho Azul Mobile

Aplicacao Flutter mobile baseada no layout original criado no Figma. A interface
usa Material 3, Navigator nativo, dados mockados e uma estrutura preparada para
substituir os mocks por Firebase Authentication, Firestore e Firebase Storage.

## Estrutura

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme.dart
  data/
    mock_data.dart
  models/
    app_models.dart
  screens/
    login_screen.dart
    dashboard_screen.dart
    admin_screen.dart
    familia_screen.dart
    saude_screen.dart
    documentos_screen.dart
    ficha_observacao_screen.dart
    linha_tempo_screen.dart
    relatorio_screen.dart
  widgets/
    app_shell.dart
    dashboard_card.dart
    custom_button.dart
    custom_input.dart
    status_badge.dart
    page_header.dart
    bottom_nav.dart
```

## Executar

O codigo da aplicacao nao depende de pacotes externos. Em uma maquina com o
Flutter instalado, gere apenas os runners nativos uma vez e execute:

```bash
flutter create --platforms=android,ios .
flutter pub get
flutter run
```

O comando `flutter create` preserva a pasta `lib/` e cria o boilerplate nativo
necessario para Android e iOS.
