// Copyright 2026 Rosnect contributors.
// SPDX-License-Identifier: Apache-2.0

package com.rosnect.rosnect

import android.Manifest
import android.content.*
import android.content.pm.PackageManager
import android.hardware.*
import android.hardware.camera2.*
import android.location.*
import android.media.*
import android.os.*
import android.util.Size
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.*

/** Foreground hardware capture. All events carry acquisition time, never dummy values. */
class MainActivity : FlutterActivity(), SensorEventListener, LocationListener {
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private lateinit var sensors: SensorManager
    private val active = mutableSetOf<String>()
    private val last = mutableMapOf<String, Long>()
    private val types = mapOf("accelerometer" to Sensor.TYPE_ACCELEROMETER,
        "gyroscope" to Sensor.TYPE_GYROSCOPE, "magnetometer" to Sensor.TYPE_MAGNETIC_FIELD,
        "light" to Sensor.TYPE_LIGHT, "barometer" to Sensor.TYPE_PRESSURE)
    private var permissionResult: MethodChannel.Result? = null
    private var permissionKind: String? = null
    private var camera: CameraDevice? = null
    private var cameraSession: CameraCaptureSession? = null
    private var reader: ImageReader? = null
    private var cameraGeneration = 0
    private var recorder: AudioRecord? = null
    private var audioThread: Thread? = null
    @Volatile private var microphoneGeneration = 0
    private var batteryReceiver: BroadcastReceiver? = null
    private var frontCamera = false
    private var cameraInterval = 500L

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        sensors = getSystemService(SENSOR_SERVICE) as SensorManager
        MethodChannel(engine.dartExecutor.binaryMessenger, "rosnect/preferences").setMethodCallHandler { call, result ->
            val preferences = getSharedPreferences("rosnect_appearance", MODE_PRIVATE)
            when (call.method) {
                "getTheme" -> result.success(preferences.getString("theme", "system"))
                "setTheme" -> {
                    val mode = call.arguments as? String
                    if (mode == "dark" || mode == "light") {
                        preferences.edit().putString("theme", mode).apply()
                        result.success(null)
                    } else result.error("invalid_theme", "Expected dark or light", null)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(engine.dartExecutor.binaryMessenger, "rosnect/sensor_events").setStreamHandler(object: EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) { sink = events }
            override fun onCancel(arguments: Any?) { stopAll(); sink = null }
        })
        MethodChannel(engine.dartExecutor.binaryMessenger, "rosnect/sensors").setMethodCallHandler { call, result ->
            when (call.method) {
                "capabilities" -> {
                    val caps = types.mapValues { sensors.getDefaultSensor(it.value) != null }.toMutableMap()
                    caps["camera"] = (getSystemService(CAMERA_SERVICE) as CameraManager).cameraIdList.isNotEmpty()
                    caps["location"] = packageManager.hasSystemFeature(PackageManager.FEATURE_LOCATION)
                    caps["microphone"] = packageManager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE)
                    caps["battery"] = true; caps["touch"] = true
                    result.success(caps)
                }
                "start" -> {
                    val kind = call.argument<String>("kind") ?: ""
                    frontCamera = call.argument<Boolean>("front") ?: false
                    cameraInterval = (1000 / (call.argument<Int>("fps") ?: 2).coerceIn(1, 5)).toLong()
                    requestStart(kind, result)
                }
                "stop" -> { stop(call.argument<String>("kind") ?: ""); result.success(null) }
                "stopAll" -> { stopAll(); result.success(null) }
                "settings" -> {
                    startActivity(Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        android.net.Uri.parse("package:$packageName")))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun emit(kind: String, value: Any, timestamp: Long = System.currentTimeMillis()) {
        main.post { if (active.contains(kind)) sink?.success(mapOf("kind" to kind, "value" to value, "timestamp_unix_ms" to timestamp)) }
    }
    private fun failure(kind: String, error: String) {
        main.post { android.util.Log.w("RosnectSensors", "$kind: $error"); stop(kind); sink?.success(mapOf("kind" to kind, "error" to error)) }
    }
    private fun requestStart(kind: String, result: MethodChannel.Result) {
        val permissions = when(kind) {
            "camera" -> arrayOf(Manifest.permission.CAMERA)
            "microphone" -> arrayOf(Manifest.permission.RECORD_AUDIO)
            "location" -> arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
            else -> emptyArray()
        }
        if (permissions.isNotEmpty() && permissions.none { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }) {
            if (permissionResult != null) { result.error("busy", "Finish the current permission request first.", null); return }
            permissionResult = result; permissionKind = kind
            requestPermissions(permissions, 81)
        } else start(kind, result)
    }
    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, grants: IntArray) {
        super.onRequestPermissionsResult(code, permissions, grants)
        if (code != 81) return
        val result = permissionResult ?: return
        val kind = permissionKind ?: return
        permissionResult = null; permissionKind = null
        if (grants.any { it == PackageManager.PERMISSION_GRANTED }) start(kind, result)
        else result.error("permission_denied", "Permission denied. Enable $kind in Android Settings → Apps → Rosnect → Permissions.", null)
    }
    @Suppress("MissingPermission")
    private fun start(kind: String, result: MethodChannel.Result) {
        try {
            stop(kind); active.add(kind)
            when {
                types.containsKey(kind) -> {
                    val sensor = sensors.getDefaultSensor(types.getValue(kind)) ?: error("Sensor unavailable on this phone")
                    if (!sensors.registerListener(this, sensor, 100000)) error("Could not start sensor")
                }
                kind == "location" -> {
                    val manager = getSystemService(LOCATION_SERVICE) as LocationManager
                    val precise = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
                        .filter { manager.isProviderEnabled(it) && (precise || it != LocationManager.GPS_PROVIDER) }
                    if (providers.isEmpty()) error("Turn on Location in Android quick settings. Precise location enables GPS.")
                    providers.forEach { manager.requestLocationUpdates(it, 1000L, 0f, this, Looper.getMainLooper()) }
                }
                kind == "battery" -> {
                    batteryReceiver = object: BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            if (intent == null) return
                            val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
                            val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                            emit("battery", mapOf("percentage" to if (level < 0) -1.0 else level.toDouble() / scale.coerceAtLeast(1),
                                "voltage" to intent.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0) / 1000.0,
                                "temperature" to intent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) / 10.0,
                                "power_supply_status" to when(intent.getIntExtra(BatteryManager.EXTRA_STATUS, 0)) {
                                    BatteryManager.BATTERY_STATUS_CHARGING -> 1
                                    BatteryManager.BATTERY_STATUS_DISCHARGING -> 2
                                    BatteryManager.BATTERY_STATUS_NOT_CHARGING -> 3
                                    BatteryManager.BATTERY_STATUS_FULL -> 4
                                    else -> 0
                                }))
                        }
                    }
                    registerReceiver(batteryReceiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                }
                kind == "camera" -> startCamera()
                kind == "microphone" -> startMicrophone()
                kind != "touch" -> error("Unknown sensor")
            }
            android.util.Log.i("RosnectSensors", "Started $kind")
            result.success(null)
        } catch (e: Exception) { stop(kind); result.error("capture_error", e.message, null) }
    }
    override fun onSensorChanged(event: SensorEvent) {
        val kind = types.entries.firstOrNull { it.value == event.sensor.type }?.key ?: return
        if (!active.contains(kind)) return
        val now = SystemClock.elapsedRealtime()
        if (now - (last[kind] ?: 0) < 95) return
        last[kind] = now
        val timestamp = System.currentTimeMillis() - (SystemClock.elapsedRealtimeNanos() - event.timestamp) / 1000000
        emit(kind, event.values.map { it.toDouble() }, timestamp)
    }
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    override fun onLocationChanged(location: Location) {
        val value = mutableMapOf<String, Any>("latitude" to location.latitude, "longitude" to location.longitude,
            "accuracy" to location.accuracy.toDouble(), "provider" to (location.provider ?: ""))
        if (location.hasAltitude()) value["altitude"] = location.altitude
        if (location.hasSpeed()) value["speed"] = location.speed.toDouble()
        emit("location", value, location.time)
    }
    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) { if (active.contains("location")) failure("location", "Location provider disabled; enable Location and restart this sensor.") }
    @Deprecated("Legacy Android callback")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

    @Suppress("MissingPermission")
    private fun startMicrophone() {
        val size = max(2048, AudioRecord.getMinBufferSize(16000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT))
        val audio = AudioRecord(MediaRecorder.AudioSource.MIC, 16000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, size * 2)
        if (audio.state != AudioRecord.STATE_INITIALIZED) { audio.release(); error("Microphone could not initialize") }
        recorder = audio; audio.startRecording()
        val generation = ++microphoneGeneration
        audioThread = Thread {
            val buffer = ShortArray(size / 2)
            var previous = 0L
            while (generation == microphoneGeneration && !Thread.currentThread().isInterrupted) {
                val count = audio.read(buffer, 0, buffer.size)
                if (count <= 0) {
                    if (generation == microphoneGeneration) failure("microphone", "Microphone stopped or became unavailable")
                    break
                }
                val now = SystemClock.elapsedRealtime()
                if (now - previous < 100) continue
                previous = now
                var sum = 0.0
                for (i in 0 until count) sum += buffer[i].toDouble() * buffer[i]
                val rms = sqrt(sum / count) / 32768.0
                emit("microphone", mapOf("rms" to rms, "dbfs" to max(-120.0, 20 * log10(max(rms, 0.000001)))))
            }
        }.also { it.start() }
    }
    @Suppress("MissingPermission")
    private fun startCamera() {
        val manager = getSystemService(CAMERA_SERVICE) as CameraManager
        val id = manager.cameraIdList.firstOrNull {
            manager.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) ==
                if (frontCamera) CameraCharacteristics.LENS_FACING_FRONT else CameraCharacteristics.LENS_FACING_BACK
        } ?: error("Selected camera unavailable")
        val characteristics = manager.getCameraCharacteristics(id)
        val sizes = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)!!.getOutputSizes(android.graphics.ImageFormat.JPEG)
        val size = sizes.filter { it.width <= 640 && it.height <= 640 }.maxByOrNull { it.width * it.height }
            ?: sizes.minByOrNull { it.width * it.height } ?: Size(640, 480)
        val generation = ++cameraGeneration
        val imageReader = ImageReader.newInstance(size.width, size.height, android.graphics.ImageFormat.JPEG, 2)
        reader = imageReader
        imageReader.setOnImageAvailableListener({ source ->
            val image = source.acquireLatestImage() ?: return@setOnImageAvailableListener
            try {
                val buffer = image.planes[0].buffer
                val bytes = ByteArray(buffer.remaining()); buffer.get(bytes)
                if (generation == cameraGeneration) {
                    if (bytes.size <= 256 * 1024) {
                        val realtime = characteristics.get(CameraCharacteristics.SENSOR_INFO_TIMESTAMP_SOURCE) == CameraCharacteristics.SENSOR_INFO_TIMESTAMP_SOURCE_REALTIME
                        val captureTime = if (realtime) System.currentTimeMillis() - (SystemClock.elapsedRealtimeNanos() - image.timestamp) / 1000000 else System.currentTimeMillis()
                        emit("camera", bytes, captureTime)
                    }
                    else failure("camera", "Camera JPEG exceeds 256 KB limit")
                }
            } finally { image.close() }
        }, main)
        manager.openCamera(id, object: CameraDevice.StateCallback() {
            override fun onOpened(device: CameraDevice) {
                if (generation != cameraGeneration) { device.close(); return }
                camera = device
                device.createCaptureSession(listOf(imageReader.surface), object: CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        if (generation != cameraGeneration) { session.close(); return }
                        cameraSession = session
                        val request = device.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE).apply {
                            addTarget(imageReader.surface)
                            set(CaptureRequest.JPEG_QUALITY, 55.toByte())
                            val rotation = (windowManager.defaultDisplay.rotation * 90)
                            val sensorRotation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
                            set(CaptureRequest.JPEG_ORIENTATION, (sensorRotation + if (frontCamera) rotation else -rotation + 360) % 360)
                            set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                        }.build()
                        lateinit var capture: Runnable
                        capture = object: Runnable {
                            override fun run() {
                                if (generation != cameraGeneration) return
                                try {
                                    session.capture(request, object: CameraCaptureSession.CaptureCallback() {
                                        override fun onCaptureFailed(s: CameraCaptureSession, r: CaptureRequest, captureFailure: CaptureFailure) {
                                            if (generation == cameraGeneration) failure("camera", "Camera frame capture failed")
                                        }
                                        override fun onCaptureCompleted(s: CameraCaptureSession, r: CaptureRequest, result: TotalCaptureResult) {
                                            if (generation == cameraGeneration) main.postDelayed(capture, cameraInterval)
                                        }
                                    }, main)
                                } catch (e: Exception) { failure("camera", e.message ?: "Camera capture failed") }
                            }
                        }
                        capture.run()
                    }
                    override fun onConfigureFailed(session: CameraCaptureSession) { failure("camera", "Camera session failed") }
                }, main)
            }
            override fun onDisconnected(device: CameraDevice) { device.close(); failure("camera", "Camera disconnected") }
            override fun onError(device: CameraDevice, code: Int) { device.close(); failure("camera", "Camera is unavailable or in use (error $code)") }
        }, main)
    }
    private fun stop(kind: String) {
        active.remove(kind); last.remove(kind)
        if (types.containsKey(kind)) sensors.getDefaultSensor(types.getValue(kind))?.let { sensors.unregisterListener(this, it) }
        when (kind) {
            "camera" -> { cameraGeneration++; cameraSession?.close(); cameraSession = null; camera?.close(); camera = null; reader?.close(); reader = null }
            "location" -> (getSystemService(LOCATION_SERVICE) as LocationManager).removeUpdates(this)
            "battery" -> { batteryReceiver?.let { unregisterReceiver(it) }; batteryReceiver = null }
            "microphone" -> {
                microphoneGeneration++
                val old = recorder; recorder = null
                try { old?.stop() } catch (_: Exception) {}
                audioThread?.interrupt(); audioThread?.join(300); audioThread = null
                old?.release()
            }
        }
    }
    private fun stopAll() { active.toList().forEach { stop(it) } }
    override fun onPause() { stopAll(); super.onPause() }
    override fun onDestroy() { stopAll(); super.onDestroy() }
}
