import 'dart:typed_data';
import 'dart:async';
import 'types.dart';

/// This transformer takes an incoming stream and splits it
/// along the "terminator" marks. Great for parsing incoming
/// serial streams that end on \r\n.
class TerminatedTransformer implements Uint8ListTransformer {
  bool cancelOnError;
  final Uint8List terminator;
  final int
      maxLen; // maximum length the partial buffer will hold before it starts flushing.

  StreamController _controller;
  StreamSubscription _subscription;
  Stream<Uint8List> _stream;
  List<int> _partial;

  TerminatedTransformer(
      {bool sync: false,
      this.cancelOnError,
      this.terminator,
      this.maxLen = 1024}) {
    _partial = [];
    _controller = new StreamController<Uint8List>(
        onListen: _onListen,
        onCancel: _onCancel,
        onPause: () {
          _subscription.pause();
        },
        onResume: () {
          _subscription.resume();
        },
        sync: sync);
  }

  TerminatedTransformer.broadcast(
      {bool sync: false,
      bool this.cancelOnError,
      this.terminator,
      this.maxLen = 1024}) {
    _partial = [];
    _controller = new StreamController<Uint8List>.broadcast(
        onListen: _onListen, onCancel: _onCancel, sync: sync);
  }

  void _onListen() {
    _subscription = _stream.listen(onData,
        onError: _controller.addError,
        onDone: _controller.close,
        cancelOnError: cancelOnError);
  }

  void _onCancel() {
    _subscription.cancel();
    _subscription = null;
  }

  void onData(Uint8List data) {
    if (_partial.length > maxLen) {
      _partial = _partial.sublist(_partial.length - maxLen);
    }
    _partial.addAll(data);    

    bool found = true;
    while (((_partial.length - terminator.length) > 0) && found) {
      for (var i = 0; i <= (_partial.length - terminator.length); i++) {
        found = true;
        for (var j = 0; j < terminator.length; j++) {
          if (_partial[i + j] != terminator[j]) {
            found = false;
            break;
          }
        }
        if (found) {
          Uint8List message =
              Uint8List.fromList(_partial.take(i + terminator.length).toList());          
          _controller.add(message);
          _partial = _partial.sublist(i + terminator.length);
          break;
        }
      }
    }
  }

  Stream<Uint8List> bind(Stream<Uint8List> stream) {
    this._stream = stream;
    return _controller.stream;
  }

  StreamTransformer<RS, RT> cast<RS, RT>() =>
      StreamTransformer.castFrom<Uint8List, Uint8List, RS, RT>(this);
}
