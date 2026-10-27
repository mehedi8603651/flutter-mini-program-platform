package dev.miniprogram.mp_only_host

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Separate Android window/task for one mini-program.
 *
 * The host Activity remains alive in its own task. Reordering the host task to
 * the foreground instead of finishing this Activity keeps this mini-program's
 * Flutter engine and in-memory state available for the next switch.
 * Live apps use separate manifest-declared components and task affinities.
 * This avoids relying on a launcher's handling of multiple documents belonging
 * to the same component/affinity.
 */
abstract class MiniProgramActivity : FlutterActivity() {
    private var backCallback: OnBackInvokedCallback? = null
    private var backRequestPending = false

    companion object {
        const val CHANNEL_NAME = "dev.miniprogram.mp_only_host/mini_program_window"
        private const val EXTRA_APP_ID = "mini_program_app_id"
        private const val EXTRA_TITLE = "mini_program_title"
        private const val ROUTE_PREFIX = "/mini-program/"
        private const val DOCUMENT_URI_PREFIX =
            "miniprogram://dev.miniprogram.mp_only_host/active/"
        private val windowActivities = listOf(
            MiniProgramWindowActivity0::class.java,
            MiniProgramWindowActivity1::class.java,
            MiniProgramWindowActivity2::class.java,
            MiniProgramWindowActivity3::class.java,
            MiniProgramWindowActivity4::class.java,
        )

        private fun appIdForIntent(source: Intent?, packageName: String): String {
            source?.getStringExtra(EXTRA_APP_ID)?.takeIf { it.isNotBlank() }?.let { return it }
            // Android can restore a task with its data URI but without extras.
            val uri = source?.data ?: return ""
            if (uri.scheme != "miniprogram" || uri.authority != packageName ||
                uri.pathSegments.size != 2 || uri.pathSegments.first() != "active") return ""
            return uri.lastPathSegment.orEmpty()
        }

        fun openMiniProgram(context: Context, appId: String, title: String) {
            val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val tasks = manager.appTasks
            val slot = selectMiniProgramWindowSlot(
                appId,
                windowActivities.map { it.name },
                tasks.map { task ->
                    val info = task.taskInfo
                    val baseIntent = info.baseIntent
                    MiniProgramTask(
                        info.taskId,
                        baseIntent?.component?.className.orEmpty(),
                        appIdForIntent(baseIntent, context.packageName),
                    )
                },
            )
            val existing = tasks.firstOrNull { it.taskInfo.taskId == slot.existingTaskId }
            if (existing != null) {
                existing.moveToFront()
                Log.i("MiniProgramWindow", "reuse task=${slot.existingTaskId} appId=$appId")
                return
            }
            val activityClass = windowActivities.first { it.name == slot.activityClassName }
            context.startActivity(Intent(context, activityClass).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse(DOCUMENT_URI_PREFIX + Uri.encode(appId))
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtra(EXTRA_APP_ID, appId)
                putExtra(EXTRA_TITLE, title)
            })
        }
    }

    override fun getDartEntrypointFunctionName(): String = "miniProgramMain"

    override fun getInitialRoute(): String {
        val appId = appIdForIntent(intent, packageName)
        val title = intent.getStringExtra(EXTRA_TITLE)?.takeIf { it.isNotBlank() } ?: appId
        return "$ROUTE_PREFIX${Uri.encode(appId)}?title=${Uri.encode(title)}"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val callback = OnBackInvokedCallback {
                handleBack()
            }
            backCallback = callback
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
                callback,
            )
        }
        updateTaskDescription(intent.getStringExtra(EXTRA_TITLE) ?: appIdForIntent(intent, packageName))
        Log.i("MiniProgramWindow", "create task=$taskId appId=${appIdForIntent(intent, packageName)} component=${componentName.className}")
    }

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            backCallback?.let { callback ->
                onBackInvokedDispatcher.unregisterOnBackInvokedCallback(callback)
            }
            backCallback = null
        }
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        val previousAppId = appIdForIntent(this.intent, packageName)
        val nextAppId = appIdForIntent(intent, packageName)
        super.onNewIntent(intent)
        setIntent(intent)
        updateTaskDescription(intent.getStringExtra(EXTRA_TITLE) ?: nextAppId)
        if (!previousAppId.isNullOrEmpty() && previousAppId != nextAppId) {
            recreate()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MiniProgramInteractionRelay.register(flutterEngine)
        HostAiSessionRelay.register(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showHost" -> {
                    showHostActivity()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        HostAiSessionRelay.focusChanged()
    }

    @Suppress("DEPRECATION")
    private fun updateTaskDescription(taskTitle: String) {
        title = taskTitle
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            setTaskDescription(ActivityManager.TaskDescription(taskTitle))
        }
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        handleBack()
    }

    private fun handleBack() {
        if (backRequestPending || isFinishing || isDestroyed) return
        val view = window.decorView
        if (ViewCompat.getRootWindowInsets(view)?.isVisible(WindowInsetsCompat.Type.ime()) == true) {
            WindowInsetsControllerCompat(window, view).hide(WindowInsetsCompat.Type.ime())
            return
        }
        val messenger = flutterEngine?.dartExecutor?.binaryMessenger
        if (messenger == null) {
            showHostActivity()
            return
        }
        backRequestPending = true
        MethodChannel(messenger, CHANNEL_NAME).invokeMethod(
            "handleBack", null, object : MethodChannel.Result {
                private fun complete(handled: Boolean) {
                    backRequestPending = false
                    if (!handled && !isFinishing && !isDestroyed && hasWindowFocus()) {
                        showHostActivity()
                    }
                }
                override fun success(result: Any?) { complete(result == true) }
                override fun error(code: String, message: String?, details: Any?) { complete(false) }
                override fun notImplemented() { complete(false) }
            },
        )
    }

    private fun showHostActivity() {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        val hostTask = manager.appTasks.firstOrNull { task ->
            val taskInfo = task.taskInfo
            taskInfo.baseIntent?.component?.className == MainActivity::class.java.name ||
                taskInfo.topActivity?.className == MainActivity::class.java.name
        }
        if (hostTask != null) {
            hostTask.moveToFront()
            Log.i("MiniProgramWindow", "return from=$taskId host=${hostTask.taskInfo.taskId}")
            return
        }
        startActivity(
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            },
        )
    }
}
