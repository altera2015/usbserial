// Contract tests for the Dart <-> platform channel protocol.
//
// These tests mock the platform side of the `usb_serial` method/event
// channels and pin down exactly which method names, argument maps and
// payloads the Dart API sends and expects. Any Android backend
// (felHR85 UsbSerial, usb-serial-for-android, ...) has to honour this
// contract for existing apps to keep working.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usb_serial/usb_serial.dart';

const MethodChannel pluginChannel = MethodChannel('usb_serial');
const EventChannel usbEventsChannel = EventChannel('usb_serial/usb_events');
const String portChannelName = 'usb_serial/UsbSerialPortAdapter/7';

TestDefaultBinaryMessenger get messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

Map<String, Object?> devicePayload({
  String deviceName = '/dev/bus/usb/001/002',
  int vid = 0x0403,
  int pid = 0x6001,
  int deviceId = 1002,
}) =>
    <String, Object?>{
      'deviceName': deviceName,
      'vid': vid,
      'pid': pid,
      'manufacturerName': 'FTDI',
      'productName': 'FT232R USB UART',
      'interfaceCount': 1,
      'serialNumber': 'A50285BI',
      'deviceId': deviceId,
    };

/// Records every call made on [channel] and answers with [reply].
List<MethodCall> recordCalls(
  MethodChannel channel, [
  Object? Function(MethodCall call)? reply,
]) {
  final calls = <MethodCall>[];
  messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
    calls.add(call);
    return reply?.call(call);
  });
  return calls;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    messenger.setMockMethodCallHandler(pluginChannel, null);
    messenger.setMockMethodCallHandler(
        const MethodChannel(portChannelName), null);
    messenger.setMockStreamHandler(usbEventsChannel, null);
    messenger.setMockStreamHandler(
        const EventChannel('$portChannelName/stream'), null);
  });

  group('UsbSerial.listDevices', () {
    test('invokes listDevices and maps every field of the payload', () async {
      final calls = recordCalls(pluginChannel, (_) => [devicePayload()]);

      final devices = await UsbSerial.listDevices();

      expect(calls.single.method, 'listDevices');
      expect(calls.single.arguments, isNull);
      expect(devices, hasLength(1));
      final d = devices.single;
      expect(d.deviceName, '/dev/bus/usb/001/002');
      expect(d.vid, 0x0403);
      expect(d.pid, 0x6001);
      expect(d.manufacturerName, 'FTDI');
      expect(d.productName, 'FT232R USB UART');
      expect(d.interfaceCount, 1);
      expect(d.serial, 'A50285BI');
      expect(d.deviceId, 1002);
      expect(d.port, isNull);
    });

    test('tolerates optional fields being absent (pre-Lollipop devices)',
        () async {
      recordCalls(
          pluginChannel,
          (_) => [
                <String, Object?>{
                  'deviceName': '/dev/bus/usb/001/003',
                  'vid': 0x1a86,
                  'pid': 0x7523,
                  'deviceId': 1003,
                }
              ]);

      final d = (await UsbSerial.listDevices()).single;

      expect(d.vid, 0x1a86);
      expect(d.productName, isNull);
      expect(d.manufacturerName, isNull);
      expect(d.serial, isNull);
      expect(d.interfaceCount, isNull);
    });

    test('returns an empty list when nothing is plugged in', () async {
      recordCalls(pluginChannel, (_) => <Object?>[]);
      expect(await UsbSerial.listDevices(), isEmpty);
    });
  });

  group('UsbSerial.create', () {
    test('sends vid/pid with deviceId -1 and default type/interface', () async {
      final calls = recordCalls(pluginChannel, (_) => portChannelName);

      final port = await UsbSerial.create(0x0403, 0x6001);

      expect(port, isA<UsbPort>());
      expect(calls.single.method, 'create');
      expect(calls.single.arguments, <String, Object?>{
        'type': '',
        'vid': 0x0403,
        'pid': 0x6001,
        'deviceId': -1,
        'interface': -1,
      });
    });

    test('forwards explicit type and interface', () async {
      final calls = recordCalls(pluginChannel, (_) => portChannelName);

      await UsbSerial.create(0x067b, 0x2303, UsbSerial.PL2303, 2);

      expect(calls.single.arguments, <String, Object?>{
        'type': 'pl2303',
        'vid': 0x067b,
        'pid': 0x2303,
        'deviceId': -1,
        'interface': 2,
      });
    });

    test('returns null when the platform returns no channel name', () async {
      recordCalls(pluginChannel, (_) => null);
      expect(await UsbSerial.create(1, 2), isNull);
    });

    test('propagates PlatformException from the platform side', () async {
      messenger.setMockMethodCallHandler(pluginChannel, (call) async {
        throw PlatformException(
            code: 'UsbSerialPortAdapter', message: 'Not an Serial device.');
      });

      expect(
        UsbSerial.create(1, 2),
        throwsA(isA<PlatformException>()
            .having((e) => e.message, 'message', 'Not an Serial device.')),
      );
    });

    test('type constants match the strings the platform side expects', () {
      expect(UsbSerial.CDC, 'cdc');
      expect(UsbSerial.CH34x, 'ch34x');
      expect(UsbSerial.CP210x, 'cp210x');
      expect(UsbSerial.FTDI, 'ftdi');
      expect(UsbSerial.PL2303, 'pl2303');
    });
  });

  group('UsbSerial.createFromDeviceId / UsbDevice.create', () {
    test('createFromDeviceId sends vid/pid -1 and the deviceId', () async {
      final calls = recordCalls(pluginChannel, (_) => portChannelName);

      final port = await UsbSerial.createFromDeviceId(1002, UsbSerial.FTDI, 0);

      expect(port, isA<UsbPort>());
      expect(calls.single.method, 'create');
      expect(calls.single.arguments, <String, Object?>{
        'type': 'ftdi',
        'vid': -1,
        'pid': -1,
        'deviceId': 1002,
        'interface': 0,
      });
    });

    test('UsbDevice.create uses its deviceId and stores the port', () async {
      final calls = recordCalls(pluginChannel, (_) => portChannelName);
      final device = UsbDevice.fromJSON(devicePayload(deviceId: 42));

      final port = await device.create(UsbSerial.CDC, 1);

      expect(calls.single.arguments, <String, Object?>{
        'type': 'cdc',
        'vid': -1,
        'pid': -1,
        'deviceId': 42,
        'interface': 1,
      });
      expect(port, isNotNull);
      expect(device.port, same(port));
    });

    test('UsbDevice.create returns null and clears port on null reply',
        () async {
      recordCalls(pluginChannel, (_) => null);
      final device = UsbDevice.fromJSON(devicePayload());

      expect(await device.create(), isNull);
      expect(device.port, isNull);
    });
  });

  group('UsbPort method channel', () {
    late List<MethodCall> calls;
    late UsbPort port;

    setUp(() {
      calls = recordCalls(const MethodChannel(portChannelName), (call) {
        switch (call.method) {
          case 'open':
          case 'close':
            return true;
          default:
            return null;
        }
      });
      port = UsbPort(portChannelName);
    });

    test('open and close return the platform result', () async {
      expect(await port.open(), isTrue);
      expect(await port.close(), isTrue);
      expect(calls.map((c) => c.method), ['open', 'close']);
      expect(calls.every((c) => c.arguments == null), isTrue);
    });

    test('open returns false when the platform fails to open', () async {
      messenger.setMockMethodCallHandler(
          const MethodChannel(portChannelName), (call) async => false);
      expect(await port.open(), isFalse);
    });

    test('write sends the bytes as a Uint8List under "data"', () async {
      await port.write(Uint8List.fromList([0x01, 0x02, 0xff]));

      expect(calls.single.method, 'write');
      final data = (calls.single.arguments as Map)['data'];
      expect(data, isA<Uint8List>());
      expect(data, [0x01, 0x02, 0xff]);
    });

    test('setDTR / setRTS send {"value": bool}', () async {
      await port.setDTR(true);
      await port.setRTS(false);

      expect(calls[0].method, 'setDTR');
      expect(calls[0].arguments, {'value': true});
      expect(calls[1].method, 'setRTS');
      expect(calls[1].arguments, {'value': false});
    });

    test('setPortParameters sends all four values and updates getters',
        () async {
      await port.setPortParameters(
          9600, UsbPort.DATABITS_7, UsbPort.STOPBITS_2, UsbPort.PARITY_EVEN);

      expect(calls.single.method, 'setPortParameters');
      expect(calls.single.arguments, {
        'baudRate': 9600,
        'dataBits': 7,
        'stopBits': 2,
        'parity': 2,
      });
      expect(port.baudRate, 9600);
      expect(port.dataBits, UsbPort.DATABITS_7);
      expect(port.stopBits, UsbPort.STOPBITS_2);
      expect(port.parity, UsbPort.PARITY_EVEN);
    });

    test('setFlowControl sends {"flowControl": int}', () async {
      await port.setFlowControl(UsbPort.FLOW_CONTROL_RTS_CTS);

      expect(calls.single.method, 'setFlowControl');
      expect(calls.single.arguments, {'flowControl': 1});
      expect(port.flowControlToString(), 'FLOW_CONTROL_RTS_CTS');
    });

    test('numeric constants match the values the platform side expects', () {
      expect([
        UsbPort.DATABITS_5,
        UsbPort.DATABITS_6,
        UsbPort.DATABITS_7,
        UsbPort.DATABITS_8
      ], [
        5,
        6,
        7,
        8
      ]);
      expect([
        UsbPort.FLOW_CONTROL_OFF,
        UsbPort.FLOW_CONTROL_RTS_CTS,
        UsbPort.FLOW_CONTROL_DSR_DTR,
        UsbPort.FLOW_CONTROL_XON_XOFF
      ], [
        0,
        1,
        2,
        3
      ]);
      expect([
        UsbPort.PARITY_NONE,
        UsbPort.PARITY_ODD,
        UsbPort.PARITY_EVEN,
        UsbPort.PARITY_MARK,
        UsbPort.PARITY_SPACE
      ], [
        0,
        1,
        2,
        3,
        4
      ]);
      expect([UsbPort.STOPBITS_1, UsbPort.STOPBITS_2, UsbPort.STOPBITS_1_5],
          [1, 2, 3]);
    });

    test('PlatformException from a port call propagates', () async {
      messenger.setMockMethodCallHandler(const MethodChannel(portChannelName),
          (call) async {
        throw PlatformException(code: 'UsbSerialPortAdapter');
      });
      expect(port.setDTR(true), throwsA(isA<PlatformException>()));
    });
  });

  group('UsbPort.inputStream', () {
    test('listens on "<channel>/stream" and emits Uint8List chunks', () async {
      messenger.setMockStreamHandler(
        const EventChannel('$portChannelName/stream'),
        MockStreamHandler.inline(onListen: (args, sink) {
          sink.success(Uint8List.fromList([0x48, 0x69]));
          sink.success(Uint8List.fromList([0x0d, 0x0a]));
          sink.endOfStream();
        }),
      );
      final port = UsbPort(portChannelName);

      expect(
        port.inputStream,
        emitsInOrder([
          [0x48, 0x69],
          [0x0d, 0x0a],
          emitsDone,
        ]),
      );
    });

    test('returns the same stream instance on repeated access', () {
      final port = UsbPort(portChannelName);
      expect(identical(port.inputStream, port.inputStream), isTrue);
    });
  });

  group('UsbSerial.usbEventStream', () {
    test('maps attach/detach payloads to UsbEvent', () async {
      messenger.setMockStreamHandler(
        usbEventsChannel,
        MockStreamHandler.inline(onListen: (args, sink) {
          sink.success({
            ...devicePayload(),
            'event': UsbEvent.ACTION_USB_ATTACHED,
          });
          sink.success({
            ...devicePayload(),
            'event': UsbEvent.ACTION_USB_DETACHED,
          });
        }),
      );

      final events = await UsbSerial.usbEventStream!.take(2).toList();

      expect(events.map((e) => e.event), [
        'android.hardware.usb.action.USB_DEVICE_ATTACHED',
        'android.hardware.usb.action.USB_DEVICE_DETACHED',
      ]);
      expect(events.first.device!.vid, 0x0403);
      expect(events.first.device!.deviceName, '/dev/bus/usb/001/002');
    });

    test('is cached across accesses', () {
      expect(identical(UsbSerial.usbEventStream, UsbSerial.usbEventStream),
          isTrue);
    });
  });

  group('UsbDevice equality', () {
    test('devices are equal when deviceName matches', () {
      final a = UsbDevice.fromJSON(devicePayload(deviceId: 1));
      final b = UsbDevice.fromJSON(devicePayload(deviceId: 2));
      final c =
          UsbDevice.fromJSON(devicePayload(deviceName: '/dev/bus/usb/001/009'));

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect([a].contains(b), isTrue);
    });
  });

  group('UsbPort equality', () {
    test('ports compare by their configured settings', () async {
      recordCalls(const MethodChannel(portChannelName));
      final a = UsbPort(portChannelName);
      final b = UsbPort(portChannelName);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);

      await a.setPortParameters(
          9600, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
      expect(a, isNot(equals(b)));
    });
  });
}
