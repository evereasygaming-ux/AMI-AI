package com.ami.ami_ai

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.animation.LinearInterpolator
import kotlin.math.sin

class RobotOrbView(context: Context) : View(context) {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val density = resources.displayMetrics.density
    private val handler = Handler(Looper.getMainLooper())

    private var phase = 0f
    private var blink = 0f
    private var running = false

    private val animator = ValueAnimator.ofFloat(0f, (Math.PI * 2).toFloat()).apply {
        duration = 2600L
        repeatCount = ValueAnimator.INFINITE
        interpolator = LinearInterpolator()
        addUpdateListener {
            phase = it.animatedValue as Float
            invalidate()
        }
    }

    private val blinkRunnable = object : Runnable {
        override fun run() {
            if (!running) return
            blink = 1f
            invalidate()
            handler.postDelayed({
                blink = 0f
                invalidate()
            }, 130L)
            handler.postDelayed(this, 2600L + (Math.random() * 2000).toLong())
        }
    }

    init {
        setLayerType(LAYER_TYPE_SOFTWARE, null)
    }

    fun start() {
        if (running) return
        running = true
        animator.start()
        handler.postDelayed(blinkRunnable, 1500L)
    }

    fun stop() {
        running = false
        animator.cancel()
        handler.removeCallbacksAndMessages(null)
    }

    override fun onDetachedFromWindow() {
        stop()
        super.onDetachedFromWindow()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        val cx = w / 2f
        val bob = sin(phase) * dp(2.5f)

        shadowPaint.shader = RadialGradient(
            cx,
            h * 0.95f,
            w * 0.30f,
            intArrayOf(Color.argb(90, 0, 0, 0), Color.TRANSPARENT),
            floatArrayOf(0f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawOval(
            RectF(cx - w * 0.30f, h * 0.93f, cx + w * 0.30f, h * 0.99f),
            shadowPaint
        )

        canvas.save()
        canvas.translate(0f, bob)

        val headCx = cx
        val headCy = h * 0.33f
        val headR = w * 0.235f

        paint.style = Paint.Style.STROKE
        paint.strokeWidth = dp(1.6f)
        paint.color = Color.rgb(150, 230, 255)
        canvas.drawLine(headCx, headCy - headR, headCx, headCy - headR - dp(7f), paint)

        glowPaint.style = Paint.Style.FILL
        glowPaint.color = Color.rgb(120, 235, 255)
        glowPaint.setShadowLayer(dp(8f), 0f, 0f, Color.rgb(80, 220, 255))
        canvas.drawCircle(headCx, headCy - headR - dp(8f), dp(2.6f), glowPaint)

        val bodyRect = RectF(
            cx - w * 0.255f,
            h * 0.47f,
            cx + w * 0.255f,
            h * 0.90f
        )
        paint.style = Paint.Style.FILL
        paint.shader = LinearGradient(
            bodyRect.left,
            bodyRect.top,
            bodyRect.right,
            bodyRect.bottom,
            intArrayOf(Color.rgb(122, 232, 255), Color.rgb(138, 107, 255)),
            null,
            Shader.TileMode.CLAMP
        )
        canvas.drawRoundRect(bodyRect, dp(15f), dp(15f), paint)
        paint.shader = null

        paint.color = Color.argb(70, 255, 255, 255)
        canvas.drawRoundRect(
            RectF(
                bodyRect.left + dp(4f),
                bodyRect.top + dp(4f),
                bodyRect.right - dp(4f),
                bodyRect.top + dp(15f)
            ),
            dp(8f),
            dp(8f),
            paint
        )

        paint.color = Color.rgb(150, 200, 255)
        canvas.drawRoundRect(
            RectF(
                bodyRect.left - dp(7f),
                bodyRect.top + dp(7f),
                bodyRect.left + dp(1f),
                bodyRect.top + dp(26f)
            ),
            dp(4f),
            dp(4f),
            paint
        )
        canvas.drawRoundRect(
            RectF(
                bodyRect.right - dp(1f),
                bodyRect.top + dp(7f),
                bodyRect.right + dp(7f),
                bodyRect.top + dp(26f)
            ),
            dp(4f),
            dp(4f),
            paint
        )

        glowPaint.color = Color.rgb(130, 255, 225)
        glowPaint.setShadowLayer(dp(7f), 0f, 0f, Color.rgb(60, 255, 210))
        canvas.drawCircle(cx, h * 0.60f, dp(3.2f), glowPaint)

        paint.style = Paint.Style.FILL
        paint.shader = RadialGradient(
            headCx - headR * 0.35f,
            headCy - headR * 0.45f,
            headR * 1.6f,
            intArrayOf(
                Color.WHITE,
                Color.rgb(135, 238, 255),
                Color.rgb(126, 96, 255)
            ),
            floatArrayOf(0f, 0.45f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawCircle(headCx, headCy, headR, paint)
        paint.shader = null

        paint.color = Color.rgb(120, 120, 230)
        canvas.drawCircle(headCx - headR * 0.96f, headCy, dp(3.2f), paint)
        canvas.drawCircle(headCx + headR * 0.96f, headCy, dp(3.2f), paint)

        val face = RectF(
            headCx - headR * 0.70f,
            headCy - headR * 0.42f,
            headCx + headR * 0.70f,
            headCy + headR * 0.42f
        )
        paint.color = Color.rgb(8, 13, 30)
        canvas.drawRoundRect(face, headR * 0.30f, headR * 0.30f, paint)

        val eyeW = headR * 0.20f
        val eyeH = headR * 0.34f * (1f - blink * 0.88f)
        val eyeY = face.centerY()
        glowPaint.style = Paint.Style.FILL
        glowPaint.color = Color.rgb(120, 245, 255)
        glowPaint.setShadowLayer(dp(6f), 0f, 0f, Color.rgb(70, 225, 255))
        canvas.drawRoundRect(
            RectF(
                face.centerX() - headR * 0.30f - eyeW / 2f,
                eyeY - eyeH / 2f,
                face.centerX() - headR * 0.30f + eyeW / 2f,
                eyeY + eyeH / 2f
            ),
            eyeW / 2f,
            eyeW / 2f,
            glowPaint
        )
        canvas.drawRoundRect(
            RectF(
                face.centerX() + headR * 0.30f - eyeW / 2f,
                eyeY - eyeH / 2f,
                face.centerX() + headR * 0.30f + eyeW / 2f,
                eyeY + eyeH / 2f
            ),
            eyeW / 2f,
            eyeW / 2f,
            glowPaint
        )

        paint.style = Paint.Style.STROKE
        paint.strokeWidth = dp(1.4f)
        paint.color = Color.rgb(120, 245, 255)
        val smile = Path().apply {
            moveTo(face.centerX() - headR * 0.16f, face.bottom - headR * 0.16f)
            quadTo(
                face.centerX(),
                face.bottom - headR * 0.04f,
                face.centerX() + headR * 0.16f,
                face.bottom - headR * 0.16f
            )
        }
        canvas.drawPath(smile, paint)

        glowPaint.setShadowLayer(0f, 0f, 0f, Color.TRANSPARENT)
        canvas.restore()
    }

    private fun dp(value: Float): Float = value * density
}
