package dev.miniprogram.mp_only_host

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

/** Reference HOST integration, independent of the SDK mini-program boundary.
 * One host engine owns the assistant. Task engines relay controls/status only.
 * Nothing is exported to other apps and no system-overlay permission is used.
 */
internal class HostAiSessionRelay : FlutterPlugin, ActivityAware {
    companion object {
        private const val CHANNEL = "dev.miniprogram.mp_only_host/host_ai_session"
        private val clients = mutableSetOf<HostAiSessionRelay>()
        private var owner: HostAiSessionRelay? = null
        private var latest: Map<String, Any?>? = null
        private var sequence = 0L

        fun register(engine: FlutterEngine) {
            if (!engine.plugins.has(HostAiSessionRelay::class.java)) {
                engine.plugins.add(HostAiSessionRelay())
            }
        }

        private fun foreground(): Map<String, String>? {
            val client = clients.singleOrNull { it.focused() } ?: return null
            return mapOf("appId" to client.appId)
        }

        fun focusChanged() {
            owner?.channel?.invokeMethod("foregroundChanged", foreground())
        }

        private fun unavailable(): Map<String, Any?> = mapOf(
            "sequence" to ++sequence,
            "state" to mapOf(
                "running" to false,
                "outcome" to "failed",
                "status" to "Host assistant unavailable",
                "message" to "Return to the host once to start its shared assistant.",
            ),
        )
    }

    private var activity: Activity? = null
    private var channel: MethodChannel? = null
    private var appId = ""
    private val handler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        clients.add(this)
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(::handle)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detach()
        clients.remove(this)
        channel?.setMethodCallHandler(null)
        channel = null
        activity = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        focusChanged()
    }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        focusChanged()
    }
    override fun onDetachedFromActivityForConfigChanges() { activity = null; focusChanged() }
    override fun onDetachedFromActivity() { activity = null; focusChanged() }

    private fun focused(): Boolean {
        val current = activity ?: return false
        return appId.isNotEmpty() && !current.isFinishing &&
            !current.isDestroyed && current.hasWindowFocus()
    }

    private fun detach() {
        appId = ""
        if (owner === this) {
            owner = null
            latest = unavailable()
            clients.filter { it !== this }.forEach { it.channel?.invokeMethod("state", latest) }
        }
        focusChanged()
    }

    private fun bounded(value: Any?): Boolean = try {
        value is Map<*, *> && JSONObject(value).toString().toByteArray(Charsets.UTF_8).size <= 20000
    } catch (_: Exception) { false }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "attach" -> {
                val id = call.argument<String>("appId").orEmpty()
                if (!id.matches(Regex("[A-Za-z0-9_.-]{1,128}"))) {
                    result.error("invalid_client", "Invalid host assistant client.", null)
                    return
                }
                if (call.argument<Boolean>("owner") == true) {
                    if (activity !is MainActivity || (owner != null && owner !== this)) {
                        result.error("invalid_owner", "Only the host owns its assistant.", null)
                        return
                    }
                    owner = this
                }
                appId = id
                result.success(latest ?: if (owner == null) unavailable() else null)
                focusChanged()
            }
            "detach" -> { detach(); result.success(null) }
            "foreground" -> result.success(foreground())
            "publish" -> {
                if (owner !== this || !bounded(call.arguments)) {
                    result.error("invalid_state", "Invalid assistant state.", null)
                    return
                }
                latest = mapOf("sequence" to ++sequence, "state" to call.arguments)
                clients.filter { it !== this && it.appId.isNotEmpty() }
                    .forEach { it.channel?.invokeMethod("state", latest) }
                result.success(null)
            }
            "command" -> {
                val target = owner?.channel
                if (!focused() || target == null || !bounded(call.arguments)) {
                    result.success(mapOf("accepted" to false))
                    return
                }
                var finished = false
                val timeout = Runnable {
                    if (!finished) { finished = true; result.success(mapOf("accepted" to false)) }
                }
                fun complete(value: Any?) {
                    if (finished) return
                    finished = true
                    handler.removeCallbacks(timeout)
                    result.success(value)
                }
                handler.postDelayed(timeout, 3000)
                target.invokeMethod("command", mapOf(
                    "appId" to appId, "command" to call.arguments,
                    "expiresAt" to System.currentTimeMillis() + 2500,
                ),
                    object : MethodChannel.Result {
                        override fun success(value: Any?) { complete(value) }
                        override fun error(code: String, message: String?, details: Any?) {
                            complete(mapOf("accepted" to false))
                        }
                        override fun notImplemented() { complete(mapOf("accepted" to false)) }
                    },
                )
            }
            else -> result.notImplemented()
        }
    }
}
