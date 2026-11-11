import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usb_serial_example/main.dart';

void main() {
  testWidgets('renders the device list from the platform channel',
      (WidgetTester tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('usb_serial'),
        (call) async {
      if (call.method == 'listDevices') {
        return [
          {
            'deviceName': '/dev/bus/usb/001/002',
            'vid': 0x0403,
            'pid': 0x6001,
            'manufacturerName': 'FTDI',
            'productName': 'FT232R USB UART',
            'deviceId': 1002,
          }
        ];
      }
      return null;
    });
    messenger.setMockStreamHandler(const EventChannel('usb_serial/usb_events'),
        MockStreamHandler.inline(onListen: (args, sink) {}));
    addTearDown(() {
      messenger.setMockMethodCallHandler(
          const MethodChannel('usb_serial'), null);
      messenger.setMockStreamHandler(
          const EventChannel('usb_serial/usb_events'), null);
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Available Serial Ports'), findsOneWidget);
    expect(find.text('FT232R USB UART'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Connect'), findsOneWidget);
    expect(find.textContaining('Status: '), findsOneWidget);
  });
}
