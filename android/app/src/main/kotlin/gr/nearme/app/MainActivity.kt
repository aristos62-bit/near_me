package gr.nearme.app

import android.content.Intent
import android.net.Uri
import android.view.WindowManager
import java.io.File
import java.io.FileOutputStream
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    /** Buffered incoming share (cold start, πριν είναι έτοιμο το Flutter). */
    private var pendingShare: Map<String, Any?>? = null
    private var shareChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    /**
     * Εξάγει και αποθηκεύει ένα ACTION_SEND intent. Αν το Flutter είναι ήδη
     * έτοιμο (warm), το σπρώχνει αμέσως· αλλιώς το κρατάει στο [pendingShare]
     * ώστε το Dart να το πάρει μέσω getPendingShare κατά την αρχικοποίηση.
     */
    private fun handleShareIntent(intent: Intent?) {
        if (intent == null || intent.action != Intent.ACTION_SEND) return
        val share = extractShare(intent) ?: return
        pendingShare = share
        pushPendingShare()
    }

    @Suppress("DEPRECATION")
    private fun extractShare(intent: Intent): Map<String, Any?>? {
        val type = intent.type ?: return null
        return when {
            type.startsWith("image/") || type.startsWith("video/") || type.startsWith("audio/") -> {
                val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                    ?: intent.clipData?.getItemAt(0)?.uri
                val path = uri?.let { copySharedMedia(it, type) } ?: return null
                val mediaType = when {
                    type.startsWith("image/") -> "image"
                    type.startsWith("video/") -> "video"
                    else -> "audio"
                }
                mapOf("type" to mediaType, "content" to path)
            }
            type.startsWith("text/") -> {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                    ?: intent.getStringExtra(Intent.EXTRA_SUBJECT)
                if (text.isNullOrBlank()) return null
                mapOf("type" to "text", "content" to text)
            }
            else -> null
        }
    }

    /**
     * Αντιγράφει το shared media (content:// uri) στο cacheDir
     * `near_me_share_cache/incoming/` με την κατάλληλη επέκταση, ώστε το Dart
     * να το διαβάσει σαν κανονικό file. Επιστρέφει το απόλυτο path ή null.
     * Ext mapping είναι ίδιο με το Dart: gif→gif, image→jpg, video→mp4, audio→m4a.
     */
    private fun copySharedMedia(uri: Uri, type: String): String? {
        val ext = when {
            type.equals("image/gif", ignoreCase = true) -> "gif"
            type.startsWith("image/") -> "jpg"
            type.startsWith("video/") -> "mp4"
            type.startsWith("audio/") -> "m4a"
            else -> return null
        }
        val dest = File(cacheDir, "near_me_share_cache/incoming/${System.currentTimeMillis()}.$ext")
        try {
            dest.parentFile?.mkdirs()
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(dest).use { output -> input.copyTo(output) }
            } ?: return null
            return dest.absolutePath
        } catch (e: Exception) {
            dest.delete()
            return null
        }
    }

    /**
     * Σπρώχνει το pending share στο Dart. Μόλις το Dart το αναγνωρίσει (ack),
     * καθαρίζει το [pendingShare] για να μην το ξαναπάρει το getPendingShare
     * (αποτροπή διπλού sheet στο resume).
     */
    private fun pushPendingShare() {
        val share = pendingShare ?: return
        val channel = shareChannel ?: return
        runOnUiThread {
            try {
                channel.invokeMethod("onShareReceived", share, object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        if (pendingShare == share) pendingShare = null
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        // Dart όχι έτοιμο — μένει στο pendingShare για το getPendingShare.
                    }

                    override fun notImplemented() {
                        // Dart δεν έχει handler — αφήνουμε το getPendingShare να το πάρει.
                    }
                })
            } catch (e: Exception) {
                // Dart handler όχι έτοιμο (cold start) — κρατάμε το pendingShare.
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "near_me/screen_protector"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    runOnUiThread {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE
                        )
                    }
                    result.success(true)
                }
                "disable" -> {
                    runOnUiThread {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "near_me/incoming_share"
        )
        shareChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingShare" -> {
                    val share = pendingShare
                    pendingShare = null
                    result.success(share)
                }
                else -> result.notImplemented()
            }
        }
    }
}