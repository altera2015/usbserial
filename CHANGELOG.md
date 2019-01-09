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