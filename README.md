[![Pub](https://img.shields.io/pub/v/usb_serial.svg)](https://pub.dartlang.org/packages/usb_serial) [![Flutter](https://github.com/altera2015/usbserial/actions/workflows/flutter.yml/badge.svg)](https://github.com/altera2015/usbserial/actions/workflows/flutter.yml)

# usb_serial

An Android USB Serial Flutter Plugin

This plugin allows Flutter code to interact with USB serial devices connected to your Android device. For example an FTDI or CDC based USB device.

## Getting Started

Add a dependency to your pubspec.yaml

```dart
dependencies:
	usb_serial: ^0.5.0
```

include the usbserial package at the top of your dart file.

```dart
import 'package:usb_serial/usb_serial.dart'
```

### Optional

Add
```xml
	<intent-filter>
		<action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" />
	</intent-filter>

	<meta-data android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED"
		android:resource="@xml/device_filter" />
```
to your AndroidManifest.xml

and place device_filter.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- 0x0403 / 0x6001: FTDI FT232R UART -->
    <usb-device vendor-id="1027" product-id="24577" />

    <!-- 0x0403 / 0x6015: FTDI FT231X -->
    <usb-device vendor-id="1027" product-id="24597" />

    <!-- 0x2341 / Arduino -->
    <usb-device vendor-id="9025" />

    <!-- 0x16C0 / 0x0483: Teensyduino  -->
    <usb-device vendor-id="5824" product-id="1155" />

    <!-- 0x10C4 / 0xEA60: CP210x UART Bridge -->
    <usb-device vendor-id="4292" product-id="60000" />

    <!-- 0x067B / 0x2303: Prolific PL2303 -->
    <usb-device vendor-id="1659" product-id="8963" />

    <!-- 0x1366 / 0x0105: Segger JLink -->
    <usb-device vendor-id="4966" product-id="261" />

    <!-- 0x1366 / 0x0105: CH340 JLink -->
    <usb-device vendor-id="1A86" product-id="7523" />

</resources>
```

in the res/xml directory. This will notify your app when one of the specified devices
is plugged in.

## Usage of Asynchronous API

```dart
...
onPressed: () async {
	List<UsbDevice> devices = await UsbSerial.listDevices();
	print(devices);

	UsbPort port;
	if (devices.length == 0) {
		return;
	}
	port = await devices[0].create();

	bool openResult = await port.open();
	if ( !openResult ) {
		print("Failed to open");
		return;
	}

	await port.setDTR(true);
	await port.setRTS(true);

	port.setPortParameters(115200, UsbPort.DATABITS_8,
	  UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

	// print first result and close port.
	port.inputStream.listen((Uint8List event) {
		print(event);
		port.close();
	});

	await port.write(Uint8List.fromList([0x10, 0x00]));
}
...
```

## Usage of transaction API

This API is a layer on top of the asynchronous part of the library. It provides two
Stream Transformers and a Transaction helper based on the StreamQueue class.

1. Terminated Transformer, this splits incoming data based on a configurable end of message bytes "terminator".
2. Magic Header + Length byte, this splits incoming data based on a configurable header ( with wildcards! ) and a length byte directly following the header.

In case neither is a fit, you can use one of those Transformers to create you own that is specific
to the binary format you are dealing with.

```dart

    ...
    Transaction<String> transaction = Transaction.stringTerminated(port.inputStream, Uint8List.fromList([13,10]));
    ...

    // While using transactions you can still listen to all
    // incoming messages!
    transaction.stream.listen( (String data) {
      print(data);
    });

    // you can write asynchronous messages as before!
    p.write(Uint8List.fromList([65,66,13,10]));

    // BUT you can also write 'transactions'. This is a combination of a flush, write and wait for response
    // with a timeout. If no response is received within the timeout a null value is returned.
    // this sends "AB\r\n"
    var response = await transaction.transaction(p, Uint8List.fromList([65,66,13,10]), Duration(seconds: 1) );
    print("The response was $response");

```

## Upgrading from pre-0.3.0


In version 0.3.0 a resource bug was fixed (issue #35) which required signature
changes.


### Transformer Class changes

The Transformer classes previously inherited directly from StreamTransformer, this class
however has no dispose method. So a new abstract class was added to include dispose and
called by Transaction.dispose().

```dart
abstract class DisposableStreamTransformer<T, R> implements StreamTransformer<T, R> {
  void dispose();
}
```

Steps:

* Change parent class to DisposableStreamTransformer
* Implement dispose class, and make sure to dispose of your StreamController

### Transaction Class changes

The Transaction class previously did not have access to the transformer, only the stream.
The signature of Transaction constructor changed from

```dart
Transaction<T>(Stream<T>);
```

to

```dart
Transaction(Stream<Uint8List> stream, DisposableStreamTransformer<Uint8List, T> transformer);
```

If you are using the static factory methods you should not have to make any changes to your
code. Only if you created your own Transformer/Transactions.

## FAQ

### Always ask permission to use USB port
https://github.com/altera2015/usbserial/issues/49
https://github.com/altera2015/usbserial/issues/38


## Dependencies

This library depends on:

https://github.com/felHR85/UsbSerial


