import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  UsbPort _port;
  String _lastEvent = "None";

  @override
  void initState() {
    super.initState();

    UsbSerial.usbEventStream.listen((UsbEvent event) {
      print("Usb Event $event");
      setState(() {
        _lastEvent = event.toString();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(
        title: const Text('USB Serial Plugin example app'),
      ),
      body: Center(
          child: Column(children: <Widget>[
        Text('Last Event: $_lastEvent\n'),
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () async {
            if (_port != null) {
              _port.close();
              _port = null;
            }

            List<UsbDevice> devices = await UsbSerial.listDevices();
            print(devices);

            if (devices.length > 0) {
              _port = await devices[0].create();

              bool openResult = await _port.open();
              await _port.setDTR(true);
              await _port.setRTS(true);
              print(openResult);

              _port.setPortParameters(115200, UsbPort.DATABITS_8,
                  UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

              _port.inputStream.listen((Uint8List event) {
                print(event);
              });
            }
          },
        ),
        IconButton(
          icon: Icon(Icons.send),
          onPressed: () async {
            Uint8List data = Uint8List.fromList([0x10, 0x00]);
            await _port.write(data);
          },
        )
      ])),
    ));
  }
}
