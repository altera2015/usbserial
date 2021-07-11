import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:usb_serial/echo_port.dart';
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

void main() {
  group("TerminatedTransformer", testTerminated);
  group("StringTerminated", testStringTerminated);
  group("MagicHeaderAndLengthByteTransformer", testMagicHeaderAndLengthByteTransformer);
}
