import 'dart:async';

/// Stream compartilhável para telas com listas preguiçosas (D-A04).
///
/// Os streams do Firestore aceitam um único ouvinte. Quando uma seção de uma
/// `ListView` sai da área visível, o `StreamBuilder` é descartado; ao voltar,
/// ele escutava o mesmo stream de novo e falhava com "Stream has already been
/// listened to". Aqui a assinatura da origem dura enquanto o dono existir,
/// novos ouvintes são aceitos e recebem imediatamente o último valor (ou erro).
/// O dono chama [dispose] no `State.dispose`.
class SharedStream<T> {
  SharedStream(this._source);

  final Stream<T> _source;
  StreamSubscription<T>? _subscription;
  final _listeners = <MultiStreamController<T>>{};
  bool _hasValue = false;
  T? _value;
  Object? _error;
  StackTrace? _stackTrace;
  bool _disposed = false;

  late final Stream<T> stream = Stream<T>.multi((controller) {
    if (_disposed) {
      controller.close();
      return;
    }
    if (_error != null) {
      controller.addError(_error!, _stackTrace);
    } else if (_hasValue) {
      controller.add(_value as T);
    }
    _listeners.add(controller);
    controller.onCancel = () => _listeners.remove(controller);
    _subscription ??= _source.listen(
      (value) {
        _hasValue = true;
        _value = value;
        _error = null;
        for (final listener in [..._listeners]) {
          listener.add(value);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _error = error;
        _stackTrace = stackTrace;
        for (final listener in [..._listeners]) {
          listener.addError(error, stackTrace);
        }
      },
    );
  });

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    for (final listener in [..._listeners]) {
      await listener.close();
    }
    _listeners.clear();
  }
}
