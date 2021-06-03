import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:usb_serial/echo_port.dart';

void testEchoPort() {
  test("Testing Echo Port data", () async {
    var writeDelay = Duration(milliseconds: 10);
    EchoPort p = EchoPort(writeDelay: writeDelay);
    var stream = p.inputStream;

    p.write(Uint8List.fromList([1, 2, 3, 4, 5]));
    p.write(Uint8List.fromList([6, 7, 8, 9, 10]));

    Future<void>.delayed(Duration(milliseconds: 100), () {
      p.write(Uint8List.fromList([6, 7, 8, 9, 11]));
    });

    Future<void>.delayed(Duration(milliseconds: 200), () {
      p.close();
    });

    expect(
        stream,
        emitsInOrder([
          Uint8List.fromList([1, 2, 3, 4, 5]),
          Uint8List.fromList([6, 7, 8, 9, 10]),
          Uint8List.fromList([6, 7, 8, 9, 11]),
          emitsDone
        ]));
  });
}

void main() {
  group("EchoPort", testEchoPort);
}
