package com.ami.ami_ai

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray

class AmiAccessibilityService : AccessibilityService() {

    companion object {
        private const val MAX_NODES = 300
        private const val MAX_DEPTH = 30
        private const val MAX_TEXT_LENGTH = 300
        private const val MAX_INPUT_LENGTH = 5000
        private const val MAX_VISITED_NODES = 1200
        private const val STREAM_INTERVAL_MS = 500L

        @Volatile
        var instance: AmiAccessibilityService? = null
            private set

        @Volatile
        var streamSink: EventChannel.EventSink? = null
    }

    private val streamHandler = Handler(Looper.getMainLooper())
    private var streamScheduled = false
    private var lastStreamAt = 0L
    private val streamRunnable = Runnable {
        streamScheduled = false
        if (streamSink != null) {
            streamSink?.success(JSONArray(getScreenNodes()).toString())
            lastStreamAt = SystemClock.elapsedRealtime()
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        streamCurrentScreen()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || streamSink == null || streamScheduled) return
        scheduleScreenStream()
    }

    private fun scheduleScreenStream() {
        if (streamSink == null || streamScheduled) return
        val elapsed = SystemClock.elapsedRealtime() - lastStreamAt
        val delay = (STREAM_INTERVAL_MS - elapsed).coerceAtLeast(0L)
        streamScheduled = true
        streamHandler.postDelayed(streamRunnable, delay)
    }

    fun streamCurrentScreen() = scheduleScreenStream()

    override fun onInterrupt() = Unit

    fun getScreenNodes(): List<Map<String, Any?>> {
        val root = rootInActiveWindow ?: return emptyList()
        val nodes = mutableListOf<Map<String, Any?>>()
        appendNode(root, nodes, IntArray(1), 0)
        return nodes
    }

    fun tapAt(x: Float, y: Float, onResult: (Boolean) -> Unit) {
        val metrics = resources.displayMetrics
        if (!x.isFinite() || !y.isFinite() || x < 0 || y < 0 ||
            x > 1 || y > 1
        ) {
            onResult(false)
            return
        }

        val screenX = x * metrics.widthPixels
        val screenY = y * metrics.heightPixels

        val root = rootInActiveWindow
        if (root == null) {
            onResult(false)
            return
        }

        val target = try {
            findClickableNode(root, screenX, screenY, IntArray(1), 0)
        } finally {
            root.recycle()
        }
        if (target != null) {
            val clicked = try {
                target.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            } finally {
                target.recycle()
            }
            if (clicked) {
                onResult(true)
                return
            }
        }

        val path = Path().apply { moveTo(screenX, screenY) }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 80))
            .build()
        val dispatched = dispatchGesture(
            gesture,
            object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    onResult(true)
                }

                override fun onCancelled(gestureDescription: GestureDescription?) {
                    onResult(false)
                }
            },
            null
        )
        if (!dispatched) onResult(false)
    }

    fun typeText(text: String): Boolean {
        if (text.length > MAX_INPUT_LENGTH) return false
        val root = rootInActiveWindow ?: return false
        try {
            val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: return false
            try {
                if (!focused.isEditable || focused.isPassword) return false
                val arguments = Bundle().apply {
                    putCharSequence(
                        AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                        text
                    )
                }
                return focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
            } finally {
                focused.recycle()
            }
        } finally {
            root.recycle()
        }
    }

    private fun appendNode(
        node: AccessibilityNodeInfo,
        nodes: MutableList<Map<String, Any?>>,
        visited: IntArray,
        depth: Int
    ) {
        if (nodes.size >= MAX_NODES || depth > MAX_DEPTH || visited[0] >= MAX_VISITED_NODES) {
            node.recycle()
            return
        }
        visited[0]++
        try {
            if (node.isVisibleToUser) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                val password = node.isPassword
                nodes.add(
                    mapOf(
                        "index" to nodes.size,
                        "text" to if (password) null else node.text?.toString()?.take(MAX_TEXT_LENGTH),
                        "contentDescription" to if (password) null else node.contentDescription?.toString()?.take(MAX_TEXT_LENGTH),
                        "className" to node.className?.toString(),
                        "viewId" to node.viewIdResourceName,
                        "bounds" to listOf(bounds.left, bounds.top, bounds.right, bounds.bottom),
                        "clickable" to node.isClickable,
                        "editable" to node.isEditable,
                        "focused" to node.isFocused,
                        "enabled" to node.isEnabled,
                        "scrollable" to node.isScrollable,
                        "password" to password
                    )
                )
            }
            for (index in 0 until node.childCount) {
                if (nodes.size >= MAX_NODES) break
                node.getChild(index)?.let { appendNode(it, nodes, visited, depth + 1) }
            }
        } finally {
            node.recycle()
        }
    }

    private fun findClickableNode(
        node: AccessibilityNodeInfo,
        x: Float,
        y: Float,
        visited: IntArray,
        depth: Int
    ): AccessibilityNodeInfo? {
        if (depth > MAX_DEPTH || visited[0] >= MAX_VISITED_NODES) return null
        visited[0]++
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        if (!bounds.contains(x.toInt(), y.toInt())) return null

        for (index in node.childCount - 1 downTo 0) {
            val child = node.getChild(index) ?: continue
            val found = try {
                findClickableNode(child, x, y, visited, depth + 1)
            } finally {
                child.recycle()
            }
            if (found != null) return found
        }
        return if (node.isClickable && node.isEnabled) AccessibilityNodeInfo.obtain(node) else null
    }

    override fun onDestroy() {
        streamHandler.removeCallbacks(streamRunnable)
        streamScheduled = false
        if (instance === this) instance = null
        super.onDestroy()
    }
}
