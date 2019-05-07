import 'dart:typed_data';
import '../lib/transaction.dart';
import '../lib/transformers.dart';
import 'echo_port.dart';
import "package:test/test.dart";


bool compare(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

Future<bool> testMagic() async {

  var writeDelay = Duration(milliseconds: 10);
  EchoPort p = EchoPort(writeDelay: writeDelay);
  var c = Transaction.magicHeader(p.inputStream, Uint8List.fromList([65,10]));


  // ******************************************************
  // Testing 2 byte magic header 65, 10 with 2 byte payload
  // ******************************************************
  var testCommand_1_2 = Uint8List.fromList([65, 10, 2, 1, 2]);
  Uint8List response = await c.transaction(p, testCommand_1_2, writeDelay*3);
  if ( !compare(response, testCommand_1_2) ) {
    print("Test 1 failed.");
    return false;
  }

  // ******************************************************
  // Testing 2 byte magic header 65,10 with 3 byte payload
  // and garbage after data.
  // ******************************************************
  var testCommand_1_2_3_4 = Uint8List.fromList([65, 10, 3, 1, 2, 3]);
  var testCommand_1_2_3_with_garbage = Uint8List.fromList( testCommand_1_2_3_4 + Uint8List.fromList([4,5,6]) );

  response = await c.transaction(p, testCommand_1_2_3_with_garbage, writeDelay*3);
  if ( !compare(response, testCommand_1_2_3_4) ) {
    print("Test 2 failed.");
    return false;
  }


  c.dispose();
  return true;
}

/*
Future<bool> testTerminated() async {
  
  // create a variable write delay
  var writeDelay = Duration(milliseconds: 10);
  EchoPort p = EchoPort(writeDelay: writeDelay);
  var c = Transaction.terminated(p.inputStream, Uint8List.fromList([10, 13]));
  
  // keep track of all data received so
  // we can make sure we have the full list at the end.
  List<Uint8List> asyncList = [];
  c.stream.listen((data) {    
    print("Async Receive: $data");
    asyncList.add(data);
  });

  // ******************************************************
  // Write some prior garbage.
  // ******************************************************
  var garbage = Uint8List.fromList([0, 1, 2, 3, 4, 10, 13]);
  p.write(garbage);

  // wait at least 3 times writeDelay to make sure that answer
  // data has arrived in queue.
  await Future<bool>.delayed(writeDelay * 10);


  var request_1 = Uint8List.fromList([65, 10, 13]);
  var request_2 = Uint8List.fromList([02, 65, 10, 13]);
  var request_2_with_garbage =
      Uint8List.fromList(request_2 + garbage );


  // First transaction!
  Uint8List response =
      await c.transaction(p, Uint8List.fromList([65, 10, 13]), Duration(seconds: 2));

  if ( !compare(response, Uint8List.fromList([65, 10, 13]))) {
    print("Transaction failed. Expected $request_1, got $response_1");
    return false;
  }
  


  // Second transaction!
  Uint8List response_2 =
      await c.transaction(p, request_2, Duration(seconds: 2));
  
  if ( !compare(response_2, request_2)) {
    print("First transaction failed. Expected $request_2, got $response_2");
    return false;
  }
    
  // more garbage, this should not enter the transactions!
  p.write(Uint8List.fromList([0xff, 0xfe, 0xf2, 10, 13, 0, 10, 13]));
  await Future<bool>.delayed(writeDelay);


  // Third transaction
  Uint8List response_3 =
      await c.transaction(p, request_2_with_garbage, Duration(seconds: 2));
  
  if ( !compare(request_2, response_3)) {
    print("First transaction failed. Expected $request_2, got $response_3");
    return false;
  }



  if ( asyncList.length != 7 ) {
    print("Did not get expected number of messages");
    return false;
  }
  
  if ( !compare(asyncList[0], garbage) ) {
    print("async list failed at entry 0");
    return false;
  }

  if ( !compare(asyncList[1], request_1) ) {
    print("async list failed at entry 1");
    return false;
  }

  if ( !compare(asyncList[2], request_2) ) {
    print("async list failed at entry 2");
    return false;
  }

  if ( !compare(asyncList[3], Uint8List.fromList([0xff, 0xfe, 0xf2, 10, 13])) ) {
    print("async list failed at entry 3");
    return false;
  }
  if ( !compare(asyncList[4], Uint8List.fromList([ 0, 10, 13])) ) {
    print("async list failed at entry 4");
    return false;
  }

  if ( !compare(asyncList[5], request_2) ) {
    print("async list failed at entry 5");
    return false;
  }

  if ( !compare(asyncList[6], garbage) ) {
    print("async list failed at entry 6");
    return false;
  }    

  c.dispose();
  return true;
}

*/

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

  test("Testing Transaction", () async {

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


}


void main() async {

  group("EchoPort", testEchoPort );
  group("TerminatedTransformer", testTerminated );
  group("MagicHeaderAndLengthByteTransformer", testMagicHeaderAndLengthByteTransformer );
  group("Transaction", testTransaction );

}
