import 'dart:async';

import 'package:flutter/services.dart';
import 'dart:typed_data';

class UsbPort {
  static const int DATABITS_5 = 5;
  static const int DATABITS_6 = 6;
  static const int DATABITS_7 = 7;
  static const int DATABITS_8 = 8;

  static const int FLOW_CONTROL_OFF = 0;
  static const int FLOW_CONTROL_RTS_CTS = 1;
  static const int FLOW_CONTROL_DSR_DTR = 2;
  static const int FLOW_CONTROL_XON_XOFF = 3;

  static const int PARITY_NONE = 0;
  static const int PARITY_ODD = 1;
  static const int PARITY_MARK = 3;
  static const int PARITY_SPACE = 4;

  static const int STOPBITS_1 = 1;
  static const int STOPBITS_1_5 = 3;
  static const int STOPBITS_2 = 2;

  final MethodChannel _channel;
  final EventChannel _eventChannel;
  Stream<Uint8List> _inputStream;

  UsbPort._internal(this._channel, this._eventChannel);

  factory UsbPort(String methodChannelName) {
    return UsbPort._internal(MethodChannel(methodChannelName),
        EventChannel(methodChannelName + "/stream"));
  }

  Stream<Uint8List> get inputStream {
    if (_inputStream == null) {
      _inputStream = _eventChannel
          .receiveBroadcastStream()
          .map<Uint8List>((value) => value);
    }
    return _inputStream;
  }

  Future<bool> open() async {
    return await _channel.invokeMethod("open");
  }

  Future<bool> close() async {
    return await _channel.invokeMethod("close");
  }

  Future<void> setDTR(bool dtr) async {
    return await _channel.invokeMethod("setDTR", {"value": dtr});
  }

  Future<void> setRTS(bool rts) async {
    return await _channel.invokeMethod("setRTS", {"value": rts});
  }

  Future<void> write(Uint8List data) async {
    return await _channel.invokeMethod("write", {"data": data});
  }

  Future<void> setPortParameters(
      int baudRate, int dataBits, int stopBits, int parity) async {
    return await _channel.invokeMethod("setPortParameters", {
      "baudRate": baudRate,
      "dataBits": dataBits,
      "stopBits": stopBits,
      "parity": parity
    });
  }

  Future<void> setFlowControl(int flowControl) async {
    return await _channel
        .invokeMethod("setFlowControl", {"flowControl": flowControl});
  }
}

class UsbDevice {
  final int vid;
  final int pid;
  final String productName;
  final String manufacturerName;
  final int deviceId;
  final String serial;

  UsbDevice(this.vid, this.pid, this.productName, this.manufacturerName,
      this.deviceId, this.serial);
  static UsbDevice fromJSON(dynamic json) {
    return UsbDevice(json["vid"], json["pid"], json["productName"],
        json["manufacturerName"], json["deviceId"], json["serialNumber"]);
  }

  String toString() {
    return "UsbDevice: ${vid.toRadixString(16)}-${pid.toRadixString(16)} $productName, $manufacturerName $serial";
  }

  Future<UsbPort> create([String type = "", int iface = -1]) {
    return UsbSerial.createFromDeviceId(deviceId, type, iface);
  }
}

class UsbSerial {
  static const String CDC = "cdc";
  static const String CH34x = "ch34x";
  static const String CP210x = "cp210x";
  static const String FTDI = "ftdi";
  static const String PL2303 = "pl2303";

  static const MethodChannel _channel = const MethodChannel('usb_serial');
  static const EventChannel _eventChannel =
      const EventChannel('usb_serial/usb_events');
  static Stream<String> _eventStream;

  static Stream<String> get usbEventStream {
    if (_eventStream == null) {
      _eventStream =
          _eventChannel.receiveBroadcastStream().map<String>((value) => value);
    }
    return _eventStream;
  }

  static Future<UsbPort> create(int vid, int pid,
      [String type = "", int interface = -1]) async {
    String methodChannelName = await _channel.invokeMethod("create", {
      "type": type,
      "vid": vid,
      "pid": pid,
      "deviceId": -1,
      "interface": interface
    });

    if (methodChannelName == null) {
      return null;
    }

    return new UsbPort(methodChannelName);
  }

  static Future<UsbPort> createFromDeviceId(int deviceId,
      [String type = "", int interface = -1]) async {
    String methodChannelName = await _channel.invokeMethod("create", {
      "type": type,
      "vid": -1,
      "pid": -1,
      "deviceId": deviceId,
      "interface": interface
    });

    if (methodChannelName == null) {
      return null;
    }

    return new UsbPort(methodChannelName);
  }

  static Future<List<UsbDevice>> listDevices() async {
    List<dynamic> devices = await _channel.invokeMethod("listDevices");
    return devices.map(UsbDevice.fromJSON).toList();
  }
}
