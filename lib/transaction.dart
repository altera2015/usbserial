import 'dart:async';
import 'dart:typed_data';

import 'package:async/async.dart';

import 'transformers.dart';
import 'types.dart';

/// The transaction class is an easy way to
/// use the UsbPort class in a more linear way
/// without blocking.
///
/// Example
/// ```dart
/// // Create a parser that splits incoming data on endline newline combination ( \r\n)
/// var c = Transaction.terminated(p.inputStream, Uint8List.fromList([13, 10]));
///
/// // Listen asynchronously if you need this:
/// c.stream.listen((data) {
///   print("ASYNC LISTEN $data");
/// });
///
/// var request_1 = Uint8List.fromList([65]);
/// // Wait two seconds for the answer
///
/// Uint8List response_1 = await c.transaction(p, request_1, Duration(seconds: 2));
/// if (response_1 == null ) {
///    print("Failed to get a response.");
/// }
/// ```
///
class Transaction<T> {
  late Stream<T> stream;
  late StreamQueue<T> _queue;
  DisposableStreamTransformer? _transformer;

  /// Create a transaction that transforms the incoming stream into
  /// events delimited by 'terminator'.
  ///
  /// ```dart
  /// var c = Transaction.terminated(p.inputStream, Uint8List.fromList([13, 10]));
  /// ```
  static Transaction<Uint8List> terminated(
      Stream<Uint8List> stream, Uint8List terminator,
      {int maxLen = 1024, bool stripTerminator = true}) {
    return Transaction<Uint8List>(
        stream,
        TerminatedTransformer.broadcast(
            terminator: terminator,
            maxLen: maxLen,
            stripTerminator: stripTerminator));
  }

  /// Create a transaction that uses MagicHeaderAndLengthByteTransformer
  ///
  /// ```dart
  /// Transaction.magicHeader(p.inputStream, Uint8List.fromList([65,65,65])); // expects magic header AAA and then byte of length.
  /// ```
  static Transaction<Uint8List> magicHeader(
      Stream<Uint8List> stream, List<int> header,
      {int maxLen = 1024}) {
    return Transaction<Uint8List>(
        stream,
        MagicHeaderAndLengthByteTransformer.broadcast(
            header: header, maxLen: maxLen));
  }

  /// Create a transaction that transforms the incoming stream into
  /// events delimited by 'terminator', returning Strings.
  ///
  /// ```dart
  /// var c = Transaction.stringTerminated(p.inputStream, Uint8List.fromList([13, 10]));
  /// ```
  static Transaction<String> stringTerminated(
      Stream<Uint8List> stream, Uint8List terminator,
      {int maxLen = 1024, bool stripTerminator = true}) {
    return Transaction<String>(
        stream,
        TerminatedStringTransformer.broadcast(
            terminator: terminator,
            maxLen: maxLen,
            stripTerminator: stripTerminator));
  }

  /// Transaction Constructor, pass it the untransformed input stream and
  /// the transformer to work on the stream.
  Transaction(Stream<Uint8List> stream,
      DisposableStreamTransformer<Uint8List, T> transformer)
      : this.stream = stream.transform(transformer),
        _transformer = transformer {
    _queue = StreamQueue<T>(this.stream);
  }

  /// Flush all existing messages from the queue.
  Future<void> flush() async {
    while (true) {
      // Don't call queue._next directly as it will
      // eat the next available message even if it
      // timed out. Use hasNext instead.
      var f = _queue.hasNext.timeout(Duration(microseconds: 1));
      try {
        bool hasNext = await f;
        if (!hasNext) {
          // The stream has closed, bail out!
          return;
        }
        await _queue.next;
        // consume the data and throw it away.
      } on TimeoutException {
        // Timeout occured, we are done, no more data
        // available.
        return;
      }
    }
  }

  /// Get the next message from the queue if any.
  /// returns data or null on error.
  Future<T?> getMsg(Duration duration) async {
    // don't use the timeout on the .next property as
    // it will eat the next incoming packet.
    // instead use hasNext and then use
    try {
      bool b = await _queue.hasNext.timeout(duration);
      if (b) {
        return await _queue.next;
      } else {
        // throw TimeoutException("Port was closed.");
        return null;
      }
    } on TimeoutException {
      return null;
    }
  }

  /// The transaction functions does 3 things.
  /// 1. Flush the incoming queue
  /// 2. Write the message
  /// 3. Await the answer for at most "duration" time.
  /// returns List of bytes or null on timeout.
  Future<T?> transaction(
      AsyncDataSinkSource port, Uint8List message, Duration duration) async {
    await flush();
    port.write(message);
    return getMsg(duration);
  }

  /// Call dispose when you are done with the object.
  /// this will release the underlying stream.
  void dispose() {
    _queue.cancel();
    _transformer?.dispose();
  }
}
