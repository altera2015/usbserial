import 'dart:typed_data';
import '../lib/transaction.dart';
import '../lib/transformers.dart';
import 'echo_port.dart';
import "package:test/test.dart";

void testEchoPort () {

  test("Testing Echo Port data", () async {

    var writeDelay = Duration(milliseconds: 10);
    EchoPort p = EchoPort(writeDelay: writeDelay);
    var stream = p.inputStream;

    p.write(Uint8List.fromList([1,2,3,4,5]));
    p.write(Uint8List.fromList([6,7,8,9,10]));

    Future<void>.delayed(Duration(milliseconds:100), () {
      p.write(Uint8List.fromList([6,7,8,9,11]));
    });

    Future<void>.delayed(Duration(milliseconds:200), () {
      p.close();
    });

    await expect(stream, emitsInOrder([
      Uint8List.fromList([1, 2, 3, 4, 5]),
      Uint8List.fromList([6, 7, 8, 9, 10]),
      Uint8List.fromList([6, 7, 8, 9, 11]),
      emitsDone
    ]));
  });

}

void testTerminated() {

  test("Testing TerminatedTransformer", () async {

    var writeDelay = Duration(milliseconds: 10);
    // Use EchoPort as a Stream Source.
    EchoPort p = EchoPort(writeDelay: writeDelay);

    var stream = p.inputStream.transform(
        TerminatedTransformer(terminator: Uint8List.fromList([10, 13]) )
    );

    Future<void>.delayed(Duration(milliseconds: 100), () {
      p.write(Uint8List.fromList([1, 2, 3, 4, 10, 13, 5, 6, 7, 8, 10, 13, 9, 10, 11, 12, 10, 13, 1, 2]));
    });

    Future<void>.delayed(Duration(milliseconds: 200), () {
      p.write(Uint8List.fromList([3, 4, 10, 13, 5, 6]));
    });

    Future<void>.delayed(Duration(milliseconds: 300), () {
      p.close();
    });

    await expect(stream, emitsInOrder([
      Uint8List.fromList([1, 2, 3, 4, 10, 13]),
      Uint8List.fromList([5, 6, 7, 8, 10, 13]),
      Uint8List.fromList([9, 10, 11, 12, 10, 13]),
      Uint8List.fromList([1, 2, 3, 4, 10, 13]),
      emitsDone
    ]));
  });

}


void testStringTerminated() {

  test("Testing TerminatedStringTransformer", () async {

    var writeDelay = Duration(milliseconds: 10);
    // Use EchoPort as a Stream Source.
    EchoPort p = EchoPort(writeDelay: writeDelay);

    var stream = p.inputStream.transform(
        TerminatedStringTransformer(terminator: Uint8List.fromList([13, 10]) )
    );

    Future<void>.delayed(Duration(milliseconds: 100), () {
      p.write(Uint8List.fromList([65, 66, 67, 68, 13, 10, 69, 70, 71, 72, 13, 10, 73, 74, 75, 76, 13, 10, 77, 78]));
    });

    Future<void>.delayed(Duration(milliseconds: 200), () {
      p.write(Uint8List.fromList([79, 80, 13, 10, 83, 84, 85]));
    });

    Future<void>.delayed(Duration(milliseconds: 300), () {
      p.close();
    });

    await expect(stream, emitsInOrder([
      "ABCD\r\n",
      "EFGH\r\n",
      "IJKL\r\n",
      "MNOP\r\n",
      emitsDone
    ]));
  });

}


void testMagicHeaderAndLengthByteTransformer() {


  test("Testing MagicHeaderAndLengthByteTransformer", () async {

    var writeDelay = Duration(milliseconds: 10);

    // Use EchoPort as a Stream Source.
    EchoPort p = EchoPort(writeDelay: writeDelay);

    var stream = p.inputStream.transform(
        MagicHeaderAndLengthByteTransformer(header: [65, 66] )
    );

    Future<void>.delayed(Duration(milliseconds: 100), () {
      p.write(Uint8List.fromList([10, 12, 65, 66, 2, 1, 2, 5, 5, 65, 66, 1, 10, 3]));
    });

    Future<void>.delayed(Duration(milliseconds: 200), () {
      p.write(Uint8List.fromList([3, 4, 10, 13, 5, 6]));
    });

    Future<void>.delayed(Duration(milliseconds: 300), () {
      p.close();
    });

    await expect(stream, emitsInOrder([
      Uint8List.fromList([65, 66, 2, 1, 2]),
      Uint8List.fromList([65, 66, 1, 10]),
      emitsDone
    ]));
  });


  test("Testing MagicHeaderAndLengthByteTransformer with Wildcards", () async {

    var writeDelay = Duration(milliseconds: 10);

    // Use EchoPort as a Stream Source.
    EchoPort p = EchoPort(writeDelay: writeDelay);

    var stream = p.inputStream.transform(
        MagicHeaderAndLengthByteTransformer(header: [65, null] )
    );

    Future<void>.delayed(Duration(milliseconds: 100), () {
      p.write(Uint8List.fromList([10, 12, 65, 80, 2, 1, 2, 5, 5, 65, 81, 1, 10, 3]));
    });

    Future<void>.delayed(Duration(milliseconds: 200), () {
      p.write(Uint8List.fromList([3, 4, 10, 13, 5, 6]));
    });

    Future<void>.delayed(Duration(milliseconds: 300), () {
      p.close();
    });

    await expect(stream, emitsInOrder([
      Uint8List.fromList([65, 80, 2, 1, 2]),
      Uint8List.fromList([65, 81, 1, 10]),
      emitsDone
    ]));
  });

}

void testTransaction() {

  test("Testing Binary Transaction", () async {

    var writeDelay = Duration(milliseconds: 0);
    EchoPort p = EchoPort(writeDelay: writeDelay);
    var transaction = Transaction.terminated(p.inputStream, Uint8List.fromList([10,13]));

    // While using transactions you can still listen to all 
    // incoming messages!
    List< Uint8List > _messages = [];
    transaction.stream.listen( (Uint8List data) {
      _messages.add(data);
    });

    p.write(Uint8List.fromList([1,2,3,4,5,10,13]));
    
    var response = await transaction.transaction(p, Uint8List.fromList([20,21,10,13]), Duration(seconds: 1) );
    expect(response, equals(Uint8List.fromList([20,21,10,13])));

    response = await transaction.transaction(p, Uint8List.fromList([20,21,10]), Duration(seconds: 1) );
    expect(response, equals(null));

    expect(_messages, equals([
      Uint8List.fromList([1,2,3,4,5,10,13]),
      Uint8List.fromList([20,21,10,13])
    ]));

  });


  test("Testing String Transaction", () async {

    var writeDelay = Duration(milliseconds: 0);
    EchoPort p = EchoPort(writeDelay: writeDelay);
    var transaction = Transaction.stringTerminated(p.inputStream, Uint8List.fromList([13,10]));

    // While using transactions you can still listen to all 
    // incoming messages!
    List< String > _messages = [];
    transaction.stream.listen( (String data) {
      _messages.add(data);
    });

    p.write(Uint8List.fromList([65,66,13,10]));
    
    var response = await transaction.transaction(p, Uint8List.fromList([67,68,13,10]), Duration(seconds: 1) );
    expect(response, equals("CD\r\n"));

    response = await transaction.transaction(p, Uint8List.fromList([20,21,10]), Duration(seconds: 1) );
    expect(response, equals(null));

    expect(_messages, equals([
      "AB\r\n",
      "CD\r\n",      
    ]));

  });  


}


void main() async {

  group("EchoPort", testEchoPort );
  group("TerminatedTransformer", testTerminated );
  group("StringTerminated", testStringTerminated );  
  group("MagicHeaderAndLengthByteTransformer", testMagicHeaderAndLengthByteTransformer );
  group("Transaction", testTransaction );

}
