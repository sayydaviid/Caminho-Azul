import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'report_share_stub.dart'
    if (dart.library.js_interop) 'report_share_web.dart' as web_share;

/// Saídas do PDF por plataforma (R-08). Nada é enviado automaticamente: o
/// usuário escolhe o destino no menu do sistema (Android/iOS, onde o WhatsApp
/// aparece quando instalado) ou no navegador.
abstract interface class ReportOutput {
  /// Android/iOS: menu nativo de compartilhamento. Web: Web Share API com
  /// arquivo, quando o navegador permite. `false` se não houve menu.
  Future<bool> share(Uint8List bytes, String fileName, String title);

  /// Diálogo de impressão do sistema; no Android inclui "Salvar como PDF" e,
  /// na Web, a pré-visualização do navegador.
  Future<void> printOrSave(Uint8List bytes, String fileName);

  /// Web: baixa o arquivo. Nas demais plataformas, abre o menu de
  /// compartilhamento (onde estão "Salvar em Arquivos"/Drive).
  Future<void> download(Uint8List bytes, String fileName);

  bool get isWeb;

  /// O navegador oferece compartilhamento de arquivos (sempre `true` fora da Web).
  bool get canShareFiles;
}

class PlatformReportOutput implements ReportOutput {
  const PlatformReportOutput();

  @override
  bool get isWeb => kIsWeb;

  @override
  bool get canShareFiles => !kIsWeb || web_share.canShareFiles();

  @override
  Future<bool> share(Uint8List bytes, String fileName, String title) async {
    if (kIsWeb) return web_share.shareFile(bytes, fileName, title);
    return Printing.sharePdf(bytes: bytes, filename: fileName, subject: title);
  }

  @override
  Future<void> printOrSave(Uint8List bytes, String fileName) async {
    await Printing.layoutPdf(
      name: fileName,
      format: PdfPageFormat.a4,
      onLayout: (_) async => bytes,
    );
  }

  @override
  Future<void> download(Uint8List bytes, String fileName) async {
    // Na Web, o printing gera um link de download local (blob), sem servidor.
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}

/// Número de páginas do PDF gerado (contagem dos objetos /Page).
int pdfPageCount(Uint8List bytes) {
  final text = String.fromCharCodes(bytes);
  return RegExp(r'/Type\s*/Page(?![s\w])').allMatches(text).length;
}
