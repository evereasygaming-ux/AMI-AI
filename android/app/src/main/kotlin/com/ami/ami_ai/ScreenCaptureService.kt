package com.ami.ami_ai

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import kotlin.math.max
import kotlin.math.min

class ScreenCaptureService : Service() {

    companion object {
        private const val CHANNEL_ID = "ami_screen_capture"
        private const val NOTIFICATION_ID = 7812
        private const val EXTRA_RESULT_CODE = "result_code"
        private const val EXTRA_RESULT_DATA = "result_data"
        const val ACTION_STOP = "com.ami.ami_ai.STOP_SCREEN_CAPTURE"

        @Volatile
        var instance: ScreenCaptureService? = null
            private set

        @Volatile
        var isRunning: Boolean = false
            private set

        var stateListener: ((Boolean) -> Unit)? = null
        var captureListener: (() -> Unit)? = null

        fun start(context: Context, resultCode: Int, data: Intent) {
            val intent = Intent(context, ScreenCaptureService::class.java).apply {
                putExtra(EXTRA_RESULT_CODE, resultCode)
                putExtra(EXTRA_RESULT_DATA, data)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, ScreenCaptureService::class.java))
        }
    }

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var imageThread: HandlerThread? = null
    private var imageHandler: Handler? = null
    private var lastImage: Image? = null
    private var pendingCapture: ByteArray? = null
    private var density = 1

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        startForegroundNotification()

        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
        @Suppress("DEPRECATION")
        val resultData = intent.getParcelableExtra<Intent>(EXTRA_RESULT_DATA)
        if (resultCode != Activity.RESULT_OK || resultData == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (mediaProjection == null) {
            startCapture(resultCode, resultData)
        }
        return START_NOT_STICKY
    }

    private fun startForegroundNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Screen context",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows while AMI can read your screen"
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        val openIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val stopIntent = Intent(this, ScreenCaptureService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        @Suppress("DEPRECATION")
        val notification = builder
            .setContentTitle("AMI can see your screen")
            .setContentText("Screen context is on. Tap to open AMI.")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Stop",
                stopPendingIntent
            )
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun startCapture(resultCode: Int, resultData: Intent) {
        val projectionManager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val projection = try {
            projectionManager.getMediaProjection(resultCode, resultData)
        } catch (_: Throwable) {
            null
        }
        if (projection == null) {
            stopSelf()
            return
        }
        mediaProjection = projection

        val thread = HandlerThread("ami-screen-capture").also { it.start() }
        imageThread = thread
        val handler = Handler(thread.looper)
        imageHandler = handler

        val metrics = resources.displayMetrics
        density = metrics.densityDpi
        val screenWidth = max(1, metrics.widthPixels)
        val screenHeight = max(1, metrics.heightPixels)
        val maxDimension = 1280f
        val scale = min(1f, maxDimension / max(screenWidth, screenHeight).toFloat())
        val width = max(1, (screenWidth * scale).toInt())
        val height = max(1, (screenHeight * scale).toInt())

        val reader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 3)
        imageReader = reader
        reader.setOnImageAvailableListener({ source ->
            try {
                val image = source.acquireLatestImage() ?: return@setOnImageAvailableListener
                lastImage?.close()
                lastImage = image
            } catch (_: Throwable) {
            }
        }, handler)

        projection.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                stopSelf()
            }
        }, handler)

        virtualDisplay = try {
            projection.createVirtualDisplay(
                "AMI Screen",
                width,
                height,
                density,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                reader.surface,
                null,
                handler
            )
        } catch (_: Throwable) {
            null
        }

        if (virtualDisplay == null) {
            stopSelf()
            return
        }

        isRunning = true
        stateListener?.invoke(true)
    }

    fun captureFrame(callback: (ByteArray?) -> Unit) {
        val handler = imageHandler
        if (handler == null) {
            callback(null)
            return
        }
        handler.post { callback(captureFrameBytes()) }
    }

    fun captureFrameAfter(delayMillis: Long) {
        val handler = imageHandler ?: return
        handler.postDelayed({
            val bytes = captureFrameBytes()
            pendingCapture = bytes
            if (bytes != null) {
                Handler(mainLooper).post { captureListener?.invoke() }
            }
        }, delayMillis)
    }

    fun takePendingCapture(): ByteArray? {
        val bytes = pendingCapture
        pendingCapture = null
        return bytes
    }

    private fun captureFrameBytes(): ByteArray? {
        val image = lastImage ?: return null
        return try {
            val bitmap = imageToBitmap(image)
            val scaled = if (bitmap.width > 900) {
                val targetHeight = max(1, (bitmap.height * (900f / bitmap.width)).toInt())
                Bitmap.createScaledBitmap(bitmap, 900, targetHeight, true)
            } else {
                bitmap
            }
            val output = java.io.ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 72, output)
            if (scaled !== bitmap) scaled.recycle()
            bitmap.recycle()
            output.toByteArray()
        } catch (_: Throwable) {
            null
        }
    }

    private fun imageToBitmap(image: Image): Bitmap {
        val plane = image.planes[0]
        val buffer = plane.buffer
        buffer.rewind()
        val pixelStride = plane.pixelStride
        val rowStride = plane.rowStride
        val rowPadding = rowStride - pixelStride * image.width
        val paddedWidth = image.width + rowPadding / pixelStride
        val bitmap = Bitmap.createBitmap(paddedWidth, image.height, Bitmap.Config.ARGB_8888)
        bitmap.copyPixelsFromBuffer(buffer)
        if (rowPadding == 0) {
            return bitmap
        }
        val cropped = Bitmap.createBitmap(bitmap, 0, 0, image.width, image.height)
        bitmap.recycle()
        return cropped
    }

    override fun onDestroy() {
        isRunning = false
        stateListener?.invoke(false)
        instance = null

        virtualDisplay?.release()
        virtualDisplay = null

        try {
            lastImage?.close()
        } catch (_: Throwable) {
        }
        lastImage = null

        imageReader?.close()
        imageReader = null

        val projection = mediaProjection
        mediaProjection = null
        try {
            projection?.stop()
        } catch (_: Throwable) {
        }

        imageThread?.quitSafely()
        imageThread = null
        imageHandler = null
        pendingCapture = null

        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
