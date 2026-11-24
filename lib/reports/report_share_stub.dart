import 'dart:typed_data';

// Fora da Web o compartilhamento usa o menu nativo (printing).
bool canShareFiles() => false;

Future<bool> shareFile(Uint8List bytes, String fileName, String title) async =>
    false;
