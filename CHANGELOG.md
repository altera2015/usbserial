## 0.5.1
* Improve Java handling of null pointers.
* Update gradle version on sample.

## 0.5.0
* Support newer Android version.
* Linter fixes.
* Add device name mapping.
* Add access to maxLen parameter for long serial messages.

## 0.4.0
* Use deviceName (unique and not null) for equal operator and hashCode.

## 0.3.0

* Implemented v2 Android embedding
* Updated UsbSerial to 6.1.0
* Transaction constructor signature changed to fix issue #39 (see test testTwoTransformersInSequence)

## 0.2.991

* Addressed issue #46
* Fixed @immutable error

## 0.2.99

* Merged null safety pull request

## 0.2.4

* Added interfaceCount
* Added CH340 VID/PID to example xml.
* Added exception catch for Device Create

## 0.2.3

* Fixed threading issue ( PR10 )

## 0.2.2

* Fixed 3 dart lint warnings.

## 0.2.1

* Updated the underlying UsbSerial library to 6.0.6
* Updated the examples

## 0.2.0

* Added Transformers and Transactions
* Added unit tests
* Changed Java naming, if your compile fails delete the 'build' directory and try again.

## 0.1.1

* Merged pull request 1: Fix for NoSuchMethodException thrown on api level less than 21
  during device enumeration.

## 0.1.0

* Modified the USB Attached/Detach stream from Stream<String> to Stream<UsbEvent> to
  carry additional information about the device being added or removed.
* Added ACTION_USB_ATTACHED and ACTION_USB_DETACHED constants to dart interface.

## 0.0.2

* Fixed crasher when connected or disconnecting a USB device without having
  a sink attached.

## 0.0.1

* Initial release, providing easy UART access to Android Flutter apps