package com.acme.paynotify

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.BufferedReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class NativePaymentNotificationProcessor(private val context: Context) {
    private data class Session(
        val enterpriseCode: String,
        val deviceIdentifier: String,
        val terminalId: String,
        val token: String,
        val tokenType: String
    )

    private data class PaymentNotificationData(
        val packageName: String,
        val title: String,
        val text: String,
        val subText: String,
        val bigText: String,
        val timestamp: Long
    )

    companion object {
        private const val TAG = "PayNotifyNative"
        private const val BASE_URL = "https://briskly-jawline-grief.ngrok-free.dev"
        private const val SESSION_PREFS_NAME = "FlutterSharedPreferences"
        private const val SESSION_KEY = "flutter.device_session"

        private val paymentPackages = setOf(
            "com.phonepe.app",
            "com.phonepe.app.business",
            "com.google.android.apps.nbu.paisa.user",
            "net.one97.paytm",
            "in.org.npci.upiapp"
        )

        private val strongKeywords = listOf(
            "credited",
            "debited",
            "payment received",
            "payment of",
            "money received",
            "received from",
            "sent to",
            "upi txn",
            "transaction id",
            "utr",
            "ref no",
            "bank account",
            "available balance",
            "credited to your account",
            "debited from your account",
            "paid you",
            "payment of rs",
            "received in bank",
            "bank transfer received",
            "collected from"
        )

        private val weakKeywords = listOf(
            "upi",
            "payment",
            "paid",
            "received",
            "sent",
            "transaction",
            "bank",
            "account",
            "₹",
            "rs",
            "inr"
        )

        private val amountRegex = Regex("""(?i)(?:rs\.?|inr|₹)\s*([0-9]+(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)|([0-9]+(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)\s*(?:rs\.?|inr|₹)""")
        private val txnRegex = Regex("""(?i)([A-Z0-9]+(?:-[A-Z0-9]+)*-TXN(?:-[A-Z0-9]+)*|TXN[0-9A-Z\-_]+|PADM-TXN-[A-Z0-9\-_]+)""")
        private val payerRegexes = listOf(
            Regex("""(?i)([A-Za-z][A-Za-z .]{1,80})\s+has\s+sent\b"""),
            Regex("""(?i)(?:received from|paid by|from)\s+([A-Za-z][A-Za-z .]{1,60})"""),
            Regex("""(?i)([A-Za-z][A-Za-z .]{1,60})\s+(?:paid you|sent you)""")
        )
    }

    fun processAsync(
        packageName: String,
        title: String,
        text: String,
        subText: String,
        bigText: String,
        timestamp: Long
    ) {
        Thread {
            process(
                PaymentNotificationData(
                    packageName = packageName,
                    title = title,
                    text = text,
                    subText = subText,
                    bigText = bigText,
                    timestamp = timestamp
                )
            )
        }.start()
    }

    private fun process(notification: PaymentNotificationData) {
        val session = getSavedSession()
        if (session == null) {
            Log.w(TAG, "Background payment notification skipped: no saved session")
            return
        }

        val notifications = expandNotificationsForProcessing(notification)
        notifications.forEachIndexed { index, item ->
            if (!isLikelyPaymentNotification(item)) {
                Log.d(TAG, "Background notification filtered: ${item.packageName} | ${item.title}")
                return@forEachIndexed
            }

            val message = buildMessage(item)
            val fullText = listOf(item.title, message)
                .filter { it.trim().isNotEmpty() }
                .joinToString(" ")
                .trim()
            val txnRef = extractTxnRef(fullText)

            val payload = JSONObject().apply {
                put("enterpriseCode", session.enterpriseCode)
                put("deviceIdentifier", session.deviceIdentifier)
                put("terminalId", session.terminalId)
                put("appName", appNameForPackage(item.packageName))
                put("packageName", item.packageName)
                put("title", item.title)
                put("message", message)
                put("rawTitle", item.title)
                put("rawMessage", message)
                putNullable("amount", extractAmount(fullText))
                putNullable("payerName", extractPayerName(fullText))
                putNullable("extractedTxnId", txnRef)
                put("notificationReceivedAt", backendLocalDateTime(item.timestamp))
                putNullable("transactionRef", txnRef)
            }

            sendPaymentNotification(session, payload, index + 1, notifications.size)
        }
    }

    private fun getSavedSession(): Session? {
        val raw = context
            .getSharedPreferences(SESSION_PREFS_NAME, Context.MODE_PRIVATE)
            .getString(SESSION_KEY, null)
            ?.trim()

        if (raw.isNullOrEmpty()) return null

        return try {
            val json = JSONObject(raw)
            val token = json.optString("token").trim()
            if (token.isEmpty()) return null

            Session(
                enterpriseCode = json.optString("enterpriseCode"),
                deviceIdentifier = json.optString("deviceIdentifier"),
                terminalId = json.optString("terminalId"),
                token = token,
                tokenType = json.optString("tokenType", "Bearer").ifBlank { "Bearer" }
            )
        } catch (exception: Exception) {
            Log.e(TAG, "Unable to read saved Flutter session", exception)
            null
        }
    }

    private fun sendPaymentNotification(
        session: Session,
        payload: JSONObject,
        part: Int,
        total: Int
    ) {
        var connection: HttpURLConnection? = null

        try {
            connection = (URL("$BASE_URL/api/payment/notify").openConnection() as HttpURLConnection)
            connection.requestMethod = "POST"
            connection.connectTimeout = 15000
            connection.readTimeout = 15000
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Authorization", "${session.tokenType} ${session.token}")

            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use {
                it.write(payload.toString())
            }

            val statusCode = connection.responseCode
            val stream = if (statusCode in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader()?.use(BufferedReader::readText).orEmpty()

            Log.i(
                TAG,
                "Background notification sent | part=$part/$total | statusCode=$statusCode | body=$body"
            )
        } catch (exception: Exception) {
            Log.e(TAG, "Background payment notification send failed", exception)
        } finally {
            connection?.disconnect()
        }
    }

    private fun isLikelyPaymentNotification(notification: PaymentNotificationData): Boolean {
        val content = listOf(
            notification.title,
            notification.text,
            notification.subText,
            notification.bigText
        ).joinToString(" ").lowercase(Locale.ROOT)

        val isKnownPaymentApp = paymentPackages.contains(notification.packageName)
        val strongMatch = strongKeywords.any { content.contains(it) }
        val weakMatchCount = weakKeywords.count { content.contains(it) }

        return (isKnownPaymentApp && (strongMatch || weakMatchCount >= 2)) ||
            (!isKnownPaymentApp && strongMatch && weakMatchCount >= 2)
    }

    private fun expandNotificationsForProcessing(
        notification: PaymentNotificationData
    ): List<PaymentNotificationData> {
        if (!isPhonePePackage(notification.packageName)) return listOf(notification)

        val lines = extractPhonePeGroupedPaymentLines(notification)
        if (lines.size <= 1) return listOf(notification)

        return lines.map {
            notification.copy(
                title = "PhonePe payment received",
                text = it,
                subText = "",
                bigText = ""
            )
        }
    }

    private fun extractPhonePeGroupedPaymentLines(notification: PaymentNotificationData): List<String> {
        val title = notification.title.lowercase(Locale.ROOT)
        val message = buildMessage(notification)
        val looksGrouped = title.contains("completed transaction updates") ||
            title.contains("new completed transaction updates") ||
            Regex("""^\s*\d+\s+new\s+""", RegexOption.IGNORE_CASE).containsMatchIn(title)

        if (!looksGrouped || !message.contains("\n")) return emptyList()

        val seen = linkedSetOf<String>()
        message.split(Regex("""\r?\n""")).forEach { rawLine ->
            val line = rawLine.trim().replaceFirst(Regex("""^[⋅•\.\-\s]+"""), "").trim()
            if (isCompletePhonePePaymentLine(line)) {
                seen.add(line)
            }
        }

        return seen.toList()
    }

    private fun isCompletePhonePePaymentLine(line: String): Boolean {
        if (line.trim().isEmpty() || extractAmount(line) == null) return false

        val value = line.lowercase(Locale.ROOT)
        val hasPaymentAction = value.contains("has sent") ||
            value.contains("sent") ||
            value.contains("received") ||
            value.contains("paid")
        val hasDestination = value.contains("bank account") ||
            value.contains("account") ||
            value.contains("upi")

        return hasPaymentAction && hasDestination
    }

    private fun buildMessage(notification: PaymentNotificationData): String {
        val seen = linkedSetOf<String>()
        listOf(notification.text, notification.subText, notification.bigText)
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .forEach { value ->
                if (seen.none { it.equals(value, ignoreCase = true) }) {
                    seen.add(value)
                }
            }

        return seen.joinToString(" ").trim()
    }

    private fun appNameForPackage(packageName: String): String {
        val value = packageName.trim().lowercase(Locale.ROOT)

        if (isPhonePePackage(packageName)) return "PHONEPE"
        if (
            value.contains("google pay") ||
            value.contains("gpay") ||
            value.contains("com.google.android.apps.nbu.paisa.user")
        ) {
            return "GOOGLE_PAY"
        }

        return when (value) {
            "net.one97.paytm" -> "PAYTM"
            "in.org.npci.upiapp" -> "BHIM"
            else -> packageName
        }
    }

    private fun isPhonePePackage(packageName: String): Boolean {
        val value = packageName.trim().lowercase(Locale.ROOT)
        return value == "com.phonepe.app" ||
            value == "com.phonepe.app.business" ||
            value.contains("phonepe")
    }

    private fun extractTxnRef(text: String): String? {
        return txnRegex.find(text)?.value?.trim()
    }

    private fun extractAmount(text: String): Double? {
        val match = amountRegex.find(text) ?: return null
        val raw = (match.groups[1]?.value ?: match.groups[2]?.value)
            ?.replace(",", "")
            ?.trim()
        return raw?.toDoubleOrNull()
    }

    private fun extractPayerName(text: String): String? {
        payerRegexes.forEach { regex ->
            val value = regex.find(text)?.groups?.get(1)?.value?.trim()
            if (!value.isNullOrEmpty()) {
                return value.replace(Regex("""\s+"""), " ")
            }
        }

        return null
    }

    private fun backendLocalDateTime(timestamp: Long): String {
        val value = if (timestamp > 0) timestamp else System.currentTimeMillis()
        return SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date(value))
    }

    private fun JSONObject.putNullable(name: String, value: Any?) {
        if (value == null) {
            put(name, JSONObject.NULL)
        } else {
            put(name, value)
        }
    }
}
