String buildAndroidShareChannelSource(String packageName) =>
    'package $packageName\n\n'
    r'''import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Tooling-generated Android system-share adapter. */
internal class MiniProgramShareChannel : FlutterPlugin, ActivityAware {
    companion object {
        private const val CHANNEL_NAME = "mini_program/share"
        private const val MAX_MEDIA_ITEMS = 10
        private const val MAX_TITLE_LENGTH = 200
        private const val MAX_TEXT_LENGTH = 32768
        private const val MAX_URL_LENGTH = 2048

        fun register(flutterEngine: FlutterEngine) {
            flutterEngine.plugins.add(MiniProgramShareChannel())
        }
    }

    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var requestInProgress = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(::handleCall)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        activity = null
        requestInProgress = false
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "open") {
            result.notImplemented()
            return
        }
        if (requestInProgress) {
            result.error(
                "share_request_in_progress",
                "A system share request is already in progress.",
                null,
            )
            return
        }
        val currentActivity = activity
        if (currentActivity == null) {
            result.error(
                "share_unavailable",
                "Android system sharing requires a foreground activity.",
                null,
            )
            return
        }
        requestInProgress = true
        try {
            openChooser(currentActivity, call.arguments as? Map<*, *>, result)
        } finally {
            requestInProgress = false
        }
    }

    private fun openChooser(
        currentActivity: Activity,
        arguments: Map<*, *>?,
        result: MethodChannel.Result,
    ) {
        val appId = boundedString(arguments?.get("miniProgramId"), 256)
        val title = optionalBoundedString(arguments?.get("title"), MAX_TITLE_LENGTH)
        val text = optionalBoundedString(arguments?.get("text"), MAX_TEXT_LENGTH)
        val rawUrl = arguments?.get("url")
        val url = optionalHttpsUrl(rawUrl)
        val rawMediaRefs = arguments?.get("mediaRefs")
        val mediaRefs = stringList(rawMediaRefs)
        if (appId == null ||
            (arguments?.get("title") != null && title == null) ||
            (arguments?.get("text") != null && text == null) ||
            (rawUrl != null && url == null) ||
            (rawMediaRefs != null && mediaRefs == null)
        ) {
            result.error(
                "share_invalid_content",
                "The resolved share content is invalid.",
                null,
            )
            return
        }
        val resolvedMediaRefs = mediaRefs ?: emptyList()
        if (text == null && url == null && resolvedMediaRefs.isEmpty()) {
            result.error(
                "share_invalid_content",
                "Share content requires text, an HTTPS URL, or media.",
                null,
            )
            return
        }
        if (resolvedMediaRefs.size > MAX_MEDIA_ITEMS) {
            result.error(
                "share_too_many_items",
                "The share request contains too many media items.",
                null,
            )
            return
        }
        val entries = resolvedMediaRefs.map { mediaRef ->
            MiniProgramHostMediaRegistry.findOwned(appId, mediaRef)
                ?: run {
                    result.error(
                        "share_media_not_owned",
                        "A media reference is unavailable or belongs to another mini-program.",
                        null,
                    )
                    return
                }
        }
        val sendIntent = Intent(
            if (entries.size > 1) Intent.ACTION_SEND_MULTIPLE else Intent.ACTION_SEND,
        ).apply {
            type = commonMimeType(entries.map { it.mimeType })
            val sharedText = listOfNotNull(text, url).joinToString("\n")
            if (sharedText.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, sharedText)
            if (entries.size == 1) {
                putExtra(Intent.EXTRA_STREAM, entries.first().uri)
            } else if (entries.size > 1) {
                putParcelableArrayListExtra(
                    Intent.EXTRA_STREAM,
                    ArrayList<Uri>(entries.map { it.uri }),
                )
            }
            if (entries.isNotEmpty()) {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                clipData = ClipData.newUri(
                    currentActivity.contentResolver,
                    entries.first().fileName,
                    entries.first().uri,
                ).also { clip ->
                    entries.drop(1).forEach { entry ->
                        clip.addItem(ClipData.Item(entry.uri))
                    }
                }
            }
        }
        try {
            val chooser = Intent.createChooser(sendIntent, title ?: "Share")
            currentActivity.startActivity(chooser)
            result.success(mapOf("chooserOpened" to true))
        } catch (_: ActivityNotFoundException) {
            result.error(
                "share_unavailable",
                "No Android app can handle this share request.",
                null,
            )
        } catch (error: SecurityException) {
            result.error(
                "share_operation_failed",
                "Android denied access to the shared media.",
                error.javaClass.simpleName,
            )
        } catch (error: Exception) {
            result.error(
                "share_operation_failed",
                "The Android share chooser could not be opened.",
                error.javaClass.simpleName,
            )
        }
    }

    private fun boundedString(raw: Any?, maxLength: Int): String? {
        val value = (raw as? String)?.trim() ?: return null
        return value.takeIf { it.isNotEmpty() && it.length <= maxLength }
    }

    private fun optionalBoundedString(raw: Any?, maxLength: Int): String? {
        if (raw == null) return null
        return boundedString(raw, maxLength)
    }

    private fun optionalHttpsUrl(raw: Any?): String? {
        if (raw == null) return null
        val value = boundedString(raw, MAX_URL_LENGTH) ?: return null
        val uri = Uri.parse(value)
        return value.takeIf {
            uri.scheme.equals("https", ignoreCase = true) &&
                !uri.host.isNullOrBlank() &&
                uri.userInfo.isNullOrBlank()
        }
    }

    private fun stringList(raw: Any?): List<String>? {
        if (raw == null) return emptyList()
        val list = raw as? List<*> ?: return null
        val result = mutableListOf<String>()
        for (item in list) {
            val value = boundedString(item, 512) ?: return null
            if (!result.contains(value)) result.add(value)
        }
        return result
    }

    private fun commonMimeType(values: List<String>): String {
        if (values.isEmpty()) return "text/plain"
        val normalized = values.map { it.lowercase() }
        if (normalized.distinct().size == 1) return normalized.first()
        val families = normalized.map { it.substringBefore('/', "") }.distinct()
        return if (families.size == 1 && families.first().isNotEmpty()) {
            "${families.first()}/*"
        } else {
            "*/*"
        }
    }
}
''';
