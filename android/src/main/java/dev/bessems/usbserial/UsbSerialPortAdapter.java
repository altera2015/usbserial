package dev.bessems.usbserial;

import android.hardware.usb.UsbDeviceConnection;
import android.util.Log;
import android.os.Handler;
import android.os.Looper;

import dev.bessems.usbserial.vendored.driver.UsbSerialPort;
import dev.bessems.usbserial.vendored.util.SerialInputOutputManager;
import dev.bessems.usbserial.vendored.util.XonXoffFilter;

import java.io.IOException;
import java.util.EnumSet;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.BinaryMessenger;

/**
 * One open serial port, driven by the vendored usb-serial-for-android (mik3y).
 * The method channel API is unchanged: open, close, write, setPortParameters, setFlowControl,
 * setDTR, setRTS, and the input stream on "<channel>/stream".
 *
 * Settings made before open() (port parameters, DTR, RTS, flow control) are kept and applied
 * when the port opens, as felHR allowed them in any order.
 */
public class UsbSerialPortAdapter implements MethodCallHandler, EventChannel.StreamHandler {

    private final String TAG = UsbSerialPortAdapter.class.getSimpleName();
    // Writes block until the data is sent, so the timeout scales with the
    // transfer time at the current baud rate (10 bits per byte for 8N1),
    // doubled for headroom, plus this fixed allowance.
    private static final int WRITE_TIMEOUT_BASE_MS = 2000;

    private final UsbDeviceConnection m_Connection;
    private final UsbSerialPort m_Port;
    private final String m_MethodChannelName;
    private final Handler m_handler;
    private EventChannel.EventSink m_EventSink;
    private SerialInputOutputManager m_IoManager;
    // Writes run off the platform (main) thread so slow ports can't freeze the UI.
    private ExecutorService m_WriteExecutor;
    // Set when XON/XOFF is emulated with inline characters (e.g. FTDI); they
    // must be stripped from the received data.
    private volatile XonXoffFilter m_XonXoffFilter;
    private volatile boolean m_Closing = false;

    // remembered settings (applied on open, re-applied when changed while open)
    private int m_BaudRate = 115200;
    private int m_DataBits = UsbSerialPort.DATABITS_8;
    private int m_StopBits = UsbSerialPort.STOPBITS_1;
    private int m_Parity = UsbSerialPort.PARITY_NONE;
    private boolean m_ParamsSet = false;
    private Boolean m_Dtr = null;
    private Boolean m_Rts = null;
    private int m_FlowControl = 0;

    UsbSerialPortAdapter(BinaryMessenger messenger, int interfaceId, UsbDeviceConnection connection, UsbSerialPort port) {
        m_Connection = connection;
        m_Port = port;
        m_MethodChannelName = "usb_serial/UsbSerialPortAdapter/" + String.valueOf(interfaceId);
        m_handler = new Handler(Looper.getMainLooper());
        final MethodChannel channel = new MethodChannel(messenger, m_MethodChannelName);
        channel.setMethodCallHandler(this);
        final EventChannel eventChannel = new EventChannel(messenger, m_MethodChannelName + "/stream");
        eventChannel.setStreamHandler(this);
    }

    String getMethodChannelName() {
        return m_MethodChannelName;
    }

    private final SerialInputOutputManager.Listener m_Listener = new SerialInputOutputManager.Listener() {
        @Override
        public void onNewData(byte[] received) {
            XonXoffFilter filter = m_XonXoffFilter;
            final byte[] data = filter != null ? filter.filter(received) : received;
            if (data.length == 0) {
                return;
            }
            if (!m_Closing && m_EventSink != null) {
                m_handler.post(new Runnable() {
                    @Override
                    public void run() {
                        if (m_EventSink != null) {
                            m_EventSink.success(data);
                        }
                    }
                });
            }
        }

        @Override
        public void onRunError(Exception e) {
            // the device was unplugged or the port closed: end the Dart stream (onDone)
            Log.d(TAG, "read stopped: " + e);
            if (m_Closing) {
                return; // closed on purpose: no end-of-stream
            }
            m_handler.post(new Runnable() {
                @Override
                public void run() {
                    if (m_EventSink != null) {
                        m_EventSink.endOfStream();
                        m_EventSink = null;
                    }
                }
            });
        }
    };

    private void applySettings() throws IOException {
        if (m_ParamsSet) {
            m_Port.setParameters(m_BaudRate, m_DataBits, m_StopBits, m_Parity);
        }
        if (m_Dtr != null) {
            m_Port.setDTR(m_Dtr);
        }
        if (m_Rts != null) {
            m_Port.setRTS(m_Rts);
        }
        applyFlowControl();
    }

    private void applyFlowControl() {
        UsbSerialPort.FlowControl fc;
        switch (m_FlowControl) {
            case 1:
                fc = UsbSerialPort.FlowControl.RTS_CTS;
                break;
            case 2:
                fc = UsbSerialPort.FlowControl.DTR_DSR;
                break;
            case 3:
                fc = UsbSerialPort.FlowControl.XON_XOFF;
                break;
            default:
                fc = UsbSerialPort.FlowControl.NONE;
        }
        try {
            EnumSet<UsbSerialPort.FlowControl> supported = m_Port.getSupportedFlowControl();
            if (fc == UsbSerialPort.FlowControl.XON_XOFF
                    && !supported.contains(fc)
                    && supported.contains(UsbSerialPort.FlowControl.XON_XOFF_INLINE)) {
                // e.g. FTDI: the chip honours XON/XOFF but passes the
                // characters through, so filter them out of the input.
                fc = UsbSerialPort.FlowControl.XON_XOFF_INLINE;
            }
            if (supported.contains(fc)) {
                m_Port.setFlowControl(fc);
                m_XonXoffFilter = fc == UsbSerialPort.FlowControl.XON_XOFF_INLINE ? new XonXoffFilter() : null;
            } else if (fc != UsbSerialPort.FlowControl.NONE) {
                Log.w(TAG, "flow control " + fc + " not supported by " + m_Port.getDriver().getClass().getSimpleName());
            }
        } catch (Exception e) {
            Log.w(TAG, "setFlowControl failed: " + e);
        }
    }

    private Boolean open() {
        if (m_Port.isOpen()) {
            return true;
        }
        try {
            m_Closing = false;
            m_Port.open(m_Connection);
            applySettings();
            m_IoManager = new SerialInputOutputManager(m_Port, m_Listener);
            m_IoManager.start();
            m_WriteExecutor = Executors.newSingleThreadExecutor();
            return true;
        } catch (Exception e) {
            Log.e(TAG, "open failed: " + e);
            try {
                m_Port.close();
            } catch (Exception ignored) {
            }
            return false;
        }
    }

    private Boolean close() {
        m_Closing = true;
        if (m_IoManager != null) {
            m_IoManager.stop();
            m_IoManager = null;
        }
        if (m_WriteExecutor != null) {
            m_WriteExecutor.shutdown();
            m_WriteExecutor = null;
        }
        m_XonXoffFilter = null;
        try {
            if (m_Port.isOpen()) {
                m_Port.close();
            }
        } catch (Exception e) {
            Log.w(TAG, "close: " + e);
        }
        return true;
    }

    private int writeTimeoutMs(int length) {
        long transferMs = (long) length * 10 * 1000 / Math.max(m_BaudRate, 1);
        return (int) Math.min(Integer.MAX_VALUE, WRITE_TIMEOUT_BASE_MS + 2 * transferMs);
    }

    private void write(final byte[] data, final Result result) {
        final ExecutorService executor = m_WriteExecutor;
        if (data == null || executor == null || !m_Port.isOpen()) {
            result.success(true);
            return;
        }
        final int timeout = writeTimeoutMs(data.length);
        executor.execute(() -> {
            try {
                m_Port.write(data, timeout);
                m_handler.post(() -> result.success(true));
            } catch (final Exception e) {
                Log.e(TAG, "write failed: " + e);
                m_handler.post(() -> result.error(TAG, "write failed: " + e.getMessage(), null));
            }
        });
    }

    public void onMethodCall(MethodCall call, Result result) {
        try {
            switch (call.method) {
                case "close":
                    result.success(close());
                    break;
                case "open":
                    result.success(open());
                    break;
                case "write":
                    write((byte[]) call.argument("data"), result);
                    break;
                case "setPortParameters":
                    m_BaudRate = (int) call.argument("baudRate");
                    m_DataBits = (int) call.argument("dataBits");
                    m_StopBits = (int) call.argument("stopBits");
                    m_Parity = (int) call.argument("parity");
                    m_ParamsSet = true;
                    if (m_Port.isOpen()) {
                        m_Port.setParameters(m_BaudRate, m_DataBits, m_StopBits, m_Parity);
                    }
                    result.success(null);
                    break;
                case "setFlowControl":
                    m_FlowControl = (int) call.argument("flowControl");
                    if (m_Port.isOpen()) {
                        applyFlowControl();
                    }
                    result.success(null);
                    break;
                case "setDTR": {
                    boolean v = call.argument("value");
                    m_Dtr = v;
                    if (m_Port.isOpen()) {
                        m_Port.setDTR(v);
                    }
                    result.success(null);
                    break;
                }
                case "setRTS": {
                    boolean v = call.argument("value");
                    m_Rts = v;
                    if (m_Port.isOpen()) {
                        m_Port.setRTS(v);
                    }
                    result.success(null);
                    break;
                }
                default:
                    result.notImplemented();
            }
        } catch (Exception e) {
            // never crash the app on a serial error: report it to Dart
            Log.e(TAG, call.method + " failed: " + e);
            result.error(TAG, call.method + " failed: " + e.getMessage(), null);
        }
    }

    @Override
    public void onListen(Object o, EventChannel.EventSink eventSink) {
        m_EventSink = eventSink;
    }

    @Override
    public void onCancel(Object o) {
        m_EventSink = null;
    }
}
