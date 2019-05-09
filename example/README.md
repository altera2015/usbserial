# UsbSerial full example

The [example/lib/main.dart](https://github.com/altera2015/usbserial/blob/master/example/lib/main.dart) file
contains a full example of how to use the serial library. It is sending data terminated with \r\n and 
waits for lines terminated with \r\n to arrive. If you don't have a device like that but do have an
Arduino at hand the sketch below will create such a magical device for you.

```C++
  int i = 0;
  
  // the setup function runs once when you press reset or power the board
  void setup() {
    // initialize digital pin 13 as an output.
    pinMode(13, OUTPUT);
    Serial.begin(115200);
    while ( !Serial ) {
    }
    digitalWrite(13, HIGH);   // turn the LED on (HIGH is the voltage level)
  }
   
  // the loop function runs over and over again forever
  void loop() {    
    if ( Serial.available() ) {
      if ( i == 0 ) {
        digitalWrite(13, HIGH);   // turn the LED on (HIGH is the voltage level)
        i = 1;
      } else {
        digitalWrite(13, LOW);    // turn the LED off by making the voltage LOW
        i = 0;
      }
      Serial.write( Serial.read() );
    }    
  }
``` 

## Quick Getting Started

Below is an abbreviated example showing the essentials to getting the UsbSerial library to work.

```dart
import 'package:usb_serial/usb_serial.dart';
import 'package:usb_serial/transaction.dart';


class _MyAppState extends State<MyApp> {
    var _port;    
    StreamSubscription<Uint8List> _subscription;
    
    @override
    void initState() async {
      super.initState();
    
      List<UsbDevice> devices = await UsbSerial.listDevices();
      if ( devices.length == 0 ) {
        return;
      }
      _port = devices[0].create();
      
      if (!await _port.open()) {
        return;
      }
      await _port.setDTR(true);
      await _port.setRTS(true);
      await _port.setPortParameters(
        115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
      
      _subscription = _port.inputStream.stream.listen((String line) {          
        print(line);        
      });
      
      _port.write(Uint8List.fromList([65,66,13,10]));
    }
    
    @override
    void dispose() {
      super.dispose();
      if ( _port != null ) {
        _subscription.cancel();
        _port.close();
        _port = null;
      }
    }



    /// elsewhere in your dart file:

    onPressed: () {
	  _port.write(Uint8List.fromList([65,66,13,10]))
    }
	
```

### Further Examples

Have a look at [the test directory](https://github.com/altera2015/usbserial/blob/master/test/) if you need more examples.