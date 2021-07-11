import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:usb_serial/echo_port.dart';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/transformers.dart';

void testTerminated() {
  test("Testing TerminatedTransformer", () async {
    var writeDelay = Duration(milliseconds: 10);
    // Use EchoPort as a Stream Source.
    EchoPort p = EchoPort(writeDelay: writeDelay);

    var stream = p.inputStream!.transform(TerminatedTransformer(terminator: Uint8List.fromList([13, 10]), stripTerminator: false));

    Future<void>.delayed(Duration(milliseconds: 100), () {
      p.write(Uint8List.fromList([1, 2, 3, 4, 13, 10, 5, 6, 7, 8, 13, 10, 9, 10, 11, 12, 13, 10, 1, 2]));
    });

    Future<void>.delayed(Duration(milliseconds: 200), () {
      p.write(Uint8List.fromList([3, 4, 13, 10, 5, 6]));
    });

    Future<void>.delayed(Duration(milliseconds: 300), () {
      p.close();
    });

    expect(
        stream,
        emitsInOrder([
          Uint8List.fromList([1, 2, 3, 4, 13, 10]),
          Uint8List.fromList([5, 6, 7, 8, 13, 10]),
          Uint8List.fromList([9, 10, 11, 12, 13, 10]),
          Uint8List.fromList([1, 2, 3, 4, 13, 10]),
          emitsDone
        ]));
  });
}

void testTerminatedStripped() {
  test("Testing TerminatedTransformer", () async {
    var writeDelay = Duration(milliseconds: 10);
    // Use EchoPort as a Stream Source.
    EchoPort p = EchoPort(writeDelay: writeDelay);

    var stream = p.inputStream!.transform(TerminatedTransformer(terminator: Uint8List.fromList([13, 10]), stripTerminator: true));

    Future<void>.delayed(Duration(milliseconds: 100), () {
      p.write(Uint8List.fromList([1, 2, 3, 4, 13, 10, 5, 6, 7, 8, 13, 10, 9, 10, 11, 12, 13, 10, 1, 2]));
    });

    Future<void>.delayed(Duration(milliseconds: 200), () {
      p.write(Uint8List.fromList([3, 4, 13, 10, 5, 6]));
    });

    Future<void>.delayed(Duration(milliseconds: 300), () {
      p.close();
    });

    expect(
        stream,
        emitsInOrder([
          Uint8List.fromList([1, 2, 3, 4]),
          Uint8List.fromList([5, 6, 7, 8]),
          Uint8List.fromList([9, 10, 11, 12]),
          Uint8List.fromList([1, 2, 3, 4]),
          emitsDone
        ]));
  });
}

void testStringTerminated() {
  test("Testing TerminatedStringTransformer", () async {
    var writeDelay = Duration(milliseconds: 10);
    // Use EchoPort as a Stream Source.
    EchoPort p = EchoPort(writeDelay: writeDelay);

    var stream = p.inputStream!.transform(TerminatedStringTransformer(terminator: Uint8List.fromList([13, 10]), stripTerminator: false));

    Future<void>.delayed(Duration(milliseconds: 100), () {
      p.write(Uint8List.fromList([65, 66, 67, 68, 13, 10, 69, 70, 71, 72, 13, 10, 73, 74, 75, 76, 13, 10, 77, 78]));
    });

    Future<void>.delayed(Duration(milliseconds: 200), () {
      p.write(Uint8List.fromList([79, 80, 13, 10, 83, 84, 85]));
    });

    Future<void>.delayed(Duration(milliseconds: 300), () {
      p.close();
    });

    expect(stream, emitsInOrder(["ABCD\r\n", "EFGH\r\n", "IJKL\r\n", "MNOP\r\n", emitsDone]));
  });
}

void testStringTerminatedStripped() {
  test("Testing TerminatedStringTransformer", () async {
    var writeDelay = Duration(milliseconds: 10);
    // Use EchoPort as a Stream Source.
    EchoPort p = EchoPort(writeDelay: writeDelay);

    var stream = p.inputStream!.transform(TerminatedStringTransformer(terminator: Uint8List.fromList([13, 10]), stripTerminator: true));

    Future<void>.delayed(Duration(milliseconds: 100), () {
      p.write(Uint8List.fromList([65, 66, 67, 68, 13, 10, 69, 70, 71, 72, 13, 10, 73, 74, 75, 76, 13, 10, 77, 78]));
    });

    Future<void>.delayed(Duration(milliseconds: 200), () {
      p.write(Uint8List.fromList([79, 80, 13, 10, 83, 84, 85]));
    });

    Future<void>.delayed(Duration(milliseconds: 300), () {
      p.close();
    });

    expect(stream, emitsInOrder(["ABCD", "EFGH", "IJKL", "MNOP", emitsDone]));
  });
}

void testMagicHeaderAndLengthByteTransformer() {
  test("Testing MagicHeaderAndLengthByteTransformer", () async {
    var writeDelay = Duration(milliseconds: 10);

    // Use EchoPort as a Stream Source.
    EchoPort p = EchoPort(writeDelay: writeDelay);

    var stream = p.inputStream!.transform(MagicHeaderAndLengthByteTransformer(header: [65, 66]));

    Future<void>.delayed(Duration(milliseconds: 100), () {
      p.write(Uint8List.fromList([10, 12, 65, 66, 2, 1, 2, 5, 5, 65, 66, 1, 10, 3]));
    });

    Future<void>.delayed(Duration(milliseconds: 200), () {
      p.write(Uint8List.fromList([3, 4, 10, 13, 5, 6]));
    });

    Future<void>.delayed(Duration(milliseconds: 300), () {
      p.close();
    });

    expect(
        stream,
        emitsInOrder([
          Uint8List.fromList([65, 66, 2, 1, 2]),
          Uint8List.fromList([65, 66, 1, 10]),
          emitsDone
        ]));
  });

  test("Testing MagicHeaderAndLengthByteTransformer with Wildcards [65, null]", () async {
    var writeDelay = Duration(milliseconds: 10);

    // Use EchoPort as a Stream Source.
    EchoPort p = EchoPort(writeDelay: writeDelay);

    var stream = p.inputStream!.transform(MagicHeaderAndLengthByteTransformer(header: [65, null]));

    Future<void>.delayed(Duration(milliseconds: 100), () {
      p.write(Uint8List.fromList([10, 12, 65, 80, 2, 1, 2, 5, 5, 65, 81, 1, 10, 3]));
    });

    Future<void>.delayed(Duration(milliseconds: 200), () {
      p.write(Uint8List.fromList([3, 4, 10, 13, 5, 6]));
    });

    Future<void>.delayed(Duration(milliseconds: 300), () {
      p.close();
    });

    expect(
        stream,
        emitsInOrder([
          Uint8List.fromList([65, 80, 2, 1, 2]),
          Uint8List.fromList([65, 81, 1, 10]),
          emitsDone
        ]));
  });

  test("Testing MagicHeaderAndLengthByteTransformer with Wildcards [null]", () async {
    var writeDelay = Duration(milliseconds: 10);

    // Use EchoPort as a Stream Source.
    EchoPort p = EchoPort(writeDelay: writeDelay);

    var stream = p.inputStream!.transform(MagicHeaderAndLengthByteTransformer(header: [null]));

    Future<void>.delayed(Duration(milliseconds: 100), () {
      p.write(Uint8List.fromList([10, 2, 65, 80, 2, 1, 2, 5, 5, 65, 81, 1, 10]));
    });

    Future<void>.delayed(Duration(milliseconds: 200), () {
      p.write(Uint8List.fromList([3, 4, 3, 13, 5, 6]));
    });

    Future<void>.delayed(Duration(milliseconds: 300), () {
      p.close();
    });

    expect(
        stream,
        emitsInOrder([
          Uint8List.fromList([10, 2, 65, 80]),
          Uint8List.fromList([2, 1, 2]),
          Uint8List.fromList([5, 5, 65, 81, 1, 10, 3]),
          Uint8List.fromList([4, 3, 13, 5, 6]),
          emitsDone
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
  group("TerminatedTransformer", testTerminated);
  group("StringTerminated", testStringTerminated);
  group("MagicHeaderAndLengthByteTransformer", testMagicHeaderAndLengthByteTransformer);
  group("testTwoTransformersInSequence", testTwoTransformersInSequence);
}
