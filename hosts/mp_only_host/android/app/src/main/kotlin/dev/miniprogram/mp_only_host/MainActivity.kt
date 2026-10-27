package dev.miniprogram.mp_only_host

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MiniProgramInteractionRelay.register(flutterEngine)
        HostAiSessionRelay.register(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MiniProgramActivity.CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openMiniProgram" -> {
                    val appId = (call.argument<String>("appId") ?: "").trim()
                    val title = (call.argument<String>("title") ?: appId).trim()
                    if (appId.isEmpty() || title.isEmpty()) {
                        result.error(
                            "invalid_mini_program",
                            "A mini-program appId and title are required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    try {
                        MiniProgramActivity.openMiniProgram(this, appId, title)
                        result.success(null)
                    } catch (error: MiniProgramWindowLimitException) {
                        result.error("mini_program_window_limit", error.message, null)
                    } catch (error: RuntimeException) {
                        result.error(
                            "mini_program_window_unavailable",
                            "Android could not open the mini-program window.",
                            error.javaClass.simpleName,
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        HostAiSessionRelay.focusChanged()
    }
}
