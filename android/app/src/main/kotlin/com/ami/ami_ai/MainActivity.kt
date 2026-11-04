package com.ami.ami_ai

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "ami/screen"
        private const val OVERLAY_CHANNEL = "ami/overlay"
        private const val ACCESSIBILITY_CHANNEL = "ami/accessibility"
        private const val ACCESSIBILITY_STREAM_CHANNEL = "ami/accessibility_stream"
        private const val DEVICE_ACTIONS_CHANNEL = "ami/device_actions"
        private const val REQUEST_PROJECTION = 7101
        private const val REQUEST_NOTIFICATIONS = 7102
        private const val REQUEST_ACTION_NOTIFICATIONS = 7103
        const val EXTRA_ORB_ACTION = "ami_orb_action"
        const val ORB_ACTION_READ_SCREEN = "read_screen"
    }

    private var screenChannel: MethodChannel? = null
    private var overlayChannel: MethodChannel? = null
    private var accessibilityChannel: MethodChannel? = null
    private var pendingCaptureResult: MethodChannel.Result? = null
    private var pendingReminderResult: MethodChannel.Result? = null
    private var pendingReminder: Triple<String, String, Long>? = null
    private var pendingOrbAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingOrbAction = intent?.getStringExtra(EXTRA_ORB_ACTION)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = intent.getStringExtra(EXTRA_ORB_ACTION) ?: return
        val channel = overlayChannel
        if (channel != null) {
            pendingOrbAction = null
            channel.invokeMethod("orbTap", null)
        } else {
            pendingOrbAction = action
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        screenChannel = channel

        ScreenCaptureService.stateListener = { active ->
            runOnUiThread {
                screenChannel?.invokeMethod("screenState", active)
            }
        }
        ScreenCaptureService.captureListener = {
            runOnUiThread {
                screenChannel?.invokeMethod("captureReady", null)
            }
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestScreenCapture" -> requestScreenCapture(result)
                "stopScreenCapture" -> {
                    pendingCaptureResult = null
                    ScreenCaptureService.stop(this)
                    result.success(true)
                }
                "captureScreen" -> captureScreen(result)
                "captureScreenAfter" -> {
                    val delay = (call.argument<Number>("delayMs") ?: 5000).toLong()
                    val service = ScreenCaptureService.instance
                    if (service == null) {
                        result.success(false)
                    } else {
                        service.captureFrameAfter(delay)
                        result.success(true)
                    }
                }
                "takePendingCapture" -> {
                    val bytes = ScreenCaptureService.instance?.takePendingCapture()
                    result.success(bytes)
                }
                "isScreenCapturing" -> result.success(ScreenCaptureService.isRunning)
                else -> result.notImplemented()
            }
        }

        setupOverlayChannel(flutterEngine)
        setupAccessibilityChannel(flutterEngine)
        setupDeviceActionsChannel(flutterEngine)
    }

    private fun setupDeviceActionsChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_ACTIONS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchApp" -> {
                    val appName = call.argument<String>("appName").orEmpty().trim()
                    result.success(launchInstalledApp(appName))
                }
                "openSettingsPage" -> {
                    val page = call.argument<String>("page").orEmpty()
                    result.success(openSettingsPage(page))
                }
                "scheduleReminder" -> {
                    val id = call.argument<String>("id").orEmpty()
                    val title = call.argument<String>("title").orEmpty().trim()
                    val triggerAt = call.argument<Number>("triggerAtMillis")?.toLong()
                    if (id.isEmpty() || title.isEmpty() || triggerAt == null ||
                        triggerAt <= System.currentTimeMillis()
                    ) {
                        result.success(false)
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                        PackageManager.PERMISSION_GRANTED
                    ) {
                        if (pendingReminderResult != null) {
                            result.success(false)
                        } else {
                            pendingReminderResult = result
                            pendingReminder = Triple(id, title, triggerAt)
                            requestPermissions(
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                REQUEST_ACTION_NOTIFICATIONS
                            )
                        }
                    } else {
                        DeviceReminderScheduler.schedule(this, id, title, triggerAt)
                        result.success(true)
                    }
                }
                "cancelReminder" -> {
                    val id = call.argument<String>("id").orEmpty()
                    DeviceReminderScheduler.cancel(this, id)
                    result.success(id.isNotEmpty())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchInstalledApp(requestedName: String): Boolean {
        if (requestedName.isEmpty()) return false
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val matches = packageManager.queryIntentActivities(launcherIntent, 0).filter {
            it.loadLabel(packageManager).toString().trim().equals(requestedName, ignoreCase = true)
        }
        if (matches.size != 1) return false
        val matchingPackages = matches.map { it.activityInfo.packageName }.distinct()
        if (matchingPackages.size != 1) return false
        val packageName = matchingPackages.single()
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
        return try {
            startActivity(launchIntent)
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun openSettingsPage(page: String): Boolean {
        val action = when (page) {
            "wifi" -> Settings.ACTION_WIFI_SETTINGS
            "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
            "display" -> Settings.ACTION_DISPLAY_SETTINGS
            "sound" -> Settings.ACTION_SOUND_SETTINGS
            "location" -> Settings.ACTION_LOCATION_SOURCE_SETTINGS
            "notifications" -> Settings.ACTION_APP_NOTIFICATION_SETTINGS
            "apps" -> Settings.ACTION_APPLICATION_SETTINGS
            "battery" -> Settings.ACTION_BATTERY_SAVER_SETTINGS
            "accessibility" -> Settings.ACTION_ACCESSIBILITY_SETTINGS
            "language" -> Settings.ACTION_LOCALE_SETTINGS
            else -> return false
        }
        return try {
            val intent = Intent(action)
            if (page == "notifications") {
                intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
            startActivity(intent)
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun setupAccessibilityChannel(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACCESSIBILITY_CHANNEL
        )
        accessibilityChannel = channel

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACCESSIBILITY_STREAM_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val service = AmiAccessibilityService.instance
                if (service == null) {
                    events.error(
                        "accessibility_unavailable",
                        "Enable AMI screen interaction in Android Accessibility settings.",
                        null
                    )
                    return
                }
                AmiAccessibilityService.streamSink = events
                service.streamCurrentScreen()
            }

            override fun onCancel(arguments: Any?) {
                AmiAccessibilityService.streamSink = null
            }
        })

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isEnabled" -> result.success(isAmiAccessibilityEnabled())
                "isConnected" ->
                    result.success(AmiAccessibilityService.instance != null)
                "openSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(true)
                    } catch (error: Throwable) {
                        result.error("accessibility_settings", error.message, null)
                    }
                }
                "getScreenNodes" -> {
                    val service = AmiAccessibilityService.instance
                    if (service == null) {
                        result.error(
                            "accessibility_unavailable",
                            "Enable AMI screen interaction in Android Accessibility settings.",
                            null
                        )
                    } else {
                        result.success(service.getScreenNodes())
                    }
                }
                "tapAt" -> {
                    val x = call.argument<Number>("x")?.toFloat()
                    val y = call.argument<Number>("y")?.toFloat()
                    val service = AmiAccessibilityService.instance
                    if (service == null || x == null || y == null) {
                        result.error(
                            "accessibility_unavailable",
                            "Screen interaction is not available.",
                            null
                        )
                    } else {
                        service.tapAt(x, y) { success -> result.success(success) }
                    }
                }
                "typeText" -> {
                    val text = call.argument<String>("text")
                    val service = AmiAccessibilityService.instance
                    if (service == null || text == null) {
                        result.error(
                            "accessibility_unavailable",
                            "Screen interaction is not available.",
                            null
                        )
                    } else {
                        result.success(service.typeText(text))
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAmiAccessibilityEnabled(): Boolean {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ).orEmpty()
        val serviceName = ComponentName(
            this,
            AmiAccessibilityService::class.java
        ).flattenToString()
        return enabledServices
            .split(':')
            .any { it.equals(serviceName, ignoreCase = true) }
    }

    private fun setupOverlayChannel(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
        overlayChannel = channel

        FloatingOrbService.tapListener = {
            runOnUiThread {
                overlayChannel?.invokeMethod("orbTap", null)
            }
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isOverlayPermissionGranted" ->
                    result.success(Settings.canDrawOverlays(this))
                "requestOverlayPermission" -> {
                    if (Settings.canDrawOverlays(this)) {
                        result.success(true)
                    } else {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")
                                )
                            )
                            result.success(false)
                        } catch (error: Throwable) {
                            result.error("overlay_settings", error.message, null)
                        }
                    }
                }
                "startOverlay" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        result.success(false)
                    } else {
                        FloatingOrbService.start(this)
                        result.success(true)
                    }
                }
                "stopOverlay" -> {
                    FloatingOrbService.stop(this)
                    result.success(true)
                }
                "isOverlayRunning" -> result.success(FloatingOrbService.isRunning)
                "takeOrbAction" -> {
                    val action = pendingOrbAction
                    pendingOrbAction = null
                    result.success(action)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestScreenCapture(result: MethodChannel.Result) {
        if (ScreenCaptureService.isRunning) {
            result.success(true)
            return
        }
        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        pendingCaptureResult = result
        try {
            startActivityForResult(manager.createScreenCaptureIntent(), REQUEST_PROJECTION)
        } catch (error: Throwable) {
            pendingCaptureResult = null
            result.error("projection_unavailable", error.message, null)
        }
    }

    private fun captureScreen(result: MethodChannel.Result) {
        val service = ScreenCaptureService.instance
        if (service == null) {
            result.success(null)
            return
        }
        service.captureFrame { bytes ->
            runOnUiThread { result.success(bytes) }
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATIONS
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_ACTION_NOTIFICATIONS) return

        val result = pendingReminderResult
        val reminder = pendingReminder
        pendingReminderResult = null
        pendingReminder = null
        if (result == null || reminder == null) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            DeviceReminderScheduler.schedule(
                this,
                reminder.first,
                reminder.second,
                reminder.third
            )
            result.success(true)
        } else {
            result.success(false)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_PROJECTION) {
            val result = pendingCaptureResult
            pendingCaptureResult = null
            if (resultCode == Activity.RESULT_OK && data != null) {
                ScreenCaptureService.start(applicationContext, resultCode, data)
                requestNotificationPermission()
                result?.success(true)
            } else {
                result?.success(false)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        if (ScreenCaptureService.stateListener != null) {
            ScreenCaptureService.stateListener = null
        }
        if (ScreenCaptureService.captureListener != null) {
            ScreenCaptureService.captureListener = null
        }
        if (FloatingOrbService.tapListener != null) {
            FloatingOrbService.tapListener = null
        }
        screenChannel = null
        overlayChannel = null
        accessibilityChannel = null
        super.onDestroy()
    }
}
