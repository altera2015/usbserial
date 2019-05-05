import 'dart:async';
import 'dart:typed_data';
import 'package:async/async.dart';
import 'types.dart';
import 'terminated_transformer.dart';

/// The transaction class is an easy way to 
/// use the UsbPort class in a more linear way
/// without blocking.
/// 
/// Example
/// ```dart
/// // Create a parser that splits incoming data on endline newline combination ( \n\r)
/// var c = Transaction.terminated(p.inputStream, Uint8List.fromList([10, 13]));
/// 
/// // Listen asynchronously if you need this:
/// c.stream.listen((data) {
///   print("ASYNC LISTEN $data");
/// });
/// 
/// var request_1 = Uint8List.fromList([65, 10, 13]);
/// // Wait two seconds for the answer
/// try {
///    Uint8List response_1 = await c.transaction(p, request_1, Duration(seconds: 2));
/// } catch ( e ) {
///    print("Failed to get a response.");
/// }
/// ```
/// 
class Transaction {
  Stream<Uint8List> stream;
  StreamQueue<Uint8List> _queue;

  /// Create a transaction that transforms the incoming stream into 
  /// events delimited by 'terminator'.
  factory Transaction.terminated(
      Stream<Uint8List> stream, Uint8List terminator) {
    return Transaction(stream
        .transform(TerminatedTransformer.broadcast(terminator: terminator)));
  }

  /// Create a new transaction based stream without transforming the input.
  Transaction(this.stream) {
    _queue = StreamQueue<Uint8List>(stream);
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
      } catch (e) {
        // Timeout occured, we are done, no more data
        // available.
        return;
      }
    }
  }

  /// Get the next message from the queue if any.
  /// Will throw error on duration expiration!
  Future<Uint8List> getMsg(Duration duration) async {    
    // don't use the timeout on the .next property as
    // it will eat the next incoming packet.
    // instead use hasNext and then use
    bool b = await _queue.hasNext.timeout(duration);
    if ( b ) {
      return await _queue.next;
    } else {
      throw TimeoutException("Port was closed.");
    }
  }

  /// The transaction functions does 3 things.
  /// 1. Flush the incoming queue
  /// 2. Write the message
  /// 3. Await the answer for at most "duration" time.
  /// Will throw an error if the message was not received on time.
  Future<Uint8List> transaction(
      AsyncDataSinkSource port, Uint8List message, Duration duration) async {        
    await flush();    
    port.write(message);
    // return await _queue.next.timeout(duration);
    return getMsg(duration);    
  }
}
