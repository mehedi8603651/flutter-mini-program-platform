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
                        baseIntent?.getStringExtra(EXTRA_APP_ID)
                            ?: baseIntent?.data?.lastPathSegment.orEmpty(),
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
        val appId = intent.getStringExtra(EXTRA_APP_ID).orEmpty()
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
        return "$ROUTE_PREFIX${Uri.encode(appId)}?title=${Uri.encode(title)}"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val callback = OnBackInvokedCallback {
                showHostActivity()
            }
            backCallback = callback
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_OVERLAY,
                callback,
            )
        }
        updateTaskDescription(intent.getStringExtra(EXTRA_TITLE) ?: "Mini Program")
        Log.i("MiniProgramWindow", "create task=$taskId appId=${intent.getStringExtra(EXTRA_APP_ID)} component=${componentName.className}")
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
        val previousAppId = this.intent?.getStringExtra(EXTRA_APP_ID)
        val nextAppId = intent.getStringExtra(EXTRA_APP_ID)
        super.onNewIntent(intent)
        setIntent(intent)
        updateTaskDescription(intent.getStringExtra(EXTRA_TITLE) ?: "Mini Program")
        if (!previousAppId.isNullOrEmpty() && previousAppId != nextAppId) {
            recreate()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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

    @Suppress("DEPRECATION")
    private fun updateTaskDescription(taskTitle: String) {
        title = taskTitle
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            setTaskDescription(ActivityManager.TaskDescription(taskTitle))
        }
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        showHostActivity()
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
