[![Pub](https://img.shields.io/pub/v/usbserial.svg)](https://pub.dartlang.org/packages/usbserial)

# usb_serial

An Android USB Serial Flutter Plugin

This plugin allows Flutter code to interact with USB serial devices connected to your Android device. For example an FTDI or CDC based USB device.

## Getting Started

Add a dependency to your pubspec.yaml

```dart
dependencies:
	usbserial: ^0.0.1
```

include the usbserial package at the top of your dart file.

```dart
import 'package:usbserial/usbserial.dart'
```

## Usage

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

	bool openResult = await _port.open();
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

## Dependencies

This library depends on:

https://github.com/felHR85/UsbSerial