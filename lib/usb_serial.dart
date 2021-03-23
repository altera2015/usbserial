import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'types.dart';

/// Created when a USB event occurs. For example a USB device is plugged
/// in or removed.
///
/// Example:
/// ```dart
/// UsbSerial.usbEventStream.listen((UsbEvent msg) {
///   print(msg);
///   if (msg.event == UsbEvent.ACTION_USB_ATTACHED) {
///     // open a device now...
///   }
///   if (msg.event == UsbEvent.ACTION_USB_DETACHED) {
///     //  close device now...
///   }
/// });
/// ```
class UsbEvent {
  /// Event passed to usbEventStream when a USB device is attached.
  static const String ACTION_USB_ATTACHED =
      "android.hardware.usb.action.USB_DEVICE_ATTACHED";

  /// Event passed to usbEventStream when a USB device is detached.
  static const String ACTION_USB_DETACHED =
      "android.hardware.usb.action.USB_DEVICE_DETACHED";

  /// either ACTION_USB_ATTACHED or ACTION_USB_DETACHED
  String? event;

  /// The device for which the event was fired.
  UsbDevice? device;

  @override
  String toString() {
    return "UsbEvent: $event, $device";
  }
}

/// UsbPort handles the communication with the USB Serial port.
class UsbPort extends AsyncDataSinkSource {
  /// Constant to configure port with 5 databits.
  static const int DATABITS_5 = 5;

  /// Constant to configure port with 6 databits.
  static const int DATABITS_6 = 6;

  /// Constant to configure port with 7 databits.
  static const int DATABITS_7 = 7;

  /// Constant to configure port with 8 databits.
  static const int DATABITS_8 = 8;

  /// Constant to configure port with no flow control
  static const int FLOW_CONTROL_OFF = 0;

  /// Constant to configure port with flow control RTS/CTS
  static const int FLOW_CONTROL_RTS_CTS = 1;

  /// Constant to configure port with flow contorl DSR / DTR
  static const int FLOW_CONTROL_DSR_DTR = 2;

  /// Constant to configure port with flow control XON XOFF
  static const int FLOW_CONTROL_XON_XOFF = 3;

  /// Constant to configure port with parity none
  static const int PARITY_NONE = 0;

  /// Constant to configure port with event parity.
  static const int PARITY_EVEN = 2;

  /// Constant to configure port with odd parity.
  static const int PARITY_ODD = 1;

  /// Constant to configure port with mark parity.
  static const int PARITY_MARK = 3;

  /// Constant to configure port with space parity.
  static const int PARITY_SPACE = 4;

  /// Constant to configure port with 1 stop bits
  static const int STOPBITS_1 = 1;

  /// Constant to configure port with 1.5 stop bits
  static const int STOPBITS_1_5 = 3;

  /// Constant to configure port with 2 stop bits
  static const int STOPBITS_2 = 2;

  final MethodChannel _channel;
  final EventChannel _eventChannel;
  Stream<Uint8List>? _inputStream;

  UsbPort._internal(this._channel, this._eventChannel);

  /// Factory to create UsbPort object.
  ///
  /// You don't need to use this directly as you get UsbPort from
  /// [UsbDevice.create].
  factory UsbPort(String methodChannelName) {
    return UsbPort._internal(MethodChannel(methodChannelName),
        EventChannel(methodChannelName + "/stream"));
  }

  /// returns the asynchronous input stream.
  ///
  /// Example
  ///
  /// ```dart
  /// UsbPort port = await device.create();
  /// await port.open();
  /// port.inputStream.listen( (Uint8List data) { print(data); } );
  /// ```
  ///
  /// This will print out the data as it arrives from the uart.
  ///
  @override
  Stream<Uint8List> get inputStream {
    if (_inputStream == null) {
      _inputStream = _eventChannel
          .receiveBroadcastStream()
          .map<Uint8List>((dynamic value) => value);
    }
    return _inputStream!;
  }

  /// Opens the uart communication channel.
  ///
  /// returns true if successful or false if failed.
  Future<bool> open() async {
    return await _channel.invokeMethod("open");
  }

  /// Closes the com port.
  Future<bool> close() async {
    return await _channel.invokeMethod("close");
  }

  /// Sets or clears the DTR port to value [dtr].
  Future<void> setDTR(bool dtr) async {
    return await _channel.invokeMethod("setDTR", {"value": dtr});
  }

  /// Sets or clears the RTS port to value [rts].
  Future<void> setRTS(bool rts) async {
    return await _channel.invokeMethod("setRTS", {"value": rts});
  }

  /// Asynchronously writes [data].
  @override
  Future<void> write(Uint8List data) async {
    return await _channel.invokeMethod("write", {"data": data});
  }

  /// Sets the port parameters to the requested values.
  ///
  /// ```dart
  /// _port.setPortParameters(115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
  /// ```
  Future<void> setPortParameters(
      int baudRate, int dataBits, int stopBits, int parity) async {
    return await _channel.invokeMethod("setPortParameters", {
      "baudRate": baudRate,
      "dataBits": dataBits,
      "stopBits": stopBits,
      "parity": parity
    });
  }

  /// Sets the flow control parameter.
  Future<void> setFlowControl(int flowControl) async {
    return await _channel
        .invokeMethod("setFlowControl", {"flowControl": flowControl});
  }
}

/// UsbDevice holds the USB device information
///
/// This is used to determine which Usb Device to open.
class UsbDevice {
  /// Vendor Id
  final int vid;

  /// Product Id
  final int pid;
  final String productName;
  final String manufacturerName;

  /// The device id is unique to this Usb Device until it is unplugged.
  /// when replugged this ID will be different.
  final int deviceId;

  /// The Serial number from the USB device.
  final String serial;

  /// The number of interfaces on this UsbPort
  final int interfaceCount;

  UsbDevice(this.vid, this.pid, this.productName, this.manufacturerName,
      this.deviceId, this.serial, this.interfaceCount);

  static UsbDevice fromJSON(dynamic json) {
    return UsbDevice(
        json["vid"],
        json["pid"],
        json["productName"],
        json["manufacturerName"],
        json["deviceId"],
        json["serialNumber"],
        json["interfaceCount"]);
  }

  @override
  String toString() {
    return "UsbDevice: ${vid.toRadixString(16)}-${pid.toRadixString(16)} $productName, $manufacturerName $serial";
  }

  /// Creates a UsbPort from the UsbDevice.
  ///
  /// [type] can be any of the [UsbSerial.CDC], [UsbSerial.CH34x], [UsbSerial.CP210x], [UsbSerial.FTDI] or [USBSerial.PL2303] values or empty for auto detection.
  /// [iface] is the USB interface to use or -1 to auto detect.
  /// returns the new UsbPort or throws an error on open failure.
  Future<UsbPort?> create([String type = "", int iface = -1]) {
    return UsbSerial.createFromDeviceId(deviceId, type, iface);
  }
}

/// UsbSerial is the main entry point into this class and can
/// create UsbPorts or list devices.
class UsbSerial {
  /// CDC class constant. Very common USB to UART bridge type. Used by [create]
  static const String CDC = "cdc";

  /// CH34X hardware type. Used by [create]
  static const String CH34x = "ch34x";

  /// CP210x hardware type. Used by [create]
  static const String CP210x = "cp210x";

  /// FTDI Hardware USB to Uart bridge. (Very common) Used by [create]
  static const String FTDI = "ftdi";

  /// PL2303 Hardware USB to Uart bridge. (Fairly common) Used by [create]
  static const String PL2303 = "pl2303";

  static const MethodChannel _channel = const MethodChannel('usb_serial');
  static const EventChannel _eventChannel =
      const EventChannel('usb_serial/usb_events');
  static Stream<UsbEvent>? _eventStream;

  /// Use this stream to detect if a USB device is plugged in or removed.
  ///
  /// Example
  /// ```dart
  /// @override
  /// void initState() {
  ///   super.initState();
  ///
  ///   UsbSerial.usbEventStream.listen((String event) {
  ///     print("Usb Event $event");
  ///     setState(() {
  ///       _lastEvent = event;
  ///     });
  ///   });
  /// }
  /// ```
  static Stream<UsbEvent> get usbEventStream {
    if (_eventStream == null) {
      _eventStream =
          _eventChannel.receiveBroadcastStream().map<UsbEvent>((value) {
        UsbEvent msg = UsbEvent();
        msg.device = UsbDevice.fromJSON(value);
        msg.event = value["event"];
        return msg;
      });
    }
    return _eventStream!;
  }

  /// Creates a UsbPort from vid, pid and optionally type and interface.
  /// throws an error on failure. This function will pop up a permission
  /// request if needed.
  ///
  /// [vid] = Vendor Id
  /// [pid] = Product Id
  /// [type] = One of [UserSerial.CDC], [UsbSerial.CH34x], [UsbSerial.CP210x], [UsbSerial.FTDI], [UsbSerial.PL2303] or empty for auto detect.
  /// [interface] = Interface of the Usb Interface, -1 for auto detect.
  ///
  /// Example for a fake device with VID 0x1000 and PID 0x2000
  /// ```dart
  /// UsbPort port = await UsbSerial.create(0x1000, 0x2000);
  /// ```
  static Future<UsbPort?> create(int vid, int pid,
      [String type = "", int interface = -1]) async {
    final methodChannelName = await _channel.invokeMethod("create", {
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

  /// Creates a UsbPort from deviceId optionally type and interface.
  /// throws an error on failure. This function will pop up a permission
  /// request if needed. Note deviceId is only valid for the duration
  /// of a device being plugged in. Once unplugged and replugged this
  /// id changes.
  ///
  /// [type] = One of [UserSerial.CDC], [UsbSerial.CH34x], [UsbSerial.CP210x], [UsbSerial.FTDI], [UsbSerial.PL2303] or empty for auto detect.
  /// [interface] = Interface of the Usb Interface, -1 for auto detect.
  static Future<UsbPort?> createFromDeviceId(int deviceId,
      [String type = "", int interface = -1]) async {
    final methodChannelName = await _channel.invokeMethod("create", {
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

  /// Returns a list of UsbDevices currently plugged in.
  static Future<List<UsbDevice>> listDevices() async {
    List<dynamic> devices = await _channel.invokeMethod("listDevices");
    return devices.map(UsbDevice.fromJSON).toList();
  }
}
