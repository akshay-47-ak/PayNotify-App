package com.acme.paynotify

import android.app.Notification
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.util.Locale

class NotificationListenerServiceImpl : NotificationListenerService() {
    private val phonePePackages = setOf(
        "com.phonepe.app",
        "com.phonepe.app.business"
    )

    private val phonePeDebugTag = "UPI_PHONEPE_GROUP_DEBUG"
    private val amountRegex = Regex("""(?i)(?:rs\.?|inr|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)|([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(?:rs\.?|inr|₹)""")
    private val payerRegexes = listOf(
        Regex("""(?i)\bfrom\s+([A-Za-z][A-Za-z0-9 ._'&-]{1,80})"""),
        Regex("""(?i)\bpaid\s+by\s+([A-Za-z][A-Za-z0-9 ._'&-]{1,80})"""),
        Regex("""(?i)\breceived\s+from\s+([A-Za-z][A-Za-z0-9 ._'&-]{1,80})""")
    )

    override fun onListenerConnected() {
        super.onListenerConnected()
        logDebugBlock("PHONEPE_DEBUG_LISTENER_CONNECTED")
        logActivePhonePeNotifications(null)
    }

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
        Log.i(phonePeDebugTag, "LISTENER_NOTIFICATION_SEEN packageName = ${sbn.packageName}")

        if (isPhonePePackage(sbn.packageName)) {
            logPhonePeNotificationPosted(sbn, title, text, subText, bigText, joinedLines)
        }

        val data = mapOf(
            "packageName" to sbn.packageName,
            "appName" to sbn.packageName,
            "title" to title,
            "text" to text,
            "subText" to subText,
            "bigText" to bigText,
            "timestamp" to sbn.postTime
        )

        val activeMethodChannel = MainActivity.methodChannel
        if (activeMethodChannel == null) {
            NativePaymentNotificationProcessor(applicationContext).processAsync(
                packageName = sbn.packageName,
                title = title,
                text = text,
                subText = subText,
                bigText = bigText,
                timestamp = sbn.postTime
            )
            return
        }

        Handler(Looper.getMainLooper()).post {
            activeMethodChannel.invokeMethod("onNotificationReceived", data)
        }
    }

    private fun logPhonePeNotificationPosted(
        sbn: StatusBarNotification,
        title: String,
        text: String,
        subText: String,
        bigText: String,
        joinedLines: String
    ) {
        val notification = sbn.notification
        val extras = notification.extras ?: Bundle()
        val isGroupSummary = isGroupSummary(notification)
        val textLines = getTextLines(extras)
        val visibleLines = getVisibleTransactionLines(text, bigText, textLines)

        logDebugBlock(
            "PHONEPE_NOTIFICATION_POSTED\n" +
                "packageName = ${sbn.packageName}\n" +
                "key = ${sbn.key}\n" +
                "id = ${sbn.id}\n" +
                "tag = ${sbn.tag}\n" +
                "postTime = ${sbn.postTime}\n" +
                "groupKey = ${sbn.groupKey}\n" +
                "isGroup = ${sbn.isGroup}\n" +
                "isClearable = ${sbn.isClearable}\n" +
                "isOngoing = ${sbn.isOngoing}\n" +
                "notification.group = ${notification.group}\n" +
                "notification.sortKey = ${notification.sortKey}\n" +
                "notification.number = ${notification.number}\n" +
                "notification.flags = ${notification.flags}\n" +
                "FLAG_GROUP_SUMMARY = $isGroupSummary\n" +
                "channelId = ${getChannelId(notification)}\n" +
                "category = ${notification.category}\n" +
                "extras.title = $title\n" +
                "extras.text = $text\n" +
                "extras.bigText = $bigText\n" +
                "extras.subText = $subText\n" +
                "extras.summaryText = ${extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT)?.toString()?.trim() ?: ""}\n" +
                "extras.textLines = ${textLines.joinToString(" | ")}\n" +
                "visibleTransactionLines = ${visibleLines.joinToString(" | ")}\n" +
                "allExtras = ${bundleToDebugString(extras)}"
        )

        if (visibleLines.size > 1 && visibleLines.any { containsPaymentSignal(it) }) {
            val builder = StringBuilder()
            builder.append("PHONEPE_SUMMARY_TEXT_LINES_FOUND\n")
            builder.append("lineCount = ${visibleLines.size}\n")
            visibleLines.forEachIndexed { index, line ->
                builder.append("line${index + 1} = $line\n")
            }
            logDebugBlock(builder.toString().trimEnd())
        }

        if (shouldInspectActivePhonePeNotifications(title, text, subText, bigText, joinedLines, isGroupSummary)) {
            logActivePhonePeNotifications(sbn)
        }
    }

    private fun logActivePhonePeNotifications(summarySbn: StatusBarNotification?) {
        val activeNotifications = try {
            getActiveNotifications() ?: emptyArray()
        } catch (exception: SecurityException) {
            logDebugBlock(
                "PHONEPE_GROUP_CHECK_RESULT\n" +
                    "summaryKey = ${summarySbn?.key ?: ""}\n" +
                    "activePhonePeCount = 0\n" +
                    "sameGroupCount = 0\n" +
                    "childCount = 0\n" +
                    "result = GET_ACTIVE_NOTIFICATIONS_FAILED\n" +
                    "error = ${exception.message}"
            )
            return
        }

        val activePhonePe = activeNotifications
            .filter {
                isPhonePePackage(it.packageName) &&
                    (summarySbn == null || it.packageName == summarySbn.packageName)
            }
        val summaryGroupKey = summarySbn?.groupKey
        val sameGroup = if (summarySbn == null) {
            activePhonePe
        } else {
            activePhonePe.filter {
                summaryGroupKey.isNullOrBlank() || it.groupKey == summaryGroupKey
            }
        }

        sameGroup.forEach { activeSbn ->
            val extras = activeSbn.notification.extras ?: Bundle()
            val activeTitle = getExtraText(extras, Notification.EXTRA_TITLE, "android.title")
            val activeText = getExtraText(extras, Notification.EXTRA_TEXT, "android.text")
            val activeBigText = getExtraText(extras, Notification.EXTRA_BIG_TEXT)
            val activeLines = getTextLines(extras)
            val combinedText = listOf(activeTitle, activeText, activeBigText, activeLines.joinToString(" "))
                .filter { it.isNotBlank() }
                .joinToString(" ")

            logDebugBlock(
                "PHONEPE_ACTIVE_NOTIFICATION\n" +
                    "key = ${activeSbn.key}\n" +
                    "title = $activeTitle\n" +
                    "text = $activeText\n" +
                    "bigText = $activeBigText\n" +
                    "textLines = ${activeLines.joinToString(" | ")}\n" +
                    "groupKey = ${activeSbn.groupKey}\n" +
                    "isGroupSummary = ${isGroupSummary(activeSbn.notification)}\n" +
                    "postTime = ${activeSbn.postTime}\n" +
                    "amount = ${extractAmount(combinedText) ?: ""}\n" +
                    "payerName = ${extractPayerName(combinedText) ?: ""}"
            )
        }

        val childCount = sameGroup.count { activeSbn ->
            val notification = activeSbn.notification
            val extras = notification.extras ?: Bundle()
            val isDifferentNotification = summarySbn == null || activeSbn.key != summarySbn.key
            val combinedText = listOf(
                getExtraText(extras, Notification.EXTRA_TITLE, "android.title"),
                getExtraText(extras, Notification.EXTRA_TEXT, "android.text"),
                getExtraText(extras, Notification.EXTRA_BIG_TEXT),
                getTextLines(extras).joinToString(" ")
            ).filter { it.isNotBlank() }.joinToString(" ")

            isDifferentNotification && !isGroupSummary(notification) && containsPaymentSignal(combinedText)
        }

        logDebugBlock(
            "PHONEPE_GROUP_CHECK_RESULT\n" +
                "summaryKey = ${summarySbn?.key ?: ""}\n" +
                "activePhonePeCount = ${activePhonePe.size}\n" +
                "sameGroupCount = ${sameGroup.size}\n" +
                "childCount = $childCount\n" +
                "result = ${if (childCount > 0) "CHILD_NOTIFICATIONS_FOUND" else "SUMMARY_ONLY_NO_CHILDREN"}"
        )
    }

    private fun shouldInspectActivePhonePeNotifications(
        title: String,
        text: String,
        subText: String,
        bigText: String,
        joinedLines: String,
        isGroupSummary: Boolean
    ): Boolean {
        val combined = listOf(title, text, subText, bigText, joinedLines)
            .joinToString(" ")
            .lowercase(Locale.ROOT)

        return isGroupSummary ||
            combined.contains("completed transaction updates") ||
            combined.contains("new completed transaction updates")
    }

    private fun isPhonePePackage(packageName: String): Boolean {
        val normalizedPackageName = packageName.lowercase(Locale.ROOT)
        return phonePePackages.contains(normalizedPackageName) ||
            normalizedPackageName.contains("phonepe")
    }

    private fun isGroupSummary(notification: Notification): Boolean {
        return notification.flags and Notification.FLAG_GROUP_SUMMARY != 0
    }

    private fun getChannelId(notification: Notification): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notification.channelId ?: ""
        } else {
            ""
        }
    }

    private fun getExtraText(extras: Bundle, key: String, fallbackKey: String? = null): String {
        return extras.getCharSequence(key)?.toString()?.trim()
            ?: fallbackKey?.let { extras.getCharSequence(it)?.toString()?.trim() }
            ?: ""
    }

    private fun getTextLines(extras: Bundle): List<String> {
        return extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.mapNotNull { it?.toString()?.trim() }
            ?.filter { it.isNotEmpty() }
            ?: emptyList()
    }

    private fun getVisibleTransactionLines(
        text: String,
        bigText: String,
        textLines: List<String>
    ): List<String> {
        val sourceLines = if (textLines.isNotEmpty()) {
            textLines
        } else {
            listOf(bigText, text)
                .firstOrNull { it.contains("\n") }
                ?.lines()
                ?: emptyList()
        }

        return sourceLines
            .map { it.trim().trimStart('⋅', '.', '-', '•').trim() }
            .filter { it.isNotEmpty() && containsPaymentSignal(it) }
            .distinct()
    }

    private fun containsPaymentSignal(value: String): Boolean {
        val lowerValue = value.lowercase(Locale.ROOT)
        return lowerValue.contains("transaction") ||
            lowerValue.contains("payment") ||
            lowerValue.contains("paid") ||
            lowerValue.contains("received") ||
            extractAmount(value) != null
    }

    private fun extractAmount(value: String): String? {
        val match = amountRegex.find(value) ?: return null
        return match.value.trim()
    }

    private fun extractPayerName(value: String): String? {
        for (regex in payerRegexes) {
            val match = regex.find(value) ?: continue
            return match.groupValues.getOrNull(1)?.trim()?.trimEnd('.', ',', '|')
        }
        return null
    }

    private fun bundleToDebugString(bundle: Bundle): String {
        return bundle.keySet().sorted().joinToString(prefix = "{", postfix = "}") { key ->
            "$key=${debugValueToString(bundle.get(key))}"
        }
    }

    private fun debugValueToString(value: Any?): String {
        return when (value) {
            null -> "null"
            is Array<*> -> value.joinToString(prefix = "[", postfix = "]") { debugValueToString(it) }
            is BooleanArray -> value.joinToString(prefix = "[", postfix = "]")
            is ByteArray -> value.joinToString(prefix = "[", postfix = "]")
            is CharArray -> value.joinToString(prefix = "[", postfix = "]")
            is DoubleArray -> value.joinToString(prefix = "[", postfix = "]")
            is FloatArray -> value.joinToString(prefix = "[", postfix = "]")
            is IntArray -> value.joinToString(prefix = "[", postfix = "]")
            is LongArray -> value.joinToString(prefix = "[", postfix = "]")
            is ShortArray -> value.joinToString(prefix = "[", postfix = "]")
            is Bundle -> bundleToDebugString(value)
            else -> value.toString()
        }
    }

    private fun logDebugBlock(message: String) {
        val maxLogLength = 3500
        if (message.length <= maxLogLength) {
            Log.i(phonePeDebugTag, message)
            return
        }

        message.chunked(maxLogLength).forEachIndexed { index, chunk ->
            Log.i(phonePeDebugTag, "chunk=${index + 1}\n$chunk")
        }
    }
}
