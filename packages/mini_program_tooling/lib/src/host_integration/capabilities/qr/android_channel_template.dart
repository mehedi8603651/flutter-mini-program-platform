String buildAndroidQrScannerChannelSource(String packageName) =>
    'package $packageName\n\n'
    r'''import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/** Host-owned QR scanner bridge installed by mini_program_tooling. */
internal class MiniProgramQrScannerChannel :
    FlutterPlugin,
    ActivityAware,
    PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener {
    companion object {
        private const val CHANNEL_NAME = "mini_program/qr_scanner"
        private const val SCAN_REQUEST_CODE = 4210
        private const val CAMERA_PERMISSION_REQUEST_CODE = 4211
        private const val PREFS_NAME = "mini_program_qr_scanner"
        private const val PREF_PERMISSION_REQUESTED = "camera_permission_requested"

        fun register(flutterEngine: FlutterEngine) {
            flutterEngine.plugins.add(MiniProgramQrScannerChannel())
        }
    }

    private data class ScanRequest(
        val scanId: String,
        val miniProgramId: String,
        val allowTorch: Boolean,
        val timeoutMs: Long,
        val result: MethodChannel.Result,
        var cancelled: Boolean = false,
    )

    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pending: ScanRequest? = null
    private var waitingForPermission = false
    private var permissionHadBeenRequested = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(::handleCall)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        failPending("qr_unavailable", "The QR scanner detached from the Flutter engine.")
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        attach(binding)

    override fun onDetachedFromActivityForConfigChanges() {
        detach("QR scanning stopped while Android configuration changed.")
    }

    override fun onDetachedFromActivity() {
        detach("QR scanning stopped because the host activity detached.")
    }

    private fun attach(binding: ActivityPluginBinding) {
        activityBinding?.removeActivityResultListener(this)
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = binding
        activity = binding.activity
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(this)
    }

    private fun detach(message: String) {
        activityBinding?.removeActivityResultListener(this)
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
        failPending("qr_unavailable", message)
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scan" -> scan(call, result)
            "cancel" -> cancel(call, result)
            else -> result.notImplemented()
        }
    }

    private fun scan(call: MethodCall, result: MethodChannel.Result) {
        if (pending != null) {
            result.error(
                "qr_request_in_progress",
                "A QR scan request is already in progress.",
                null,
            )
            return
        }
        val currentActivity = activity
        if (currentActivity == null) {
            result.error(
                "qr_unavailable",
                "QR scanning requires a foreground Android activity.",
                null,
            )
            return
        }
        val arguments = call.arguments as? Map<*, *>
        val scanId = arguments?.get("scanId") as? String
        val miniProgramId = arguments?.get("miniProgramId") as? String
        val allowTorch = arguments?.get("allowTorch") as? Boolean
        val timeoutMs = (arguments?.get("timeoutMs") as? Number)?.toLong()
        if (scanId.isNullOrBlank() || miniProgramId.isNullOrBlank() ||
            allowTorch == null || timeoutMs == null || timeoutMs !in 1_000L..120_000L
        ) {
            result.error("qr_invalid_result", "The QR scan request is invalid.", null)
            return
        }
        val request = ScanRequest(
            scanId = scanId,
            miniProgramId = miniProgramId,
            allowTorch = allowTorch,
            timeoutMs = timeoutMs,
            result = result,
        )
        pending = request
        if (ContextCompat.checkSelfPermission(
                currentActivity,
                Manifest.permission.CAMERA,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            launchScanner(request)
            return
        }
        val preferences = currentActivity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        permissionHadBeenRequested = preferences.getBoolean(
            PREF_PERMISSION_REQUESTED,
            false,
        )
        preferences.edit().putBoolean(PREF_PERMISSION_REQUESTED, true).apply()
        waitingForPermission = true
        ActivityCompat.requestPermissions(
            currentActivity,
            arrayOf(Manifest.permission.CAMERA),
            CAMERA_PERMISSION_REQUEST_CODE,
        )
    }

    private fun launchScanner(request: ScanRequest) {
        val currentActivity = activity
        if (currentActivity == null) {
            failPending(
                "qr_unavailable",
                "QR scanning requires a foreground Android activity.",
            )
            return
        }
        if (request.cancelled) {
            failPending("qr_scan_cancelled", "QR scanning was cancelled.")
            return
        }
        try {
            val intent = Intent(currentActivity, MiniProgramQrScannerActivity::class.java)
                .putExtra(MiniProgramQrScannerActivity.EXTRA_SCAN_ID, request.scanId)
                .putExtra(MiniProgramQrScannerActivity.EXTRA_ALLOW_TORCH, request.allowTorch)
                .putExtra(MiniProgramQrScannerActivity.EXTRA_TIMEOUT_MS, request.timeoutMs)
            currentActivity.startActivityForResult(intent, SCAN_REQUEST_CODE)
        } catch (_: Exception) {
            failPending(
                "qr_unavailable",
                "The Android QR scanner activity could not be opened.",
            )
        }
    }

    private fun cancel(call: MethodCall, result: MethodChannel.Result) {
        val scanId = (call.arguments as? Map<*, *>)?.get("scanId") as? String
        val request = pending
        if (scanId.isNullOrBlank() || request == null || request.scanId != scanId) {
            result.success(false)
            return
        }
        request.cancelled = true
        MiniProgramQrScannerActivity.cancel(scanId)
        if (waitingForPermission) {
            MiniProgramQrScannerActivity.clearPendingCancellation(scanId)
            failPending("qr_scan_cancelled", "QR scanning was cancelled.")
        }
        result.success(true)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != CAMERA_PERMISSION_REQUEST_CODE) return false
        waitingForPermission = false
        val request = pending ?: return true
        if (request.cancelled) {
            failPending("qr_scan_cancelled", "QR scanning was cancelled.")
            return true
        }
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (granted) {
            launchScanner(request)
            return true
        }
        val currentActivity = activity
        val permanentlyDenied = permissionHadBeenRequested &&
            currentActivity != null &&
            !ActivityCompat.shouldShowRequestPermissionRationale(
                currentActivity,
                Manifest.permission.CAMERA,
            )
        failPending(
            if (permanentlyDenied) {
                "qr_permission_denied_permanently"
            } else {
                "qr_permission_denied"
            },
            if (permanentlyDenied) {
                "Camera permission for QR scanning is permanently denied."
            } else {
                "Camera permission for QR scanning was denied."
            },
        )
        return true
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != SCAN_REQUEST_CODE) return false
        val request = pending ?: return true
        pending = null
        waitingForPermission = false
        if (request.cancelled) {
            request.result.error("qr_scan_cancelled", "QR scanning was cancelled.", null)
            return true
        }
        if (resultCode != Activity.RESULT_OK) {
            request.result.error(
                data?.getStringExtra(MiniProgramQrScannerActivity.EXTRA_ERROR_CODE)
                    ?: "qr_scan_cancelled",
                data?.getStringExtra(MiniProgramQrScannerActivity.EXTRA_ERROR_MESSAGE)
                    ?: "QR scanning was cancelled.",
                null,
            )
            return true
        }
        val rawValue = data?.getStringExtra(MiniProgramQrScannerActivity.EXTRA_RAW_VALUE)
        val valueType = data?.getStringExtra(MiniProgramQrScannerActivity.EXTRA_VALUE_TYPE)
        val scannedAtUtc = data?.getStringExtra(
            MiniProgramQrScannerActivity.EXTRA_SCANNED_AT_UTC,
        )
        if (rawValue.isNullOrEmpty() || valueType.isNullOrBlank() ||
            scannedAtUtc.isNullOrBlank()
        ) {
            request.result.error(
                "qr_invalid_result",
                "Android returned an invalid QR scan result.",
                null,
            )
            return true
        }
        request.result.success(
            mapOf(
                "rawValue" to rawValue,
                "format" to "qr",
                "valueType" to valueType,
                "scannedAtUtc" to scannedAtUtc,
            ),
        )
        return true
    }

    private fun failPending(code: String, message: String) {
        val request = pending ?: return
        pending = null
        waitingForPermission = false
        request.result.error(code, message, null)
    }
}
''';

String buildAndroidQrScannerActivitySource(String packageName) =>
    'package $packageName\n\n'
    r'''import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.lang.ref.WeakReference
import java.text.SimpleDateFormat
import java.util.Collections
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** CameraX and bundled ML Kit QR-only scanner owned by the host. */
internal class MiniProgramQrScannerActivity : ComponentActivity() {
    companion object {
        const val EXTRA_SCAN_ID = "scanId"
        const val EXTRA_ALLOW_TORCH = "allowTorch"
        const val EXTRA_TIMEOUT_MS = "timeoutMs"
        const val EXTRA_RAW_VALUE = "rawValue"
        const val EXTRA_VALUE_TYPE = "valueType"
        const val EXTRA_SCANNED_AT_UTC = "scannedAtUtc"
        const val EXTRA_ERROR_CODE = "errorCode"
        const val EXTRA_ERROR_MESSAGE = "errorMessage"

        private var active = WeakReference<MiniProgramQrScannerActivity>(null)
        private val cancelledBeforeStart = Collections.synchronizedSet(
            mutableSetOf<String>(),
        )

        fun cancel(scanId: String): Boolean {
            val current = active.get()
            if (current != null && current.scanId == scanId) {
                current.runOnUiThread {
                    current.finishWithError(
                        "qr_scan_cancelled",
                        "QR scanning was cancelled.",
                    )
                }
                return true
            }
            cancelledBeforeStart.add(scanId)
            return true
        }

        fun clearPendingCancellation(scanId: String) {
            cancelledBeforeStart.remove(scanId)
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val analysisExecutor = Executors.newSingleThreadExecutor()
    private val analyzing = AtomicBoolean(false)
    private val completed = AtomicBoolean(false)
    private lateinit var scanner: BarcodeScanner
    private lateinit var previewView: PreviewView
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var torchButton: TextView? = null
    private var torchEnabled = false
    private var scanId = ""

    private val timeoutRunnable = Runnable {
        finishWithError("qr_timeout", "The QR scan request timed out.")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        scanId = intent.getStringExtra(EXTRA_SCAN_ID).orEmpty()
        val timeoutMs = intent.getLongExtra(EXTRA_TIMEOUT_MS, 60_000L)
        if (scanId.isBlank() || timeoutMs !in 1_000L..120_000L) {
            finishWithError("qr_invalid_result", "The QR scan request is invalid.")
            return
        }
        if (active.get() != null) {
            finishWithError(
                "qr_camera_in_use",
                "Another QR scanner is already using the camera.",
            )
            return
        }
        active = WeakReference(this)
        if (cancelledBeforeStart.remove(scanId)) {
            finishWithError("qr_scan_cancelled", "QR scanning was cancelled.")
            return
        }
        scanner = BarcodeScanning.getClient(
            BarcodeScannerOptions.Builder()
                .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
                .build(),
        )
        buildUserInterface(intent.getBooleanExtra(EXTRA_ALLOW_TORCH, false))
        mainHandler.postDelayed(timeoutRunnable, timeoutMs)
        startCamera()
    }

    private fun buildUserInterface(allowTorch: Boolean) {
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        previewView = PreviewView(this).apply {
            scaleType = PreviewView.ScaleType.FILL_CENTER
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        }
        root.addView(
            previewView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        root.addView(
            control("Close") {
                finishWithError("qr_scan_cancelled", "QR scanning was cancelled.")
            },
            controlLayout(Gravity.TOP or Gravity.START),
        )
        if (allowTorch) {
            torchButton = control("Light") { toggleTorch() }
            root.addView(torchButton, controlLayout(Gravity.TOP or Gravity.END))
        }
        val hint = TextView(this).apply {
            text = "Place a QR code inside the camera view"
            setTextColor(Color.WHITE)
            textSize = 17f
            gravity = Gravity.CENTER
            setPadding(32, 20, 32, 20)
            setBackgroundColor(0x99000000.toInt())
        }
        root.addView(
            hint,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            ).apply { setMargins(32, 32, 32, 64) },
        )
        setContentView(root)
    }

    private fun control(label: String, onTap: () -> Unit): TextView =
        TextView(this).apply {
            text = label
            contentDescription = label
            setTextColor(Color.WHITE)
            textSize = 16f
            gravity = Gravity.CENTER
            setPadding(24, 16, 24, 16)
            setBackgroundColor(0x99000000.toInt())
            setOnClickListener { onTap() }
        }

    private fun controlLayout(gravity: Int) = FrameLayout.LayoutParams(
        ViewGroup.LayoutParams.WRAP_CONTENT,
        ViewGroup.LayoutParams.WRAP_CONTENT,
        gravity,
    ).apply { setMargins(24, 32, 24, 24) }

    private fun startCamera() {
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener(
            {
                if (completed.get()) return@addListener
                try {
                    val provider = future.get()
                    cameraProvider = provider
                    val preview = Preview.Builder().build().also {
                        it.setSurfaceProvider(previewView.surfaceProvider)
                    }
                    val analysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                    analysis.setAnalyzer(analysisExecutor, ::analyze)
                    provider.unbindAll()
                    camera = provider.bindToLifecycle(
                        this,
                        CameraSelector.DEFAULT_BACK_CAMERA,
                        preview,
                        analysis,
                    )
                    if (camera?.cameraInfo?.hasFlashUnit() != true) {
                        torchButton?.visibility = android.view.View.GONE
                    }
                } catch (_: SecurityException) {
                    finishWithError(
                        "qr_permission_denied",
                        "Camera permission for QR scanning was denied.",
                    )
                } catch (_: Exception) {
                    finishWithError(
                        "qr_camera_in_use",
                        "The camera is unavailable or already in use.",
                    )
                }
            },
            ContextCompat.getMainExecutor(this),
        )
    }

    @androidx.annotation.OptIn(
        markerClass = [androidx.camera.core.ExperimentalGetImage::class],
    )
    private fun analyze(imageProxy: ImageProxy) {
        if (completed.get() || !analyzing.compareAndSet(false, true)) {
            imageProxy.close()
            return
        }
        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            analyzing.set(false)
            imageProxy.close()
            return
        }
        val image = InputImage.fromMediaImage(
            mediaImage,
            imageProxy.imageInfo.rotationDegrees,
        )
        scanner.process(image)
            .addOnSuccessListener { barcodes ->
                val barcode = barcodes.firstOrNull { !it.rawValue.isNullOrEmpty() }
                if (barcode != null) finishWithSuccess(barcode)
            }
            .addOnCompleteListener {
                analyzing.set(false)
                imageProxy.close()
            }
    }

    private fun toggleTorch() {
        val activeCamera = camera ?: return
        if (activeCamera.cameraInfo.hasFlashUnit() != true) return
        val next = !torchEnabled
        val future = activeCamera.cameraControl.enableTorch(next)
        future.addListener(
            {
                try {
                    future.get()
                    torchEnabled = next
                    torchButton?.text = if (next) "Light off" else "Light"
                } catch (_: Exception) {
                    torchEnabled = false
                    torchButton?.text = "Light"
                }
            },
            ContextCompat.getMainExecutor(this),
        )
    }

    private fun finishWithSuccess(barcode: Barcode) {
        val rawValue = barcode.rawValue ?: return
        if (!completed.compareAndSet(false, true)) return
        setResult(
            Activity.RESULT_OK,
            Intent()
                .putExtra(EXTRA_RAW_VALUE, rawValue)
                .putExtra(EXTRA_VALUE_TYPE, valueType(barcode.valueType))
                .putExtra(EXTRA_SCANNED_AT_UTC, utcTimestamp()),
        )
        finish()
    }

    private fun finishWithError(code: String, message: String) {
        if (!completed.compareAndSet(false, true)) return
        setResult(
            Activity.RESULT_CANCELED,
            Intent()
                .putExtra(EXTRA_ERROR_CODE, code)
                .putExtra(EXTRA_ERROR_MESSAGE, message),
        )
        finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        finishWithError("qr_scan_cancelled", "QR scanning was cancelled.")
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(timeoutRunnable)
        try {
            camera?.cameraControl?.enableTorch(false)
            cameraProvider?.unbindAll()
        } catch (_: Exception) {
            // Lifecycle cleanup is best effort.
        }
        if (::scanner.isInitialized) scanner.close()
        analysisExecutor.shutdownNow()
        if (active.get() === this) active.clear()
        super.onDestroy()
    }

    private fun valueType(type: Int): String = when (type) {
        Barcode.TYPE_URL -> "url"
        Barcode.TYPE_WIFI -> "wifi"
        Barcode.TYPE_CONTACT_INFO -> "contact"
        Barcode.TYPE_EMAIL -> "email"
        Barcode.TYPE_PHONE -> "phone"
        Barcode.TYPE_SMS -> "sms"
        Barcode.TYPE_GEO -> "geo"
        Barcode.TYPE_CALENDAR_EVENT -> "calendar"
        Barcode.TYPE_DRIVER_LICENSE -> "driverLicense"
        Barcode.TYPE_TEXT -> "text"
        else -> "unknown"
    }

    private fun utcTimestamp(): String = SimpleDateFormat(
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        Locale.US,
    ).apply { timeZone = TimeZone.getTimeZone("UTC") }.format(Date())
}
''';
