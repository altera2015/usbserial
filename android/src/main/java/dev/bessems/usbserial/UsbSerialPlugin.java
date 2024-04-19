package dev.bessems.usbserial;

import android.annotation.SuppressLint;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbDeviceConnection;
import android.hardware.usb.UsbManager;
import android.os.Build;
import android.util.Log;

import com.felhr.usbserial.UsbSerialDevice;

import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.List;
import java.util.ArrayList;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.EventChannel;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;

import androidx.annotation.NonNull;


/** UsbSerialPlugin */
public class UsbSerialPlugin implements FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private final String TAG = UsbSerialPortAdapter.class.getSimpleName();

    private android.content.Context m_Context;
    private UsbManager m_Manager;
    private int m_InterfaceId;
    private BinaryMessenger m_Messenger;
    private EventChannel.EventSink m_EventSink;

    private static final String ACTION_USB_PERMISSION = "com.android.example.USB_PERMISSION";
    public static final String ACTION_USB_ATTACHED = "android.hardware.usb.action.USB_DEVICE_ATTACHED";
    public static final String ACTION_USB_DETACHED = "android.hardware.usb.action.USB_DEVICE_DETACHED";


    private final BroadcastReceiver usbReceiver = new BroadcastReceiver() {

        private UsbDevice getUsbDeviceFromIntent(Intent intent) {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                return intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice.class);
            } else {
                // Create local variable to keep scope of deprecation suppression smallest
                @SuppressWarnings("deprecation")
                UsbDevice ret = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
                return ret;
            }
        }

        @Override
        public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();
            if (action == null) {
                return;
            }
            if (action.equals(ACTION_USB_ATTACHED)) {
                Log.d(TAG, "ACTION_USB_ATTACHED");
                if (m_EventSink != null) {
                    UsbDevice device = getUsbDeviceFromIntent(intent);
                    if (device != null) {
                        HashMap<String, Object> msg = serializeDevice(device);
                        msg.put("event", ACTION_USB_ATTACHED);
                        m_EventSink.success(msg);
                    } else {
                        Log.e(TAG, "ACTION_USB_ATTACHED but no EXTRA_DEVICE");
                    }
                }
            } else if (action.equals(ACTION_USB_DETACHED)) {
                Log.d(TAG, "ACTION_USB_DETACHED");
                if (m_EventSink != null) {
                    UsbDevice device = getUsbDeviceFromIntent(intent);
                    if (device != null) {
                        HashMap<String, Object> msg = serializeDevice(device);
                        msg.put("event", ACTION_USB_DETACHED);
                        m_EventSink.success(msg);
                    } else {
                        Log.e(TAG, "ACTION_USB_DETACHED but no EXTRA_DEVICE");
                    }
                }
            }

        }
    };

    public UsbSerialPlugin() {
        m_Messenger = null;
        m_Context = null;
        m_Manager = null;
        m_InterfaceId = 0;
    }


    private interface AcquirePermissionCallback {
        void onSuccess(UsbDevice device);
        void onFailed(UsbDevice device);
    }
    @SuppressLint("PrivateApi")
    private void acquirePermissions(UsbDevice device, AcquirePermissionCallback cb) {

        class BRC2 extends  BroadcastReceiver {

            private final UsbDevice m_Device;
            private final AcquirePermissionCallback m_CB;

            BRC2(UsbDevice device, AcquirePermissionCallback cb ) {
                m_Device = device;
                m_CB = cb;
            }

            @Override
            public void onReceive(Context context, Intent intent) {
                String action = intent.getAction();
                if (ACTION_USB_PERMISSION.equals(action)) {
                    Log.e(TAG, "BroadcastReceiver intent arrived, entering sync...");
                    m_Context.unregisterReceiver(this);
                    synchronized (this) {
                        Log.e(TAG, "BroadcastReceiver in sync");
                        /* UsbDevice device = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE); */
                        if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                            // createPort(m_DriverIndex, m_PortIndex, m_Result, false);
                            m_CB.onSuccess(m_Device);
                        } else {
                            Log.d(TAG, "permission denied for device ");
                            m_CB.onFailed(m_Device);
                        }
                    }
                }
            }
        }

        Context cw = m_Context; //m_Registrar.context();

        BRC2 usbReceiver = new BRC2(device, cb);

        int flags = 0;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = PendingIntent.FLAG_MUTABLE;
        }

        Intent intent = new Intent(ACTION_USB_PERMISSION);

        Class<?> activityThread = null;
        try {
            activityThread = Class.forName("android.app.ActivityThread");
            Method method = activityThread.getDeclaredMethod("currentPackageName");
            String appPackageName = (String) method.invoke(activityThread);
            intent.setPackage(appPackageName);
        } catch (Exception e) {
            // Not too important to throw anything
        }

        PendingIntent permissionIntent = PendingIntent.getBroadcast(cw, 0, intent, flags);

        IntentFilter filter = new IntentFilter(ACTION_USB_PERMISSION);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            cw.registerReceiver(usbReceiver, filter, null, null, Context.RECEIVER_NOT_EXPORTED);
        } else {
            cw.registerReceiver(usbReceiver, filter);
        }

        m_Manager.requestPermission(device, permissionIntent);
    }

    private void openDevice(String type, UsbDevice device, int iface, Result result, boolean allowAcquirePermission) {

        final AcquirePermissionCallback cb = new AcquirePermissionCallback() {

            @Override
            public void onSuccess(UsbDevice device) {
                openDevice(type, device, iface, result, false);
            }

            @Override
            public void onFailed(UsbDevice device) {
                result.error(TAG, "Failed to acquire permissions.", null);
            }
        };

        try {
            UsbDeviceConnection connection = m_Manager.openDevice(device);

            if ( connection == null && allowAcquirePermission ) {
                acquirePermissions(device, cb);
                return;
            }

            UsbSerialDevice serialDeviceDevice;
            if ( type.equals("") ) {
                serialDeviceDevice = UsbSerialDevice.createUsbSerialDevice(device, connection, iface);
            } else {
                serialDeviceDevice = UsbSerialDevice.createUsbSerialDevice(type, device, connection, iface);
            }

            if (serialDeviceDevice != null) {
                int interfaceId = m_InterfaceId++;
                UsbSerialPortAdapter adapter = new UsbSerialPortAdapter(m_Messenger, interfaceId, connection, serialDeviceDevice);
                result.success(adapter.getMethodChannelName());
                Log.d(TAG, "success.");
                return;
            }
            result.error(TAG, "Not an Serial device.", null);

        } catch ( java.lang.SecurityException e ) {

            if ( allowAcquirePermission ) {
                acquirePermissions(device, cb);
            } else {
                result.error(TAG, "Failed to acquire USB permission.", null);
            }
        } catch ( java.lang.Exception e ) {
            result.error(TAG, "Failed to acquire USB device.", null);
        }
    }

    private void createTyped(String type, int vid, int pid, int deviceId, int iface, Result result) {
        Map<String, UsbDevice> devices = m_Manager.getDeviceList();
        for (UsbDevice device : devices.values()) {

            if ( deviceId == device.getDeviceId() || (device.getVendorId() == vid && device.getProductId() == pid) ) {
                openDevice(type, device, iface, result, true);
                return;
            }
        }

        result.error(TAG, "No such device", null);
    }

    private HashMap<String, Object> serializeDevice(UsbDevice device) {
        HashMap<String, Object> dev = new HashMap<>();
        dev.put("deviceName", device.getDeviceName());
        dev.put("vid", device.getVendorId());
        dev.put("pid", device.getProductId());
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
            dev.put("manufacturerName", device.getManufacturerName());
            dev.put("productName", device.getProductName());
            dev.put("interfaceCount", device.getInterfaceCount());
            /* if the app targets SDK >= android.os.Build.VERSION_CODES.Q and the app does not have permission to read from the device. */
            try {
                dev.put("serialNumber", device.getSerialNumber());
            } catch  ( java.lang.SecurityException e ) {
                Log.e(TAG, e.toString());
            }
        }
        dev.put("deviceId", device.getDeviceId());
        return dev;
    }

    private void listDevices(Result result) {
        Map<String, UsbDevice> devices = m_Manager.getDeviceList();
        if ( devices == null ) {
            result.error(TAG, "Could not get USB device list.", null);
            return;
        }
        List<HashMap<String, Object>> transferDevices = new ArrayList<>();

        for (UsbDevice device : devices.values()) {
            transferDevices.add(serializeDevice(device));
        }
        result.success(transferDevices);
    }


    @Override
    public void onListen(Object o, EventChannel.EventSink eventSink) {
        m_EventSink = eventSink;

    }

    @Override
    public void onCancel(Object o) {
        m_EventSink = null;
    }


    private EventChannel m_EventChannel;
    private void register(BinaryMessenger messenger, android.content.Context context) {
        m_Messenger = messenger;
        m_Context = context;
        m_Manager = (UsbManager) m_Context.getSystemService(android.content.Context.USB_SERVICE);
        m_InterfaceId = 100;
        m_EventChannel = new EventChannel(messenger, "usb_serial/usb_events");
        m_EventChannel.setStreamHandler(this);

        IntentFilter filter = new IntentFilter();
        filter.addAction(ACTION_USB_DETACHED);
        filter.addAction(ACTION_USB_ATTACHED);
        m_Context.registerReceiver(usbReceiver, filter);
    }

    private void unregister() {
        m_Context.unregisterReceiver(usbReceiver);
        m_EventChannel.setStreamHandler(null);
        m_Manager = null;
        m_Context = null;
        m_Messenger = null;
    }


    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private MethodChannel m_Channel;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        register(flutterPluginBinding.getBinaryMessenger(), flutterPluginBinding.getApplicationContext());
        m_Channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "usb_serial");
        m_Channel.setMethodCallHandler(this);

    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        m_Channel.setMethodCallHandler(null);
        unregister();
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {

        switch (call.method) {

            case "create": {
                String type = call.argument("type");
                Integer vid = call.argument("vid");
                Integer pid = call.argument("pid");
                Integer deviceId = call.argument("deviceId");
                Integer interfaceId = call.argument("interface");
                if (type!=null && vid!=null && pid !=null && deviceId != null && interfaceId != null ) {
                    createTyped(type,vid,pid,deviceId, interfaceId, result);
                }
                break;
            }
            case "listDevices":
                listDevices(result);
                break;

            default:
                result.notImplemented();
                break;
            }

    }

}

