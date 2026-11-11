import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  UsbPort? _port;
  String _status = "Idle";
  List<Widget> _ports = [];
  final List<Widget> _serialData = [];

  StreamSubscription<String>? _subscription;
  StreamSubscription<UsbEvent>? _usbEvents;
  Transaction<String>? _transaction;
  UsbDevice? _device;

  final TextEditingController _textController = TextEditingController();

  Future<bool> _connectTo(UsbDevice? device) async {
    _serialData.clear();

    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }

    if (_transaction != null) {
      _transaction!.dispose();
      _transaction = null;
    }

    if (_port != null) {
      _port!.close();
      _port = null;
    }

    if (device == null) {
      _device = null;
      setState(() {
        _status = "Disconnected";
      });
      return true;
    }

    _port = await device.create();
    if (await (_port!.open()) != true) {
      setState(() {
        _status = "Failed to open port";
      });
      return false;
    }
    _device = device;

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(
        115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _transaction = Transaction.stringTerminated(
        _port!.inputStream as Stream<Uint8List>, Uint8List.fromList([13, 10]));

    _subscription = _transaction!.stream.listen((String line) {
      setState(() {
        _serialData.add(Text(line));
        if (_serialData.length > 20) {
          _serialData.removeAt(0);
        }
      });
    });

    setState(() {
      _status = "Connected";
    });
    return true;
  }

  void _getPorts() async {
    _ports = [];
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (!mounted) {
      return;
    }
    if (!devices.contains(_device)) {
      _connectTo(null);
    }
    debugPrint(devices.toString());

    for (var device in devices) {
      _ports.add(ListTile(
          leading: Icon(Icons.usb),
          title: Text(device.productName ?? 'Unknown device'),
          subtitle: Text(device.manufacturerName ?? ''),
          trailing: ElevatedButton(
            child: Text(_device == device ? "Disconnect" : "Connect"),
            onPressed: () {
              _connectTo(_device == device ? null : device).then((res) {
                _getPorts();
              });
            },
          )));
    }

    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    _usbEvents = UsbSerial.usbEventStream!.listen((UsbEvent event) {
      _getPorts();
    });

    _getPorts();
  }

  @override
  void dispose() {
    _usbEvents?.cancel();
    _subscription?.cancel();
    _transaction?.dispose();
    _port?.close();
    _textController.dispose();
    super.dispose();
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
        Text(
            _ports.isNotEmpty
                ? "Available Serial Ports"
                : "No serial devices available",
            style: Theme.of(context).textTheme.titleLarge),
        ..._ports,
        Text('Status: $_status\n'),
        Text('info: ${_port.toString()}\n'),
        ListTile(
          title: TextField(
            controller: _textController,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Text To Send',
            ),
          ),
          trailing: ElevatedButton(
            onPressed: _port == null
                ? null
                : () async {
                    if (_port == null) {
                      return;
                    }
                    String data = "${_textController.text}\r\n";
                    await _port!.write(Uint8List.fromList(data.codeUnits));
                    _textController.text = "";
                  },
            child: Text("Send"),
          ),
        ),
        Text("Result Data", style: Theme.of(context).textTheme.titleLarge),
        ..._serialData,
      ])),
    ));
  }
}
