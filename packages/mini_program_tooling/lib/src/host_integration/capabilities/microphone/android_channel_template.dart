String buildAndroidMicrophoneChannelSource(String packageName) =>
    'package $packageName\n\n$_androidMicrophoneChannelSource';

const String _androidMicrophoneChannelSource = r'''import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.MediaMetadataRetriever
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.StatFs
import androidx.core.content.FileProvider
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

/** A distinct component prevents collisions with other capability FileProviders. */
class MiniProgramMicrophoneFileProvider : FileProvider() {
    override fun getType(uri: android.net.Uri): String? {
        val inferred = super.getType(uri) // Retain FileProvider path validation.
        // Android MIME tables vary for .m4a; match our fixed AAC/MPEG-4 contract.
        return if (uri.lastPathSegment?.endsWith(".m4a") == true) "audio/mp4" else inferred
    }
}

/** Tooling-generated foreground recorder. Native audio locations stay private. */
internal class MiniProgramMicrophoneChannel : FlutterPlugin, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener, DefaultLifecycleObserver {
    companion object {
        private const val CHANNEL_NAME = "mini_program/microphone"
        private const val PERMISSION_REQUEST = 4117
        private val recordingInProgress = AtomicBoolean(false)
        private val cleanedPreviousProcess = AtomicBoolean(false)
        fun register(engine: FlutterEngine) { engine.plugins.add(MiniProgramMicrophoneChannel()) }
    }
    private data class Recording(
        val id: String, val appId: String, val seconds: Int, val maxBytes: Long,
        val result: MethodChannel.Result,
        var recorder: MediaRecorder? = null, var file: File? = null,
        var started: Boolean = false, var permissionPending: Boolean = false,
        @Volatile var cancelled: Boolean = false, var replied: Boolean = false,
        var finished: Boolean = false, var timeout: Runnable? = null,
    )
    @Volatile private var context: Context? = null
    @Volatile private var activity: Activity? = null
    @Volatile private var activityStarted = false
    private var binding: ActivityPluginBinding? = null
    private var channel: MethodChannel? = null
    @Volatile private var pending: Recording? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val recorderThread = HandlerThread("MiniProgramRecorder").apply { start() }
    private val handler = Handler(recorderThread.looper)
    private val ownedRefs = mutableMapOf<String, String>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also { it.setMethodCallHandler(::handleCall) }
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detach()
        handler.post {
            ownedRefs.forEach { (ref, appId) -> MiniProgramHostMediaRegistry.releaseOwned(appId, ref) }
            ownedRefs.clear()
            recorderThread.quitSafely()
        }
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding)
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attach(binding)
    override fun onDetachedFromActivityForConfigChanges() = detach()
    override fun onDetachedFromActivity() = detach()
    private fun attach(value: ActivityPluginBinding) {
        binding = value
        activity = value.activity
        activityStarted = (value.activity as? LifecycleOwner)?.lifecycle?.currentState
            ?.isAtLeast(Lifecycle.State.STARTED) == true
        value.addRequestPermissionsResultListener(this)
        (value.activity as? LifecycleOwner)?.lifecycle?.addObserver(this)
    }
    private fun detach() {
        activityStarted = false
        pending?.cancelled = true
        handler.post {
            pending?.let { discard(it, "microphone_recording_cancelled", "The recording activity detached.", terminal = true) }
        }
        (activity as? LifecycleOwner)?.lifecycle?.removeObserver(this)
        binding?.removeRequestPermissionsResultListener(this)
        binding = null
        activity = null
    }
    override fun onStart(owner: LifecycleOwner) { activityStarted = true }
    override fun onStop(owner: LifecycleOwner) {
        activityStarted = false
        handler.post {
            pending?.let {
                if (it.started) finishRecording(it, "background")
                else discard(it, "microphone_recording_cancelled", "Recording stopped before it began.")
            }
        }
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        // Mark cancellation immediately even if a slow native start is pending.
        if (call.method == "cancel") {
            pending?.takeIf { it.id == call.argument<String>("recordingId") }?.cancelled = true
        }
        handler.post { handleRecorderCall(call, result) }
    }
    private fun handleRecorderCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "record" -> record(call, result)
            "stop", "cancel" -> {
                val recording = pending
                if (recording == null || recording.id != call.argument<String>("recordingId")) {
                    result.success(false)
                } else {
                    if (call.method == "stop" && recording.started) {
                        finishRecording(recording, if (call.argument<Boolean>("background") == true) "background" else "user")
                    } else discard(recording, "microphone_recording_cancelled", "Microphone recording was cancelled.")
                    result.success(true)
                }
            }
            "releaseMedia" -> {
                val appId = call.argument<String>("miniProgramId")
                val ref = call.argument<String>("mediaRef")
                val released = appId != null && ref != null && MiniProgramHostMediaRegistry.releaseOwned(appId, ref)
                if (released) ownedRefs.remove(ref)
                result.success(released)
            }
            else -> result.notImplemented()
        }
    }

    private fun record(call: MethodCall, result: MethodChannel.Result) {
        val appContext = context
        val current = activity
        val id = call.argument<String>("recordingId")
        val appId = call.argument<String>("miniProgramId")
        val seconds = call.argument<Number>("maxDurationSeconds")?.toInt()
        val maxBytes = call.argument<Number>("maxBytes")?.toLong()
        if (id.isNullOrBlank() || id.length > 160 || appId.isNullOrBlank() || appId.length > 512 ||
            seconds == null || seconds !in 1..600 || maxBytes == null || maxBytes !in 1..104857600L) {
            result.error("microphone_invalid_request", "The recording request is invalid.", null)
            return
        }
        if (appContext == null || current == null || !foreground() ||
            !appContext.packageManager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE)) {
            result.error("microphone_unavailable", "Recording requires a foreground activity and microphone.", null)
            return
        }
        if (!recordingInProgress.compareAndSet(false, true)) {
            result.error("microphone_request_in_progress", "Another mini-program is already recording.", null)
            return
        }
        val recording = Recording(id, appId, seconds, maxBytes, result)
        pending = recording
        if (appContext.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            start(recording)
        } else {
            recording.permissionPending = true
            mainHandler.post {
                if (activity !== current || !activityStarted) {
                    handler.post { discard(recording, "microphone_recording_cancelled", "The recording activity closed.", terminal = true) }
                } else try {
                    current.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), PERMISSION_REQUEST)
                } catch (_: Exception) {
                    handler.post {
                        recording.permissionPending = false
                        discard(recording, "microphone_unavailable", "Android could not request microphone permission.", terminal = true)
                    }
                }
            }
        }
    }

    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, grants: IntArray): Boolean {
        if (code != PERMISSION_REQUEST) return false
        val granted = grants.isNotEmpty() && grants[0] == PackageManager.PERMISSION_GRANTED
        val permanent = activity?.shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO) == false
        handler.post { permissionResult(granted, permanent) }
        return true
    }
    private fun permissionResult(granted: Boolean, permanent: Boolean) {
        val recording = pending ?: return
        recording.permissionPending = false
        if (recording.cancelled) {
            discard(recording, "microphone_recording_cancelled", "Microphone recording was cancelled.", terminal = true)
            return
        }
        if (!granted) {
            discard(recording, if (permanent) "microphone_permission_denied_permanently" else "microphone_permission_denied",
                "Microphone permission was not granted.", terminal = true)
        } else {
            // The permission callback can precede the activity's resumed event.
            start(recording)
        }
    }

    private fun foreground(): Boolean = activityStarted && activity?.isFinishing == false

    @Suppress("DEPRECATION")
    private fun start(recording: Recording) {
        if (pending !== recording || recording.cancelled || recording.finished) return
        val appContext = context
        if (appContext == null || !foreground()) {
            discard(recording, "microphone_unavailable", "Recording requires a foreground activity.", terminal = true)
            return
        }
        val audioManager = appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (audioManager.isMicrophoneMute) {
            discard(recording, "microphone_unavailable", "The microphone is muted by the system.", terminal = true)
            return
        }
        try {
            val directory = File(appContext.cacheDir, "mini_program_microphone")
            if ((!directory.exists() && !directory.mkdirs()) ||
                StatFs(appContext.cacheDir.absolutePath).availableBytes < 64L * 1024 * 1024) {
                discard(recording, "microphone_storage_unavailable", "There is not enough space for recording.", terminal = true)
                return
            }
            if (cleanedPreviousProcess.compareAndSet(false, true)) {
                directory.listFiles()?.forEach { file ->
                    if (file.name.matches(Regex("[0-9a-f-]{36}\\.m4a")) &&
                        MiniProgramHostMediaRegistry.find("voice_${file.nameWithoutExtension}") == null) file.delete()
                }
            }
            val file = File(directory, "${UUID.randomUUID()}.m4a")
            recording.file = file
            val recorder = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(appContext) else MediaRecorder()
            recording.recorder = recorder
            recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            recorder.setAudioChannels(1)
            recorder.setAudioSamplingRate(16000)
            recorder.setAudioEncodingBitRate(64000)
            recorder.setOutputFile(file.absolutePath)
            recorder.setMaxDuration(recording.seconds * 1000)
            recorder.setMaxFileSize(recording.maxBytes)
            recorder.setOnInfoListener { _, what, _ ->
                if (pending === recording && recording.started) when (what) {
                    MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED -> finishRecording(recording, "durationLimit")
                    MediaRecorder.MEDIA_RECORDER_INFO_MAX_FILESIZE_REACHED -> finishRecording(recording, "sizeLimit")
                }
            }
            recorder.setOnErrorListener { _, _, _ ->
                if (pending === recording) discard(recording, "microphone_operation_failed", "Android could not continue recording.", terminal = true)
            }
            recorder.prepare()
            if (recording.cancelled || !foreground()) {
                discard(recording, "microphone_recording_cancelled", "Recording stopped before it began.", terminal = true)
                return
            }
            recorder.start()
            recording.started = true
            if (recording.cancelled) {
                discard(recording, "microphone_recording_cancelled", "Microphone recording was cancelled.", terminal = true)
                return
            }
            if (!foreground()) { finishRecording(recording, "background"); return }
            val timeout = Runnable { if (pending === recording) finishRecording(recording, "durationLimit") }
            recording.timeout = timeout
            handler.postDelayed(timeout, recording.seconds * 1000L + 250L)
            mainHandler.post {
                if (pending === recording && !recording.cancelled) {
                    channel?.invokeMethod("recordingStarted", mapOf("recordingId" to recording.id))
                }
            }
        } catch (_: SecurityException) {
            discard(recording, "microphone_permission_denied", "Microphone permission is unavailable.", terminal = true)
        } catch (_: Exception) {
            discard(recording, "microphone_operation_failed", "Android could not start microphone recording.", terminal = true)
        }
    }

    private fun finishRecording(recording: Recording, reason: String) {
        if (pending !== recording || recording.finished || recording.cancelled) return
        try {
            recording.recorder?.stop()
            recording.started = false
            recording.recorder?.release()
            recording.recorder = null
            val appContext = context ?: throw IllegalStateException()
            val file = recording.file ?: throw IllegalStateException()
            val retriever = MediaMetadataRetriever()
            val duration = try {
                retriever.setDataSource(file.absolutePath)
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0
            } finally { retriever.release() }
            if (file.length() !in 1..recording.maxBytes || duration !in 1..(recording.seconds * 1000L + 1000L)) {
                discard(recording, "microphone_limit_exceeded", "The recording exceeds accepted limits or is empty.", terminal = true)
                return
            }
            val ref = "voice_${file.nameWithoutExtension}"
            val name = "voice_${file.name}"
            val uri = FileProvider.getUriForFile(appContext, appContext.packageName + ".mini_program_microphone_files", file)
            if (!MiniProgramHostMediaRegistry.register(MiniProgramHostMediaRegistry.Entry(
                recording.appId, ref, file, uri, name, "audio/mp4"))) throw IllegalStateException()
            ownedRefs[ref] = recording.appId
            recording.file = null // Ownership has transferred to the media registry.
            val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            format.timeZone = TimeZone.getTimeZone("UTC")
            if (!recording.replied) {
                recording.replied = true
                recording.result.success(mapOf("recordingId" to recording.id, "mediaRef" to ref,
                    "fileName" to name, "mimeType" to "audio/mp4", "bytes" to file.length(),
                    "durationMs" to duration, "codec" to "aac", "sampleRate" to 16000, "channels" to 1,
                    "stopReason" to reason, "recordedAtUtc" to format.format(Date())))
            } else MiniProgramHostMediaRegistry.releaseOwned(recording.appId, ref)
            cleanup(recording)
        } catch (_: Exception) {
            discard(recording, "microphone_operation_failed", "Recording could not be finalized; try recording for at least one second.", terminal = true)
        }
    }

    private fun discard(recording: Recording, code: String, message: String, terminal: Boolean = false) {
        recording.cancelled = true
        if (!recording.replied) {
            recording.replied = true
            recording.result.error(code, message, null)
        }
        if (terminal || !recording.permissionPending) cleanup(recording)
        // Permission-dialog cancellation keeps the guard until its callback.
    }
    private fun cleanup(recording: Recording) {
        if (recording.finished) return
        recording.finished = true
        recording.timeout?.let { handler.removeCallbacks(it) }
        try { if (recording.started) recording.recorder?.stop() } catch (_: Exception) { }
        try { recording.recorder?.release() } catch (_: Exception) { }
        recording.recorder = null
        recording.file?.delete()
        recording.file = null
        if (pending === recording) pending = null
        recordingInProgress.set(false)
    }
}
''';
