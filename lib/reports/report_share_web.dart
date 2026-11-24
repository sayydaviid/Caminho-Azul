import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

// Web Share API (nível 2, com arquivos). O navegador mostra o próprio menu;
// o app não sabe nem afirma se o arquivo chegou ao destinatário.
web.ShareData _data(Uint8List bytes, String fileName, String title) {
  final file = web.File(
    [bytes.toJS].toJS,
    fileName,
    web.FilePropertyBag(type: 'application/pdf'),
  );
  return web.ShareData(title: title, files: [file].toJS);
}

bool canShareFiles() {
  try {
    final probe = _data(Uint8List(0), 'teste.pdf', 'Caminho Azul');
    return web.window.navigator.canShare(probe);
  } catch (_) {
    return false;
  }
}

Future<bool> shareFile(Uint8List bytes, String fileName, String title) async {
  final data = _data(bytes, fileName, title);
  try {
    if (!web.window.navigator.canShare(data)) return false;
    await web.window.navigator.share(data).toDart;
    return true;
  } catch (_) {
    // Cancelado pelo usuário ou não suportado.
    return false;
  }
}
