import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:usb_serial/echo_port.dart';
import 'package:usb_serial/transaction.dart';

void testTransaction() {
  test("Testing Binary Transaction", () async {
    var writeDelay = Duration(milliseconds: 0);
    EchoPort p = EchoPort(writeDelay: writeDelay);
    var transaction = Transaction.terminated(p.inputStream!, Uint8List.fromList([13, 10]));

    // While using transactions you can still listen to all
    // incoming messages!
    List<Uint8List> _messages = [];
    transaction.stream.listen((Uint8List data) {
      _messages.add(data);
    });

    p.write(Uint8List.fromList([1, 2, 3, 4, 5, 13, 10]));

    var response = await transaction.transaction(p, Uint8List.fromList([20, 21, 13, 10]), Duration(seconds: 1));
    expect(response, equals(Uint8List.fromList([20, 21])));

    response = await transaction.transaction(p, Uint8List.fromList([20, 21, 10]), Duration(seconds: 1));
    expect(response, equals(null));

    expect(
        _messages,
        equals([
          Uint8List.fromList([1, 2, 3, 4, 5]),
          Uint8List.fromList([20, 21])
        ]));
  });

  test("Testing String Transaction", () async {
    var writeDelay = Duration(milliseconds: 0);
    EchoPort p = EchoPort(writeDelay: writeDelay);
    var transaction = Transaction.stringTerminated(p.inputStream!, Uint8List.fromList([13, 10]));

    // While using transactions you can still listen to all
    // incoming messages!
    List<String> _messages = [];
    transaction.stream.listen((String data) {
      _messages.add(data);
    });

    p.write(Uint8List.fromList([65, 66, 13, 10]));

    var response = await transaction.transaction(p, Uint8List.fromList([67, 68, 13, 10]), Duration(seconds: 1));
    expect(response, equals("CD"));

    response = await transaction.transaction(p, Uint8List.fromList([20, 21, 10]), Duration(seconds: 1));
    expect(response, equals(null));

    expect(
        _messages,
        equals([
          "AB",
          "CD",
        ]));
  });
}

void testTwoTransformersInSequence() {
  try {
    test("Testing Two Transformers In Sequence", () async {
      var writeDelay = Duration(milliseconds: 10);
      Transaction<Uint8List>? transaction_0;
      // Use EchoPort as a Stream Source.
      EchoPort p = EchoPort(writeDelay: writeDelay);

      var startListening = (int idx) async {
        Transaction<String> transaction_1 = Transaction.stringTerminated(p.inputStream!, Uint8List.fromList([13, 10])); // note the ending condition

        String? response = await transaction_1.transaction(p, Uint8List.fromList(("config bla bla").codeUnits + [13, 10]), Duration(seconds: 1));
        expect(response, "config bla bla");

        // end this transaction_1
        transaction_1.dispose();

        // start listening from  the device (terminated needed here because of the "<END>" termination)
        transaction_0 = Transaction.terminated(p.inputStream!, Uint8List.fromList("<END>".codeUnits)); // this ending condition
        //transaction_0.stream.listen((Uint8List data) {});

        Future<void>.delayed(Duration(milliseconds: 100), () {
          p.write(Uint8List.fromList(Uint8List.fromList("A$idx data<END>".codeUnits)));
        });
        Future<void>.delayed(Duration(milliseconds: 100), () {
          p.write(Uint8List.fromList(Uint8List.fromList("B$idx data<END>".codeUnits)));
        });
        Future<void>.delayed(Duration(milliseconds: 100), () {
          p.write(Uint8List.fromList(Uint8List.fromList("C$idx data<END>".codeUnits)));
        });

        expect(
            transaction_0!.stream,
            emitsInOrder([
              Uint8List.fromList(Uint8List.fromList("A$idx data".codeUnits)),
              Uint8List.fromList(Uint8List.fromList("B$idx data".codeUnits)),
              Uint8List.fromList(Uint8List.fromList("C$idx data".codeUnits)),
              emitsDone,
            ]));
      };

      // Now 'hit' stop listening
      var stopListening = (int idx) async {
        // stop listening
        transaction_0?.dispose();

        // send the stop command to usb device (no answer to wait)
        Transaction<String> transaction_1 = Transaction.stringTerminated(p.inputStream!, Uint8List.fromList([13, 10]));
        String? answer = await transaction_1.transaction(p, Uint8List.fromList(("stop").codeUnits + [13, 10]), Duration(seconds: 1));
        // end this transaction_1
        transaction_1.dispose();

        expect(answer, "stop");
      };

      await startListening(1);
      await Future<void>.delayed(Duration(milliseconds: 1000));
      await stopListening(1);
      await Future<void>.delayed(Duration(milliseconds: 500));

      await startListening(2);
      await Future<void>.delayed(Duration(milliseconds: 1000));
      await stopListening(2);

      Future<void>.delayed(Duration(milliseconds: 100), () {
        p.close();
      });
    });
  } catch (e, s) {
    print(s);
  }
}

void main() {
  group("Transaction", testTransaction);
  group("testTwoTransformersInSequence", testTwoTransformersInSequence);
}
