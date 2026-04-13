package com.example.myfirst_app

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class NotificationListenerServiceImpl : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)

        if (sbn == null) return

        val notification: Notification = sbn.notification
        val extras = notification.extras

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()

        val data = mapOf(
            "packageName" to sbn.packageName,
            "appName" to sbn.packageName,
            "title" to title,
            "text" to text,
            "subText" to subText,
            "bigText" to bigText,
            "timestamp" to sbn.postTime
        )

        MainActivity.methodChannel?.invokeMethod("onNotificationReceived", data)
    }
}