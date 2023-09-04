import 'dart:async';
import 'dart:typed_data';

/// wildcardFind searches the haystack for a copy of needle.
/// both needle and haystack must be Lists. Needle may
/// contain null's, that position is then treated as a wildcard.
int wildcardFind(dynamic needle, dynamic haystack) {
  final int? hl = haystack.length;
  final int? nl = needle.length;

  if (nl == 0) {
    return 0;
  }

  if (hl! < nl!) {
    return -1;
  }

  for (int i = 0; i <= (hl - nl); i++) {
    bool found = true;
    for (int j = 0; j < nl; j++) {
      if (needle[j] != null && (haystack[i + j] != needle[j])) {
        found = false;
        break;
      }
    }
    if (found) {
      return i;
    }
  }
  return -1;
}

/// parent abstract class to all transformers adding dispose method.
abstract class DisposableStreamTransformer<T, R>
    implements StreamTransformer<T, R> {
  void dispose();
}

/// This transformer takes an incoming stream and splits it
/// along the "terminator" marks. Great for parsing incoming
/// serial streams that end on \r\n.
class TerminatedTransformer
    implements DisposableStreamTransformer<Uint8List, Uint8List> {
  bool? cancelOnError;
  final Uint8List? terminator;
  final int
      maxLen; // maximum length the partial buffer will hold before it starts flushing.
  final stripTerminator;

  late StreamController _controller;
  StreamSubscription? _subscription;
  late Stream<Uint8List> _stream;
  late List<int> _partial;

  /// Splits the incoming stream at the given terminator sequence.
  /// maxLen is the maximum number of bytes that will be collected
  /// before a terminator is detected. If more data arrives the oldest
  /// bytes will be discarded.
  /// terminator is a Uint8List of bytes.
  /// stripTerminator is a boolean indicating if the terminator should
  /// remain attached in the output.
  ///
  /// This constructor creates a single stream
  TerminatedTransformer({bool sync = false, this.cancelOnError, this.terminator, this.maxLen = 1024, this.stripTerminator = true}) {
    _partial = [];
    _controller = new StreamController<Uint8List>(
        onListen: _onListen,
        onCancel: _onCancel,
        onPause: () {
          _subscription!.pause();
        },
        onResume: () {
          _subscription!.resume();
        },
        sync: sync);
  }

  /// Splits the incoming stream at the given terminator sequence.
  /// maxLen is the maximum number of bytes that will be collected
  /// before a terminator is detected. If more data arrives the oldest
  /// bytes will be discarded.
  /// terminator is a Uint8List of bytes.
  /// stripTerminator is a boolean indicating if the terminator should
  /// remain attached in the output.
  ///
  /// This constructor creates a broadcast stream

  TerminatedTransformer.broadcast({bool sync = false, this.cancelOnError, this.terminator, this.maxLen = 1024, this.stripTerminator = true}) {
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
    _subscription!.cancel();
    _subscription = null;
  }

  void onData(Uint8List data) {
    if (_partial.length > maxLen) {
      _partial = _partial.sublist(_partial.length - maxLen);
    }
    _partial.addAll(data);

    while (((_partial.length - terminator!.length) > 0)) {
      int index = wildcardFind(terminator, _partial);
      if (index < 0) {
        break;
      }
      Uint8List message;
      if (stripTerminator) {
        message = Uint8List.fromList(_partial.take(index).toList());
      } else {
        message = Uint8List.fromList(
            _partial.take(index + terminator!.length).toList());
      }

      _controller.add(message);
      _partial = _partial.sublist(index + terminator!.length);
    }
  }

  @override
  Stream<Uint8List> bind(Stream<Uint8List> stream) {
    this._stream = stream;
    return _controller.stream as Stream<Uint8List>;
  }

  @override
  StreamTransformer<RS, RT> cast<RS, RT>() =>
      StreamTransformer.castFrom<Uint8List, Uint8List, RS, RT>(this);

  @override
  void dispose() {
    _controller.close();
  }
}

/// This transformer takes an incoming stream and splits it
/// along the "terminator" marks and returns a String! Great
/// for parsing incoming serial streams that end on \r\n.
class TerminatedStringTransformer
    implements DisposableStreamTransformer<Uint8List, String> {
  bool? cancelOnError;
  final Uint8List? terminator;
  final int
      maxLen; // maximum length the partial buffer will hold before it starts flushing.
  final stripTerminator;

  late StreamController _controller;
  StreamSubscription? _subscription;
  late Stream<Uint8List> _stream;
  late List<int> _partial;

  /// Splits the incoming stream at the given terminator sequence
  /// and converts to input to a string.
  ///
  /// maxLen is the maximum number of bytes that will be collected
  /// before a terminator is detected. If more data arrives the oldest
  /// bytes will be discarded.
  /// terminator is a Uint8List of bytes.
  /// stripTerminator is a boolean indicating if the terminator should
  /// remain attached in the output.
  ///
  /// This constructor creates a single string stream

  TerminatedStringTransformer({bool sync = false, this.cancelOnError, this.terminator, this.maxLen = 1024, this.stripTerminator = true}) {
    _partial = [];
    _controller = new StreamController<String>(
        onListen: _onListen,
        onCancel: _onCancel,
        onPause: () {
          _subscription!.pause();
        },
        onResume: () {
          _subscription!.resume();
        },
        sync: sync);
  }

  /// Splits the incoming stream at the given terminator sequence
  /// and converts to input to a string.
  ///
  /// maxLen is the maximum number of bytes that will be collected
  /// before a terminator is detected. If more data arrives the oldest
  /// bytes will be discarded.
  /// terminator is a Uint8List of bytes.
  /// stripTerminator is a boolean indicating if the terminator should
  /// remain attached in the output.
  ///
  /// This constructor creates a broadcast string stream

  TerminatedStringTransformer.broadcast({bool sync = false, this.cancelOnError, this.terminator, this.maxLen = 1024, this.stripTerminator = true}) {
    _partial = [];
    _controller = new StreamController<String>.broadcast(
        onListen: _onListen, onCancel: _onCancel, sync: sync);
  }

  void _onListen() {
    _subscription = _stream.listen(onData,
        onError: _controller.addError,
        onDone: _controller.close,
        cancelOnError: cancelOnError);
  }

  void _onCancel() {
    _subscription!.cancel();
    _subscription = null;
  }

  void onData(Uint8List data) {
    if (_partial.length > maxLen) {
      _partial = _partial.sublist(_partial.length - maxLen);
    }
    _partial.addAll(data);

    while (((_partial.length - terminator!.length) > 0)) {
      int index = wildcardFind(terminator, _partial);
      if (index < 0) {
        break;
      }
      Uint8List message;
      if (stripTerminator) {
        message = Uint8List.fromList(_partial.take(index).toList());
      } else {
        message = Uint8List.fromList(
            _partial.take(index + terminator!.length).toList());
      }
      _controller.add(String.fromCharCodes(message));
      _partial = _partial.sublist(index + terminator!.length);
    }
  }

  @override
  Stream<String> bind(Stream<Uint8List> stream) {
    this._stream = stream;
    return _controller.stream as Stream<String>;
  }

  @override
  StreamTransformer<RS, RT> cast<RS, RT>() =>
      StreamTransformer.castFrom<Uint8List, String, RS, RT>(this);

  @override
  void dispose() {
    _controller.close();
  }
}

/// Assembles messages that start with a fixed sequence of zero or more magic
/// bytes followed by a single byte that indicates the length of the rest of
/// the packet.
/// null is accepted as a wildcard byte.
/// <MAGIC BYTE> <LENGTH> <DATA1> <DATA2> ,...
/// example: [0x25] magic
/// 0x25 0x02 0x01 0x02
///
/// example [null] magic (will match any header byte)
/// 0x60 0x03 0x01 0x03 0x02
/// 0x10 0x04 0x01 0x02 0x03 0x04
///
/// Will clear input if no data is received for at least 1 second.
class MagicHeaderAndLengthByteTransformer
    implements DisposableStreamTransformer<Uint8List, Uint8List> {
  final List<int?>? header;
  final Duration clearTimeout;
  late List<int> _partial;
  Timer? _timer;
  late bool _dataSinceLastTick;
  bool? cancelOnError;
  final int
      maxLen; // maximum length the partial buffer will hold before it starts flushing.

  late StreamController _controller;
  StreamSubscription? _subscription;
  late Stream<Uint8List> _stream;

  MagicHeaderAndLengthByteTransformer({bool sync = false, this.cancelOnError, this.header, this.maxLen = 1024, this.clearTimeout = const Duration(seconds: 1)}) {
    _partial = [];
    _controller = new StreamController<Uint8List>(
        onListen: _onListen,
        onCancel: _onCancel,
        onPause: () {
          _subscription!.pause();
        },
        onResume: () {
          _subscription!.resume();
        },
        sync: sync);
  }

  MagicHeaderAndLengthByteTransformer.broadcast(
      {bool sync = false, this.cancelOnError, this.header, this.maxLen = 1024, this.clearTimeout = const Duration(seconds: 1)}) {
    _partial = [];
    _controller = new StreamController<Uint8List>.broadcast(
        onListen: _onListen, onCancel: _onCancel, sync: sync);
  }

  void _onListen() {
    _startTimer();
    _subscription = _stream.listen(onData,
        onError: _controller.addError,
        onDone: _controller.close,
        cancelOnError: cancelOnError);
  }

  void _onCancel() {
    _stopTimer();
    _subscription!.cancel();
    _subscription = null;
  }

  void onData(Uint8List data) {
    _dataSinceLastTick = true;
    if (_partial.length > maxLen) {
      _partial = _partial.sublist(_partial.length - maxLen);
    }

    _partial.addAll(data);

    while (_partial.length > 0) {
      int index = wildcardFind(header, _partial);
      if (index < 0) {
        return;
      }

      if (index > 0) {
        _partial = _partial.sublist(index);
      }

      if (_partial.length < header!.length + 1) {
        // not completely arrived yet.
        return;
      }

      int len = _partial[header!.length];
      if (_partial.length < len + header!.length + 1) {
        // not completely arrived yet.
        return;
      }

      _controller.add(
          Uint8List.fromList(_partial.sublist(0, len + header!.length + 1)));
      _partial = _partial.sublist(len + header!.length + 1);
    }
  }

  @override
  Stream<Uint8List> bind(Stream<Uint8List> stream) {
    this._stream = stream;
    return _controller.stream as Stream<Uint8List>;
  }

  @override
  StreamTransformer<RS, RT> cast<RS, RT>() =>
      StreamTransformer.castFrom<Uint8List, Uint8List, RS, RT>(this);

  void _onTimer(Timer timer) {
    if (_partial.length > 0 && !_dataSinceLastTick) {
      _partial.clear();
    }
    _dataSinceLastTick = false;
  }

  void _stopTimer() {
    _timer!.cancel();
    _timer = null;
  }

  void _startTimer() {
    _dataSinceLastTick = false;
    _timer = Timer.periodic(clearTimeout, this._onTimer);
  }

  @override
  void dispose() {
    _controller.close();
  }
}
