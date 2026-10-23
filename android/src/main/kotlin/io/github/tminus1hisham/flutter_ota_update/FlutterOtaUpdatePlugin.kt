package io.github.tminus1hisham.flutter_ota_update

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/** Our own subclass so the manifest entry never clashes with an app's FileProvider. */
class OtaFileProvider : FileProvider()

class ChecksumMismatchException(message: String) : Exception(message)

/**
 * Streams [url] into [dest], reporting progress, and returns the SHA-256 hex of the bytes written.
 * Throws [ChecksumMismatchException] (and deletes [dest]) when [expectedSha256] is given and differs.
 */
internal fun downloadAndHash(
    url: String,
    headers: Map<String, String>,
    dest: File,
    expectedSha256: String?,
    onProgress: (received: Long, total: Long) -> Unit,
): String {
    val conn = URL(url).openConnection()
    headers.forEach { (k, v) -> conn.setRequestProperty(k, v) }
    if (conn is HttpURLConnection && conn.responseCode !in 200..299) {
        throw java.io.IOException("HTTP ${conn.responseCode} for $url")
    }
    val total = conn.contentLengthLong
    val digest = MessageDigest.getInstance("SHA-256")
    dest.parentFile?.mkdirs()
    conn.getInputStream().use { input ->
        dest.outputStream().use { output ->
            val buffer = ByteArray(64 * 1024)
            var received = 0L
            var lastReported = -1L
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                output.write(buffer, 0, n)
                digest.update(buffer, 0, n)
                received += n
                // Throttle to ~1% steps (or every 256 KB when size is unknown).
                val step = if (total > 0) total / 100 else 256 * 1024L
                if (received - lastReported >= step) {
                    lastReported = received
                    onProgress(received, total)
                }
            }
            onProgress(received, total)
        }
    }
    val actual = digest.digest().joinToString("") { "%02x".format(it) }
    if (expectedSha256 != null && !actual.equals(expectedSha256, ignoreCase = true)) {
        dest.delete()
        throw ChecksumMismatchException("Expected SHA-256 $expectedSha256 but got $actual")
    }
    return actual
}

/** FlutterOtaUpdatePlugin */
class FlutterOtaUpdatePlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_ota_update")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getAppVersion" -> {
                val info = context.packageManager.getPackageInfo(context.packageName, 0)
                result.success(info.versionName)
            }
            "downloadAndInstall" -> downloadAndInstall(call, result)
            else -> result.notImplemented()
        }
    }

    private fun downloadAndInstall(call: MethodCall, result: Result) {
        val url = call.argument<String>("url")!!
        val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
        val sha256 = call.argument<String>("sha256")
        val fileName = File(call.argument<String>("fileName")!!).name
        val dest = File(File(context.cacheDir, "ota"), fileName)

        Thread {
            try {
                downloadAndHash(url, headers, dest, sha256) { received, total ->
                    mainHandler.post {
                        channel.invokeMethod("progress", mapOf("received" to received, "total" to total))
                    }
                }
                mainHandler.post {
                    try {
                        launchInstaller(dest)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("INSTALL_FAILED", e.message, null)
                    }
                }
            } catch (e: ChecksumMismatchException) {
                mainHandler.post { result.error("CHECKSUM_MISMATCH", e.message, null) }
            } catch (e: Exception) {
                mainHandler.post { result.error("DOWNLOAD_FAILED", e.message, null) }
            }
        }.start()
    }

    private fun launchInstaller(apk: File) {
        val uri = FileProvider.getUriForFile(
            context, "${context.packageName}.flutter_ota_update.fileprovider", apk
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        // On Android 8+ the system installer itself asks the user to allow
        // "install unknown apps" for this app if it isn't granted yet.
        context.startActivity(intent)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
