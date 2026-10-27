import 'native_templates.dart';

String buildAndroidInteractionRelay(String packageName) =>
    'package $packageName\n\n$androidTasksGeneratedMarker\n'
    r'''
import android.app.Activity
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/** Process-local routing only. No network service or Android permission. */
internal class MiniProgramInteractionRelay : FlutterPlugin, ActivityAware {
    companion object {
        private val engines = mutableSetOf<MiniProgramInteractionRelay>()
        private var busy = false
        fun register(engine: FlutterEngine) {
            if (!engine.plugins.has(MiniProgramInteractionRelay::class.java)) {
                engine.plugins.add(MiniProgramInteractionRelay())
            }
        }
    }
    private var activity: Activity? = null
    private var channel: MethodChannel? = null
    private var enabled = false
    private val handler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        engines.add(this)
        channel = MethodChannel(binding.binaryMessenger, "dev.miniprogram/foreground_interaction").also {
            it.setMethodCallHandler(::handle)
        }
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        enabled = false
        engines.remove(this)
        channel?.setMethodCallHandler(null)
        channel = null
        activity = null
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onDetachedFromActivity() { activity = null }

    private fun focused(): Boolean {
        val current = activity ?: return false
        return enabled && !current.isFinishing && !current.isDestroyed && current.hasWindowFocus()
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "register" -> { enabled = true; result.success(null) }
            "unregister" -> { enabled = false; result.success(null) }
            "dispatch" -> dispatch(call.arguments, result)
            else -> result.notImplemented()
        }
    }

    private fun dispatch(arguments: Any?, result: MethodChannel.Result) {
        val request = arguments as? Map<*, *>
        if (request == null) {
            result.success(mapOf("status" to "rejected", "code" to "invalid_request"))
            return
        }
        try {
            if (JSONObject(request).toString().toByteArray(Charsets.UTF_8).size > 20000) {
                result.success(mapOf("status" to "rejected", "code" to "invalid_request"))
                return
            }
        } catch (_: Exception) {
            result.success(mapOf("status" to "rejected", "code" to "invalid_request"))
            return
        }
        val targets = engines.filter { it.focused() }
        val target = targets.singleOrNull()
        if (target == null || target.channel == null) {
            result.success(mapOf("status" to "unavailable", "code" to "foreground_required"))
            return
        }
        if (busy) {
            result.success(mapOf("status" to "rejected", "code" to "interaction_busy"))
            return
        }
        busy = true
        var finished = false
        val timeout = Runnable {
            if (!finished) {
                finished = true
                busy = false
                // An uncertain request may already have executed. Observe before retrying.
                result.success(mapOf("status" to "unknown", "code" to "relay_timeout"))
            }
        }
        fun complete(value: Any?) {
            if (finished) return
            finished = true
            busy = false
            handler.removeCallbacks(timeout)
            result.success(value)
        }
        handler.postDelayed(timeout, 5000)
        target.channel!!.invokeMethod("dispatch", request, object : MethodChannel.Result {
            override fun success(value: Any?) { complete(value) }
            override fun error(code: String, message: String?, details: Any?) {
                complete(mapOf("status" to "unknown", "code" to "relay_unavailable"))
            }
            override fun notImplemented() {
                complete(mapOf("status" to "unavailable", "code" to "relay_unavailable"))
            }
        })
    }
}
''';
