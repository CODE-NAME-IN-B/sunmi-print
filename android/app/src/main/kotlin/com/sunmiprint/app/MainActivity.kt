package com.sunmiprint.app

import android.bluetooth.BluetoothAdapter
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.sunmiprint.app/bluetooth"
    private val EVENT_CHANNEL = "com.sunmiprint.app/bluetooth/events"

    private var classicDiscovery: ClassicBluetoothDiscovery? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        val eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)

        classicDiscovery = ClassicBluetoothDiscovery(this, methodChannel, eventChannel)

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isBluetoothEnabled" -> {
                    result.success(classicDiscovery?.isBluetoothEnabled() ?: false)
                }

                "enableBluetooth" -> {
                    val intent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                    startActivity(intent)
                    result.success(true)
                }

                "openBluetoothSettings" -> {
                    val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }

                "startDiscovery" -> {
                    classicDiscovery?.startDiscovery(result)
                }

                "cancelDiscovery" -> {
                    classicDiscovery?.cancelDiscovery()
                    result.success(true)
                }

                "getBondedDevices" -> {
                    classicDiscovery?.getBondedDevices(result)
                }

                "pairDevice" -> {
                    val address = call.argument<String>("address")
                    if (address != null) {
                        classicDiscovery?.createBond(address, result)
                    } else {
                        result.error("INVALID_ARGS", "Device address required", null)
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        classicDiscovery?.dispose()
        super.onDestroy()
    }
}
