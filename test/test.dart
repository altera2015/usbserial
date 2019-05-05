import 'dart:typed_data';
import 'transaction.dart';
import 'echo_port.dart';


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

Future<bool> test() async {
  print("Starting Test");

  // create a variable write delay
  var writeDelay = Duration(milliseconds: 10);
  EchoPort p = EchoPort(writeDelay: writeDelay);
  var c = Transaction.terminated(p.inputStream, Uint8List.fromList([10, 13]));
  
  // keep track of all data received so
  // we can make sure we have the full list at the end.
  List<Uint8List> asyncList = [];
  c.stream.listen((data) {    
    print(data);
    asyncList.add(data);
  });

  // Write some prior garbage.
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
  Uint8List response_1 =
      await c.transaction(p, request_1, Duration(seconds: 2));

  if ( !compare(response_1, request_1)) {
    print("First transaction failed. Expected $request_1, got $response_1");
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


  return true;
}

Future main() async {  
  bool b = await test();
  if ( b ) {
    print("All tests passed");
  } else {
    print("Unit tests failed");
  }
}
