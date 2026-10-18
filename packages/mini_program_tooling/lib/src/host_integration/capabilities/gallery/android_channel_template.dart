String buildAndroidGalleryChannelSource(String packageName) =>
    'package $packageName\n\n$_androidGalleryChannelSource';

const String _androidGalleryChannelSource = r'''import android.os.Build
import android.provider.MediaStore
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import androidx.lifecycle.Lifecycle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** Tooling-generated Android Photo Picker. Native locations never leave the host. */
internal class MiniProgramGalleryChannel : FlutterPlugin, ActivityAware {
    companion object {
        private const val CHANNEL_NAME = "mini_program/gallery"
        // Shared by every Flutter engine/task in this host process.
        private val selectionInProgress = AtomicBoolean(false)
        private val cleanedPreviousProcess = AtomicBoolean(false)
        fun register(flutterEngine: FlutterEngine) {
            flutterEngine.plugins.add(MiniProgramGalleryChannel())
        }
    }

    private data class Selection(
        val id: String, val appId: String, val maxImages: Int,
        val maxImageBytes: Long, val maxTotalBytes: Long,
        val maxWidth: Int, val maxHeight: Int, val quality: Int,
        val result: MethodChannel.Result,
        val cancelled: AtomicBoolean = AtomicBoolean(false),
        val replied: AtomicBoolean = AtomicBoolean(false),
        val finished: AtomicBoolean = AtomicBoolean(false),
    )
    private class GalleryFailure(val code: String, override val message: String) : Exception(message)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var context: Context? = null
    private var activity: ComponentActivity? = null
    private var channel: MethodChannel? = null
    private var launcher: ActivityResultLauncher<PickVisualMediaRequest>? = null
    private var pending: Selection? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(::handleCall)
        }
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detach()
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
        worker.shutdown()
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { attach(binding) }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { attach(binding) }
    override fun onDetachedFromActivityForConfigChanges() { detach() }
    override fun onDetachedFromActivity() { detach() }
    private fun attach(binding: ActivityPluginBinding) {
        activity = binding.activity as? ComponentActivity
    }
    private fun detach() {
        pending?.let {
            it.cancelled.set(true)
            fail(it, "gallery_unavailable", "The host activity detached during photo selection.")
            finish(it)
        }
        launcher?.unregister()
        launcher = null
        activity = null
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickImages" -> pickImages(call, result)
            "cancel" -> {
                val id = call.argument<String>("selectionId")
                val selection = pending
                if (selection == null || selection.id != id) {
                    result.success(false)
                } else {
                    selection.cancelled.set(true)
                    fail(selection, "gallery_selection_cancelled", "Photo selection was cancelled.")
                    // Retain the native guard until the picker actually returns.
                    result.success(true)
                }
            }
            "loadPreview" -> loadPreview(call, result)
            "releaseMedia" -> {
                val appId = call.argument<String>("miniProgramId")
                val ref = call.argument<String>("mediaRef")
                result.success(appId != null && ref != null &&
                    MiniProgramHostMediaRegistry.releaseOwned(appId, ref))
            }
            else -> result.notImplemented()
        }
    }

    private fun pickImages(call: MethodCall, result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null ||
            !currentActivity.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) {
            result.error("gallery_unavailable", "Photo selection requires a foreground activity.", null)
            return
        }
        val args = call.arguments as? Map<*, *>
        val id = args?.get("selectionId") as? String
        val appId = args?.get("miniProgramId") as? String
        val count = (args?.get("maxImages") as? Number)?.toInt()
        val imageBytes = (args?.get("maxImageBytes") as? Number)?.toLong()
        val totalBytes = (args?.get("maxTotalBytes") as? Number)?.toLong()
        val width = (args?.get("maxWidth") as? Number)?.toInt()
        val height = (args?.get("maxHeight") as? Number)?.toInt()
        val quality = (args?.get("quality") as? Number)?.toInt()
        if (id.isNullOrBlank() || id.length > 160 || appId.isNullOrBlank() || appId.length > 512 ||
            count == null || count !in 1..30 || imageBytes == null || imageBytes !in 1..104857600L ||
            totalBytes == null || totalBytes !in 1..314572800L ||
            width == null || width !in 64..8192 || height == null || height !in 64..8192 ||
            quality == null || quality !in 1..100) {
            result.error("gallery_invalid_request", "The photo selection request is invalid.", null)
            return
        }
        if (!selectionInProgress.compareAndSet(false, true)) {
            result.error("gallery_request_in_progress", "Another photo selection is already open.", null)
            return
        }
        val selection = Selection(id, appId, count, imageBytes, totalBytes, width, height, quality, result)
        pending = selection
        try {
            // These contracts use the system/backported Photo Picker and fall back
            // to ACTION_OPEN_DOCUMENT when no Photo Picker is available.
            val pickerCount = if (Build.VERSION.SDK_INT >= 33) {
                min(count, MediaStore.getPickImagesMaxLimit())
            } else count
            launcher = if (pickerCount == 1) {
                currentActivity.activityResultRegistry.register(
                    "mini_program_gallery_$id", ActivityResultContracts.PickVisualMedia(),
                ) { uri -> completeSelection(listOfNotNull(uri)) }
            } else {
                currentActivity.activityResultRegistry.register(
                    "mini_program_gallery_$id", ActivityResultContracts.PickMultipleVisualMedia(pickerCount),
                    ::completeSelection,
                )
            }
            launcher!!.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        } catch (_: Exception) {
            fail(selection, "gallery_unavailable", "Android could not open the photo picker.")
            finish(selection)
        }
    }

    private fun completeSelection(uris: List<Uri>) {
        val selection = pending ?: return
        launcher?.unregister()
        launcher = null
        if (selection.cancelled.get() || uris.isEmpty()) {
            fail(selection, "gallery_selection_cancelled", "Photo selection was cancelled.")
            finish(selection)
            return
        }
        if (uris.size > selection.maxImages || uris.distinct().size != uris.size) {
            fail(selection, "gallery_limit_exceeded", "Too many photos were selected.")
            finish(selection)
            return
        }
        val appContext = context
        if (appContext == null) {
            fail(selection, "gallery_unavailable", "The gallery provider is unavailable.")
            finish(selection)
            return
        }
        worker.execute {
            val refs = mutableListOf<String>()
            var images: List<Map<String, Any>> = emptyList()
            var failure: GalleryFailure? = null
            try {
                // Dart references do not survive process death. Remove orphaned
                // gallery copies once, retaining every live same-process entry.
                if (cleanedPreviousProcess.compareAndSet(false, true)) {
                    File(appContext.cacheDir, "mini_program_gallery").listFiles()?.forEach { file ->
                        if (file.name.matches(Regex("[0-9a-f-]{36}\\.(jpg|input)")) &&
                            MiniProgramHostMediaRegistry.find("gallery_${file.nameWithoutExtension}") == null) {
                            file.delete()
                        }
                    }
                }
                var inputTotal = 0L
                var outputTotal = 0L
                images = uris.map { uri ->
                    ensureNotCancelled(selection)
                    val (image, inputBytes) = importImage(appContext, selection, uri,
                        selection.maxTotalBytes - inputTotal)
                    val ref = image["mediaRef"] as String
                    refs.add(ref)
                    inputTotal += inputBytes
                    outputTotal += image["bytes"] as Long
                    if (outputTotal > selection.maxTotalBytes) {
                        throw GalleryFailure("gallery_limit_exceeded", "The photos exceed the total size limit.")
                    }
                    image
                }
                ensureNotCancelled(selection)
            } catch (error: GalleryFailure) {
                failure = error
            } catch (_: OutOfMemoryError) {
                failure = GalleryFailure("gallery_unsupported_image", "A selected image is too large to decode.")
            } catch (_: Exception) {
                failure = GalleryFailure("gallery_operation_failed", "A selected photo could not be imported.")
            }
            mainHandler.post {
                if (failure != null || selection.cancelled.get()) {
                    refs.forEach { MiniProgramHostMediaRegistry.releaseOwned(selection.appId, it) }
                    val error = failure ?: GalleryFailure("gallery_selection_cancelled", "Photo selection was cancelled.")
                    fail(selection, error.code, error.message)
                } else if (selection.replied.compareAndSet(false, true)) {
                    val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
                    dateFormat.timeZone = TimeZone.getTimeZone("UTC")
                    selection.result.success(mapOf(
                        "selectionId" to selection.id, "images" to images,
                        "selectedAtUtc" to dateFormat.format(Date()),
                    ))
                } else {
                    refs.forEach { MiniProgramHostMediaRegistry.releaseOwned(selection.appId, it) }
                }
                finish(selection)
            }
        }
    }

    private fun importImage(appContext: Context, selection: Selection, uri: Uri,
        remainingInputBytes: Long): Pair<Map<String, Any>, Long> {
        if (uri.scheme != "content") {
            throw GalleryFailure("gallery_unsupported_image", "The photo picker returned an unsupported item.")
        }
        val directory = File(appContext.cacheDir, "mini_program_gallery")
        if ((!directory.exists() && !directory.mkdirs()) ||
            StatFs(appContext.cacheDir.absolutePath).availableBytes < 64L * 1024 * 1024) {
            throw GalleryFailure("gallery_storage_unavailable", "There is not enough space to import photos.")
        }
        val id = UUID.randomUUID().toString()
        val sourceFile = File(directory, "$id.input")
        val outputFile = File(directory, "$id.jpg")
        var registered = false
        var bitmap: Bitmap? = null
        try {
            val limit = min(selection.maxImageBytes, remainingInputBytes)
            var inputBytes = 0L
            val input = appContext.contentResolver.openInputStream(uri)
                ?: throw GalleryFailure("gallery_unsupported_image", "A selected photo is unavailable.")
            input.use { stream ->
                FileOutputStream(sourceFile).use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        ensureNotCancelled(selection)
                        val read = stream.read(buffer)
                        if (read == -1) break
                        inputBytes += read
                        if (inputBytes > limit) {
                            throw GalleryFailure("gallery_limit_exceeded", "The selected photos exceed accepted size limits.")
                        }
                        output.write(buffer, 0, read)
                    }
                }
            }
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(sourceFile.absolutePath, bounds)
            if (bounds.outWidth !in 1..65535 || bounds.outHeight !in 1..65535) {
                throw GalleryFailure("gallery_unsupported_image", "A selected item is not a supported photo.")
            }
            var sample = 1
            val maxDimension = max(selection.maxWidth, selection.maxHeight)
            while ((bounds.outWidth / sample).toLong() * (bounds.outHeight / sample) > 16L * 1024 * 1024 ||
                bounds.outWidth / sample > maxDimension * 2 || bounds.outHeight / sample > maxDimension * 2) {
                sample *= 2
            }
            bitmap = BitmapFactory.decodeFile(sourceFile.absolutePath,
                BitmapFactory.Options().apply { inSampleSize = sample; inPreferredConfig = Bitmap.Config.ARGB_8888 })
                ?: throw GalleryFailure("gallery_unsupported_image", "A selected photo could not be decoded.")
            val orientation = try {
                ExifInterface(sourceFile.absolutePath).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            } catch (_: Exception) { ExifInterface.ORIENTATION_NORMAL }
            val matrix = Matrix()
            when (orientation) {
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.setScale(-1f, 1f)
                ExifInterface.ORIENTATION_ROTATE_180 -> matrix.setRotate(180f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.setScale(1f, -1f)
                ExifInterface.ORIENTATION_TRANSPOSE -> { matrix.setRotate(90f); matrix.postScale(-1f, 1f) }
                ExifInterface.ORIENTATION_ROTATE_90 -> matrix.setRotate(90f)
                ExifInterface.ORIENTATION_TRANSVERSE -> { matrix.setRotate(270f); matrix.postScale(-1f, 1f) }
                ExifInterface.ORIENTATION_ROTATE_270 -> matrix.setRotate(270f)
            }
            if (!matrix.isIdentity) {
                val oriented = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
                if (oriented !== bitmap) { bitmap.recycle(); bitmap = oriented }
            }
            val scale = min(1.0, min(selection.maxWidth.toDouble() / bitmap.width,
                selection.maxHeight.toDouble() / bitmap.height))
            if (scale < 1.0) {
                val resized = Bitmap.createScaledBitmap(bitmap, max(1, (bitmap.width * scale).roundToInt()),
                    max(1, (bitmap.height * scale).roundToInt()), true)
                if (resized !== bitmap) { bitmap.recycle(); bitmap = resized }
            }
            ensureNotCancelled(selection)
            FileOutputStream(outputFile).use {
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, selection.quality, it)) {
                    throw GalleryFailure("gallery_operation_failed", "A selected photo could not be encoded.")
                }
            }
            if (outputFile.length() <= 0 || outputFile.length() > selection.maxImageBytes) {
                throw GalleryFailure("gallery_limit_exceeded", "A processed photo exceeds the accepted size limit.")
            }
            ensureNotCancelled(selection)
            val ref = "gallery_$id"
            val fileName = "photo_$id.jpg"
            val outputUri = FileProvider.getUriForFile(appContext,
                appContext.packageName + ".mini_program_gallery_files", outputFile)
            if (!MiniProgramHostMediaRegistry.register(MiniProgramHostMediaRegistry.Entry(
                selection.appId, ref, outputFile, outputUri, fileName, "image/jpeg"))) {
                throw GalleryFailure("gallery_operation_failed", "The selected photo could not be registered.")
            }
            registered = true
            return mapOf<String, Any>("mediaRef" to ref, "fileName" to fileName,
                "mimeType" to "image/jpeg", "bytes" to outputFile.length(),
                "width" to bitmap.width, "height" to bitmap.height, "source" to "gallery") to inputBytes
        } finally {
            bitmap?.recycle()
            sourceFile.delete()
            if (!registered) outputFile.delete()
        }
    }

    private fun loadPreview(call: MethodCall, result: MethodChannel.Result) {
        val appId = call.argument<String>("miniProgramId")
        val ref = call.argument<String>("mediaRef")
        val maximum = call.argument<Number>("maxBytes")?.toLong() ?: 16777216L
        val entry = if (appId != null && ref != null) MiniProgramHostMediaRegistry.findOwned(appId, ref) else null
        if (entry == null) {
            result.error("media_not_owned", "The photo is not owned by this mini-program.", null)
            return
        }
        worker.execute {
            try {
                if (maximum !in 1..16777216L || entry.size <= 0 || entry.size > maximum) {
                    mainHandler.post { result.error("media_preview_too_large", "The photo exceeds the preview limit.", null) }
                } else {
                    val bytes = entry.file.readBytes()
                    mainHandler.post { result.success(mapOf("mediaRef" to entry.mediaRef,
                        "mimeType" to entry.mimeType, "bytes" to bytes)) }
                }
            } catch (_: Exception) {
                mainHandler.post { result.error("media_not_found", "The selected photo is no longer available.", null) }
            }
        }
    }
    private fun ensureNotCancelled(selection: Selection) {
        if (selection.cancelled.get()) {
            throw GalleryFailure("gallery_selection_cancelled", "Photo selection was cancelled.")
        }
    }
    private fun fail(selection: Selection, code: String, message: String) {
        if (selection.replied.compareAndSet(false, true)) selection.result.error(code, message, null)
    }
    private fun finish(selection: Selection) {
        if (selection.finished.compareAndSet(false, true)) {
            if (pending === selection) {
                pending = null
                launcher?.unregister()
                launcher = null
            }
            selectionInProgress.set(false)
        }
    }
}
''';
