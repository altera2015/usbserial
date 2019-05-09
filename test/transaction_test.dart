import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/echo_port.dart';

void testTransaction() {
  test("Testing Binary Transaction", () async {
    var writeDelay = Duration(milliseconds: 0);
    EchoPort p = EchoPort(writeDelay: writeDelay);
    var transaction =
        Transaction.terminated(p.inputStream, Uint8List.fromList([10, 13]));

    // While using transactions you can still listen to all
    // incoming messages!
    List<Uint8List> _messages = [];
    transaction.stream.listen((Uint8List data) {
      _messages.add(data);
    });

    p.write(Uint8List.fromList([1, 2, 3, 4, 5, 10, 13]));

    var response = await transaction.transaction(
        p, Uint8List.fromList([20, 21, 10, 13]), Duration(seconds: 1));
    expect(response, equals(Uint8List.fromList([20, 21, 10, 13])));

    response = await transaction.transaction(
        p, Uint8List.fromList([20, 21, 10]), Duration(seconds: 1));
    expect(response, equals(null));

    expect(
        _messages,
        equals([
          Uint8List.fromList([1, 2, 3, 4, 5, 10, 13]),
          Uint8List.fromList([20, 21, 10, 13])
        ]));
  });

  test("Testing String Transaction", () async {
    var writeDelay = Duration(milliseconds: 0);
    EchoPort p = EchoPort(writeDelay: writeDelay);
    var transaction = Transaction.stringTerminated(
        p.inputStream, Uint8List.fromList([13, 10]));

    // While using transactions you can still listen to all
    // incoming messages!
    List<String> _messages = [];
    transaction.stream.listen((String data) {
      _messages.add(data);
    });

    p.write(Uint8List.fromList([65, 66, 13, 10]));

    var response = await transaction.transaction(
        p, Uint8List.fromList([67, 68, 13, 10]), Duration(seconds: 1));
    expect(response, equals("CD\r\n"));

    response = await transaction.transaction(
        p, Uint8List.fromList([20, 21, 10]), Duration(seconds: 1));
    expect(response, equals(null));

    expect(
        _messages,
        equals([
          "AB\r\n",
          "CD\r\n",
        ]));
  });
}

void main() {
  group("Transaction", testTransaction);
}
