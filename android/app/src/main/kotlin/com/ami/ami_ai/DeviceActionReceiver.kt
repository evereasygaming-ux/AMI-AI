package com.ami.ami_ai

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

object DeviceReminderScheduler {
    private const val PREFS_NAME = "ami_device_reminders"
    private const val CHANNEL_ID = "ami_reminders"
    private const val ACTION_FIRE = "com.ami.ami_ai.action.FIRE_REMINDER"
    private const val EXTRA_ID = "reminder_id"
    private const val EXTRA_TITLE = "reminder_title"

    fun schedule(context: Context, id: String, title: String, triggerAtMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = reminderIntent(context, id, title)
        val pendingIntent = pendingIntent(context, id, intent)
        val triggerAt = maxOf(triggerAtMillis, System.currentTimeMillis() + 1_000L)
        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(id, "$triggerAt\n$title")
            .apply()
    }

    fun cancel(context: Context, id: String) {
        val preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val stored = preferences.getString(id, null)
        if (stored != null) {
            val title = stored.substringAfter("\n", "Reminder")
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent(context, id, reminderIntent(context, id, title)))
        }
        preferences.edit().remove(id).apply()
    }

    fun rescheduleAll(context: Context) {
        val preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        for ((id, raw) in preferences.all) {
            val value = raw as? String ?: continue
            val triggerAt = value.substringBefore('\n').toLongOrNull() ?: continue
            val title = value.substringAfter("\n", "Reminder")
            if (triggerAt <= now) {
                showReminder(context, id, title)
            } else {
                schedule(context, id, title, triggerAt)
            }
        }
    }

    internal fun handleReminder(context: Context, intent: Intent) {
        val id = intent.getStringExtra(EXTRA_ID) ?: return
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "AMI reminder"
        showReminder(context, id, title)
    }

    private fun showReminder(context: Context, id: String, title: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "AMI reminders", NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(context)
        }
        val openAppIntent = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val contentIntent = PendingIntent.getActivity(
            context,
            id.hashCode(),
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = builder
            .setContentIntent(contentIntent)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("AMI reminder")
            .setContentText(title)
            .setAutoCancel(true)
            .build()
        manager.notify(id.hashCode(), notification)
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(id)
            .apply()
    }

    private fun reminderIntent(context: Context, id: String, title: String) =
        Intent(context, DeviceActionReceiver::class.java)
            .setAction(ACTION_FIRE)
            .putExtra(EXTRA_ID, id)
            .putExtra(EXTRA_TITLE, title)

    private fun pendingIntent(context: Context, id: String, intent: Intent) =
        PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}

class DeviceActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> DeviceReminderScheduler.rescheduleAll(context)
            "com.ami.ami_ai.action.FIRE_REMINDER" ->
                DeviceReminderScheduler.handleReminder(context, intent)
        }
    }
}
