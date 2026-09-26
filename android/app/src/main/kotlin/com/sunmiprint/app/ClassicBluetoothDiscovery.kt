package com.sunmiprint.app

import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class ClassicBluetoothDiscovery(
    private val activity: Activity,
    private val methodChannel: MethodChannel,
    private val eventChannel: EventChannel
) : EventChannel.StreamHandler {

    private val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private var discoveryReceiver: BroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null
    private var isDiscovering = false

    init {
        eventChannel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    @SuppressLint("MissingPermission")
    fun startDiscovery(result: MethodChannel.Result) {
        if (bluetoothAdapter == null) {
            result.error("NO_BLUETOOTH", "Bluetooth not supported on this device", null)
            return
        }

        if (!bluetoothAdapter.isEnabled) {
            result.error("BLUETOOTH_OFF", "Bluetooth is turned off", null)
            return
        }

        if (!hasRequiredPermissions()) {
            result.error("PERMISSION_DENIED", "Bluetooth permissions not granted", null)
            return
        }

        // Cancel any ongoing discovery first
        if (bluetoothAdapter.isDiscovering) {
            bluetoothAdapter.cancelDiscovery()
        }

        // Get already paired devices
        val pairedDevices = bluetoothAdapter.bondedDevices?.map { device ->
            mapOf(
                "name" to (device.name ?: "Unknown"),
                "address" to device.address,
                "type" to deviceTypeToString(device.type),
                "bondState" to bondStateToString(device.bondState),
                "isPaired" to true
            )
        } ?: emptyList()

        // Send paired devices first
        eventSink?.success(mapOf(
            "event" to "paired",
            "devices" to pairedDevices
        ))

        // Register receiver for discovery
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_STARTED)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        }

        discoveryReceiver = object : BroadcastReceiver() {
            @SuppressLint("MissingPermission")
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    BluetoothAdapter.ACTION_DISCOVERY_STARTED -> {
                        isDiscovering = true
                        eventSink?.success(mapOf("event" to "discoveryStarted"))
                    }
                    BluetoothDevice.ACTION_FOUND -> {
                        val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                        }
                        device?.let {
                            val deviceInfo = mapOf(
                                "name" to (it.name ?: "Unknown"),
                                "address" to it.address,
                                "type" to deviceTypeToString(it.type),
                                "bondState" to bondStateToString(it.bondState),
                                "isPaired" to false
                            )
                            eventSink?.success(mapOf(
                                "event" to "deviceFound",
                                "device" to deviceInfo
                            ))
                        }
                    }
                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                        isDiscovering = false
                        eventSink?.success(mapOf("event" to "discoveryFinished"))
                        unregisterReceiver()
                    }
                    BluetoothDevice.ACTION_BOND_STATE_CHANGED -> {
                        val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                        }
                        val bondState = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.BOND_NONE)
                        device?.let {
                            eventSink?.success(mapOf(
                                "event" to "bondStateChanged",
                                "address" to it.address,
                                "bondState" to bondStateToString(bondState)
                            ))
                        }
                    }
                }
            }
        }

        activity.registerReceiver(discoveryReceiver, filter)

        // Start discovery
        val started = bluetoothAdapter.startDiscovery()
        if (started) {
            result.success(true)
        } else {
            unregisterReceiver()
            result.error("DISCOVERY_FAILED", "Failed to start Bluetooth discovery", null)
        }
    }

    @SuppressLint("MissingPermission")
    fun cancelDiscovery() {
        bluetoothAdapter?.cancelDiscovery()
        unregisterReceiver()
        isDiscovering = false
    }

    @SuppressLint("MissingPermission")
    fun getBondedDevices(result: MethodChannel.Result) {
        if (bluetoothAdapter == null) {
            result.error("NO_BLUETOOTH", "Bluetooth not supported", null)
            return
        }

        if (!bluetoothAdapter.isEnabled) {
            result.error("BLUETOOTH_OFF", "Bluetooth is turned off", null)
            return
        }

        if (!hasRequiredPermissions()) {
            result.error("PERMISSION_DENIED", "Bluetooth permissions not granted", null)
            return
        }

        val devices = bluetoothAdapter.bondedDevices?.map { device ->
            mapOf(
                "name" to (device.name ?: "Unknown"),
                "address" to device.address,
                "type" to deviceTypeToString(device.type),
                "bondState" to bondStateToString(device.bondState),
                "isPaired" to true
            )
        } ?: emptyList()

        result.success(devices)
    }

    @SuppressLint("MissingPermission")
    fun createBond(address: String, result: MethodChannel.Result) {
        if (bluetoothAdapter == null) {
            result.error("NO_BLUETOOTH", "Bluetooth not supported", null)
            return
        }

        if (!bluetoothAdapter.isEnabled) {
            result.error("BLUETOOTH_OFF", "Bluetooth is turned off", null)
            return
        }

        if (!hasRequiredPermissions()) {
            result.error("PERMISSION_DENIED", "Bluetooth permissions not granted", null)
            return
        }

        val device = bluetoothAdapter.getRemoteDevice(address)
        if (device == null) {
            result.error("DEVICE_NOT_FOUND", "Device not found", null)
            return
        }

        // Already bonded
        if (device.bondState == BluetoothDevice.BOND_BONDED) {
            result.success(true)
            return
        }

        // Listen for bond state changes
        val bondReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == BluetoothDevice.ACTION_BOND_STATE_CHANGED) {
                    val extraDevice = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                    }
                    val bondState = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.BOND_NONE)

                    if (extraDevice?.address == address) {
                        when (bondState) {
                            BluetoothDevice.BOND_BONDED -> {
                                try { activity.unregisterReceiver(this) } catch (_: Exception) {}
                                eventSink?.success(mapOf(
                                    "event" to "bondStateChanged",
                                    "address" to address,
                                    "bondState" to "bonded"
                                ))
                                result.success(true)
                            }
                            BluetoothDevice.BOND_NONE -> {
                                // Bonding failed or was rejected
                                try { activity.unregisterReceiver(this) } catch (_: Exception) {}
                                eventSink?.success(mapOf(
                                    "event" to "bondStateChanged",
                                    "address" to address,
                                    "bondState" to "none"
                                ))
                                result.error("BOND_FAILED", "Pairing failed or was rejected", null)
                            }
                        }
                    }
                }
            }
        }

        val filter = IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        activity.registerReceiver(bondReceiver, filter)

        // Auto-unregister after 30s timeout
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            try { activity.unregisterReceiver(bondReceiver) } catch (_: Exception) {}
        }, 30000)

        // Trigger pairing - this shows the system pairing dialog
        val bonded = device.createBond()
        if (!bonded) {
            try { activity.unregisterReceiver(bondReceiver) } catch (_: Exception) {}
            result.error("BOND_FAILED", "Could not initiate pairing", null)
        }
    }

    @SuppressLint("MissingPermission")
    fun isBluetoothEnabled(): Boolean {
        return bluetoothAdapter?.isEnabled == true
    }

    @SuppressLint("MissingPermission")
    private fun hasRequiredPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+
            activity.checkSelfPermission(android.Manifest.permission.BLUETOOTH_SCAN) ==
                    android.content.pm.PackageManager.PERMISSION_GRANTED &&
            activity.checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) ==
                    android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            // Android 11 and below
            activity.checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) ==
                    android.content.pm.PackageManager.PERMISSION_GRANTED
        }
    }

    private fun unregisterReceiver() {
        try {
            discoveryReceiver?.let {
                activity.unregisterReceiver(it)
                discoveryReceiver = null
            }
        } catch (e: Exception) {
            // Receiver already unregistered
        }
    }

    private fun deviceTypeToString(type: Int): String {
        return when (type) {
            BluetoothDevice.DEVICE_TYPE_CLASSIC -> "classic"
            BluetoothDevice.DEVICE_TYPE_LE -> "ble"
            BluetoothDevice.DEVICE_TYPE_DUAL -> "dual"
            else -> "unknown"
        }
    }

    private fun bondStateToString(state: Int): String {
        return when (state) {
            BluetoothDevice.BOND_NONE -> "none"
            BluetoothDevice.BOND_BONDING -> "bonding"
            BluetoothDevice.BOND_BONDED -> "bonded"
            else -> "unknown"
        }
    }

    fun dispose() {
        cancelDiscovery()
    }
}
