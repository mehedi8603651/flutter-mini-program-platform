String buildAndroidDisplayBrightnessChannelSource(String packageName) =>
    'package $packageName\n\n'
    r'''import android.app.Activity
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Tooling-generated temporary host-window brightness adapter. */
internal class MiniProgramDisplayBrightnessChannel : FlutterPlugin, ActivityAware {
    companion object {
        private const val CHANNEL_NAME = "mini_program/display_brightness"

        fun register(flutterEngine: FlutterEngine) {
            flutterEngine.plugins.add(MiniProgramDisplayBrightnessChannel())
        }
    }

    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var requestedLevel: Float? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(::handleCall)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        restoreBestEffort(activity)
        requestedLevel = null
        channel?.setMethodCallHandler(null)
        channel = null
        activity = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        requestedLevel?.let { applyBestEffort(binding.activity, it) }
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        requestedLevel?.let { applyBestEffort(binding.activity, it) }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        restoreBestEffort(activity)
        activity = null
    }

    override fun onDetachedFromActivity() {
        restoreBestEffort(activity)
        requestedLevel = null
        activity = null
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setBrightness" -> setBrightness(call, result)
            "restoreBrightness" -> restoreBrightness(result)
            else -> result.notImplemented()
        }
    }

    private fun setBrightness(call: MethodCall, result: MethodChannel.Result) {
        val rawLevel = call.argument<Number>("level")?.toDouble()
        if (rawLevel == null || !rawLevel.isFinite() || rawLevel <= 0.0 || rawLevel > 1.0) {
            result.error(
                "display_brightness_invalid_level",
                "Display brightness must be over 0 and at most 1.",
                null,
            )
            return
        }
        val currentActivity = activity
        if (currentActivity == null) {
            result.error(
                "display_brightness_unavailable",
                "Display brightness requires a foreground Android activity.",
                null,
            )
            return
        }
        val level = rawLevel.toFloat()
        try {
            val attributes = currentActivity.window.attributes
            attributes.screenBrightness = level
            currentActivity.window.attributes = attributes
            requestedLevel = level
            result.success(null)
        } catch (_: Exception) {
            result.error(
                "display_brightness_operation_failed",
                "Android could not update the window brightness.",
                null,
            )
        }
    }

    private fun restoreBrightness(result: MethodChannel.Result) {
        val currentActivity = activity
        requestedLevel = null
        if (currentActivity == null) {
            result.success(null)
            return
        }
        try {
            val attributes = currentActivity.window.attributes
            attributes.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
            currentActivity.window.attributes = attributes
            result.success(null)
        } catch (_: Exception) {
            result.error(
                "display_brightness_operation_failed",
                "Android could not restore the window brightness.",
                null,
            )
        }
    }

    private fun applyBestEffort(target: Activity, level: Float) {
        try {
            val attributes = target.window.attributes
            attributes.screenBrightness = level
            target.window.attributes = attributes
        } catch (_: Exception) {
            // Dart lifecycle ownership remains authoritative.
        }
    }

    private fun restoreBestEffort(target: Activity?) {
        if (target == null) return
        try {
            val attributes = target.window.attributes
            attributes.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
            target.window.attributes = attributes
        } catch (_: Exception) {
            // Activity cleanup is best effort.
        }
    }
}
''';
