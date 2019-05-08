import 'dart:async';
import 'dart:typed_data';
import 'lib/types.dart';

/// Test harnass stub for UsbPort.
/// Sends the data back with a delay.
class EchoPort extends AsyncDataSinkSource {
  Stream<Uint8List> _stream;
  StreamController<Uint8List> _controller;
  bool _running = false;
  List<Uint8List> _buffer;
  final Duration writeDelay;

  Stream<Uint8List> fakeData() {
    void start() {
      _running = true;
      if (_buffer.length > 0) {
        _buffer.forEach((data) {
          _controller.add(data);
        });
        _buffer.clear();
      }
    }

    void stop() {
      _running = false;
    }

    _controller = StreamController<Uint8List>(
        onListen: start, onPause: stop, onResume: start, onCancel: stop);

    return _controller.stream;
  }

  EchoPort({this.writeDelay = const Duration(seconds: 0)}) {
    _stream = fakeData();
    _buffer = [];
  }

  Stream<Uint8List> get inputStream {
    return _stream;
  }

  Future<void> _write(Uint8List data) async {
    if (_running) {
      _controller.add(data);
    } else {
      _buffer.add(data);
    }
  }

  Future<void> write(Uint8List data) async {
    if ( writeDelay == Duration(seconds: 0)) {
      return _write(data);
    } else {
      Future<void>.delayed(writeDelay, () {
        return _write(data);
      });
    }
  }

  void close() {
    _controller.close();
  }
}
