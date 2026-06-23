package com.acme.paynotify

import android.app.Notification
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class NotificationListenerServiceImpl : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)

        if (sbn == null) return

        val notification: Notification = sbn.notification
        val extras: Bundle = notification.extras ?: Bundle()

        var title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
        var text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim() ?: ""
        var subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()?.trim() ?: ""
        var bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim() ?: ""

        // fallback keys used by some apps
        if (title.isEmpty()) {
            title = extras.getCharSequence("android.title")?.toString()?.trim() ?: ""
        }

        if (text.isEmpty()) {
            text = extras.getCharSequence("android.text")?.toString()?.trim() ?: ""
        }

        // read text lines if available
        val textLines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
        val joinedLines = textLines
            ?.mapNotNull { it?.toString()?.trim() }
            ?.filter { it.isNotEmpty() }
            ?.joinToString(" | ")
            ?: ""

        if (bigText.isEmpty() && joinedLines.isNotEmpty()) {
            bigText = joinedLines
        }

        // fallback to ticker text
        if (text.isEmpty() && notification.tickerText != null) {
            text = notification.tickerText.toString().trim()
        }

        Log.d("PayNotify", "packageName = ${sbn.packageName}")
        Log.d("PayNotify", "title = $title")
        Log.d("PayNotify", "text = $text")
        Log.d("PayNotify", "subText = $subText")
        Log.d("PayNotify", "bigText = $bigText")
        Log.d("PayNotify", "extras = $extras")

        val data = mapOf(
            "packageName" to sbn.packageName,
            "appName" to sbn.packageName,
            "title" to title,
            "text" to text,
            "subText" to subText,
            "bigText" to bigText,
            "timestamp" to sbn.postTime
        )

        Handler(Looper.getMainLooper()).post {
            MainActivity.methodChannel?.invokeMethod("onNotificationReceived", data)
        }
    }
}