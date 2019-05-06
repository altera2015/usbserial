import 'dart:typed_data';
import 'dart:async';

abstract class AsyncDataSinkSource {
  Future<void> write(Uint8List data);
  Stream<Uint8List> get inputStream;
}

abstract class Uint8ListTransformer
    implements StreamTransformer<Uint8List, Uint8List>{}
