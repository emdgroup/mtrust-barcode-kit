package com.emddigital.mtrust_barcode_kit


import BarcodeFormat
import BarcodeKitFlutterApi
import BarcodeKitHostApi

import CameraLensDirection
import CameraOpenResponse
import CornerPoint
import DetectedBarcode
import android.annotation.SuppressLint
import android.graphics.Rect
import android.graphics.RectF
import android.media.Image
import android.os.Build
import android.util.Log
import android.view.Surface
import androidx.annotation.RequiresApi
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.TorchState
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.util.concurrent.Executor


val barcodeFormatMap = hashMapOf<BarcodeFormat, Int>(
    BarcodeFormat.AZTEC to Barcode.FORMAT_AZTEC,
    BarcodeFormat.CODABAR to Barcode.FORMAT_CODABAR,
    BarcodeFormat.CODE39 to Barcode.FORMAT_CODE_39,
    BarcodeFormat.CODE93 to Barcode.FORMAT_CODE_93,
    BarcodeFormat.CODE128 to Barcode.FORMAT_CODE_128,
    BarcodeFormat.DATA_MATRIX to Barcode.FORMAT_DATA_MATRIX,
    BarcodeFormat.EAN8 to Barcode.FORMAT_EAN_8,
    BarcodeFormat.EAN13 to Barcode.FORMAT_EAN_13,
    BarcodeFormat.PDF417 to Barcode.FORMAT_PDF417,
    BarcodeFormat.QR_CODE to Barcode.FORMAT_QR_CODE,
    BarcodeFormat.UPC_A to Barcode.FORMAT_UPC_A,
    BarcodeFormat.UPC_E to Barcode.FORMAT_UPC_E,
    BarcodeFormat.ITF to Barcode.FORMAT_ITF
)

val barcodeFormatsReversed = barcodeFormatMap.entries.associateBy({ it.value }, { it.key })

/** BarcodeKitPlugin */
class BarcodeKitPlugin : FlutterPlugin, BarcodeKitHostApi, ActivityAware {


    // Flutter
    private var activity: ActivityPluginBinding? = null
    private var flutter: FlutterPlugin.FlutterPluginBinding? = null
    private lateinit var channel: MethodChannel
    private var flutterApi: BarcodeKitFlutterApi? = null

    // Camera related
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var preview: Preview? = null
    private var analysis: ImageAnalysis? = null
    private var cameraSelector: CameraSelector? = null

    // Surface for preview
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null

    private var ocrEnabled = false


    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        // Keep a reference to the binding
        flutter = flutterPluginBinding
        flutterApi = BarcodeKitFlutterApi(flutterPluginBinding.binaryMessenger)
        BarcodeKitHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Close the pigeon api
        BarcodeKitHostApi.setUp(binding.binaryMessenger, null)

        flutterApi = null
        // Remove reference
        flutter = null

    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        // Keep binding to activity
        activity = binding
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        // Keep binding
        onAttachedToActivity(binding)
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    override fun onDetachedFromActivity() {
        // Close the camera while the activity reference is still available,
        // then remove the reference.
        closeCamera()
        activity = null
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()

    }


    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun makePreviewSurface(executor: Executor){


        // Preview
        val surfaceProvider = Preview.SurfaceProvider { request ->
            val resolution = request.resolution
            val texture = textureEntry!!.surfaceTexture()
            texture.setDefaultBufferSize(resolution.width, resolution.height)
            val surface = Surface(texture)
            request.provideSurface(surface, executor) { }
        }
        preview = Preview.Builder().build().apply { setSurfaceProvider(surfaceProvider) }
        textureEntry = flutter!!.textureRegistry.createSurfaceTexture()

    }

    fun buildDetectors(formats: List<Long>) : Pair<BarcodeScanner, TextRecognizer>{
        val options = BarcodeScannerOptions.Builder()

        if (formats.isNotEmpty()) {

            val formattedFormats = formats.map<Long, Int> { format ->
                barcodeFormatMap[BarcodeFormat.values().first { format.toInt() == it.raw }]!!
            }
            if (formats.size > 1) {
                options.setBarcodeFormats(
                    formattedFormats.first(),
                    *formattedFormats.subList(1, formattedFormats.lastIndex).toIntArray()
                )
            } else {
                options.setBarcodeFormats(formattedFormats.first())
            }
        }

        val barcodeScanner = BarcodeScanning.getClient(options.build())
        val textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        return Pair(barcodeScanner, textRecognizer)
    }



    // Open the camera and attach an MlKit analyzer
    @SuppressLint("UnsafeOptInUsageError", "RestrictedApi")
    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    override fun openCamera(
        direction: CameraLensDirection,
        formats: List<Long>,
        fallbackDirections: List<CameraLensDirection>,
        callback: (Result<CameraOpenResponse>) -> Unit
    ) {
        // Close potential existing camera instance
        closeCamera()

        val future = ProcessCameraProvider.getInstance(activity!!.activity)
        val executor = ContextCompat.getMainExecutor(activity!!.activity)

        future.addListener({
            cameraProvider = future.get()
            makePreviewSurface(executor)

             val detectors = buildDetectors(formats)

            val analyzer = MaskedAnalyzer(detectors.first, detectors.second)

            analysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build().apply { setAnalyzer(executor, analyzer) }
            // Bind to lifecycle.

            // Build camera selector with fallback logic
            var cameraSelectorBuilder = CameraSelector.Builder()
            
            // Try to get the requested camera direction, with fallback to provided fallback directions
            val directionsToTry = mutableListOf(direction)
            directionsToTry.addAll(fallbackDirections)
            
            var foundCamera = false
            
            for (directionToTry in directionsToTry) {
                try {
                    cameraSelectorBuilder = CameraSelector.Builder()
                    cameraSelectorBuilder = when (directionToTry) {
                        CameraLensDirection.BACK -> cameraSelectorBuilder.requireLensFacing(CameraSelector.LENS_FACING_BACK)
                        CameraLensDirection.EXT -> cameraSelectorBuilder.requireLensFacing(CameraSelector.LENS_FACING_EXTERNAL)
                        CameraLensDirection.FRONT -> cameraSelectorBuilder.requireLensFacing(CameraSelector.LENS_FACING_FRONT)
                        CameraLensDirection.UNKNOWN -> cameraSelectorBuilder
                    }
                    
                    val potentialSelector = cameraSelectorBuilder.build()
                    
                    // Check if this camera is available
                    if (cameraProvider!!.hasCamera(potentialSelector)) {
                        cameraSelector = potentialSelector
                        foundCamera = true
                        break
                    }
                } catch (e: Exception) {
                    // Continue to next direction
                    continue
                }
            }
            
            if (!foundCamera) {
                callback(Result.failure(RuntimeException("No suitable camera available from the provided directions")))
                return@addListener
            }

            val camera = attachCamera()

            @SuppressLint("RestrictedApi")
            val resolution = preview!!.attachedSurfaceResolution!!
            val portrait = camera.cameraInfo.sensorRotationDegrees % 180 == 0
            val width = if (portrait) resolution.width.toLong() else resolution.height.toLong()
            val height = if (portrait) resolution.height.toLong() else resolution.width.toLong()


            callback(
                Result.success(
                    CameraOpenResponse(
                        supportsFlash = camera.cameraInfo.hasFlashUnit(),
                        height = height,
                        width = width,
                        textureId = textureEntry!!.id().toString()
                    )
                )
            )
        }, executor)
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun attachCamera(): Camera{
        val owner = activity!!.activity as LifecycleOwner
        val camera = cameraProvider!!.bindToLifecycle(owner, cameraSelector!!, preview, analysis)
        camera.cameraInfo.torchState.observe(owner) { state ->
            flutterApi?.onTorchStateChanged(state == TorchState.ON) {}
        }

        this.camera = camera

        return camera
    }

    private fun handleBarcodes(barcodes: List<Barcode>?) {
        if (barcodes.isNullOrEmpty()) return
        for (barcode: Barcode in barcodes) {
            flutterApi?.onBarcodeScanned(
                DetectedBarcode(
                    rawValue = barcode.rawValue,
                    format = barcodeFormatsReversed[barcode.format],
                    cornerPoints = barcode.cornerPoints!!.map { point ->
                        CornerPoint(point.x.toDouble(), point.y.toDouble())
                    }
                )
            ) {}
        }
    }

    private fun handleText(text: Text?) {
        if (text == null) return
        for (block in text.textBlocks) {
            for (line in block.lines) {
                flutterApi?.onTextDetected(line.text) {}
            }
        }
    }

    /**
     * SPIKE: custom [ImageAnalysis.Analyzer] that restricts OCR to a region of
     * the frame instead of the ML Kit-managed [androidx.camera.mlkit.vision.MlKitAnalyzer],
     * which always evaluates every attached detector against the full frame.
     *
     * Barcode detection still runs on the full frame (unchanged behaviour).
     * Text recognition is restricted to [ocrRegion] by mutating the underlying
     * [Image.cropRect] before wrapping it in a second [InputImage] - ML Kit's
     * internal YUV -> Bitmap conversion honours `Image.cropRect`, so the
     * recognizer only ever sees/decodes the cropped region rather than the
     * full frame. This is what actually saves CPU, vs. detecting on the full
     * frame and merely filtering results afterwards.
     *
     * NOTE - this is a proof of concept, not production ready:
     *  - [ocrRegion] is hardcoded (normalized, in "display/rotated" space,
     *    i.e. what the user sees in the mask cutout). Wiring the real mask
     *    rect from `BarcodeKitView` requires a new Pigeon message from Dart
     *    (e.g. extending `setOCREnabled` or a new `setOcrRegion(Rect)` call)
     *    computed from `maskWidth`/`maskHeight` vs. the preview's rendered
     *    size/aspect ratio.
     *  - The rotation -> sensor-space mapping in [computeCropRect] needs
     *    verification on real devices (front vs back camera, 0/90/180/270
     *    sensor rotation) before this ships.
     *  - Two separate ML Kit calls (barcode + text) now run instead of one
     *    combined `MlKitAnalyzer` pass; frame lifetime (`imageProxy.close()`)
     *    is now our responsibility and is deferred until both tasks finish.
     */
    private inner class MaskedAnalyzer(
        private val barcodeScanner: BarcodeScanner,
        private val textRecognizer: TextRecognizer
    ) : ImageAnalysis.Analyzer {

        // TODO: replace with the real mask rect, piped in from Dart via Pigeon.
        // Normalized (0..1) rect, in the orientation the user sees on screen.
        var ocrRegion = RectF(0.15f, 0.35f, 0.85f, 0.65f)

        @SuppressLint("UnsafeOptInUsageError")
        override fun analyze(imageProxy: ImageProxy) {
            val mediaImage = imageProxy.image
            if (mediaImage == null) {
                imageProxy.close()
                return
            }

            val rotationDegrees = imageProxy.imageInfo.rotationDegrees

            // Barcode detection: full frame, default crop rect.
            mediaImage.cropRect = Rect(0, 0, mediaImage.width, mediaImage.height)
            val barcodeTask: Task<List<Barcode>> =
                barcodeScanner.process(InputImage.fromMediaImage(mediaImage, rotationDegrees))

            // Text recognition: only the masked region, if OCR is enabled.
            val textTask: Task<Text>? = if (ocrEnabled) {
                val cropRect = computeCropRect(mediaImage, rotationDegrees, ocrRegion)
                mediaImage.cropRect = cropRect
                textRecognizer.process(InputImage.fromMediaImage(mediaImage, rotationDegrees))
            } else {
                null
            }

            val tasks = mutableListOf<Task<*>>(barcodeTask)
            if (textTask != null) tasks.add(textTask)

            Tasks.whenAllComplete(tasks).addOnCompleteListener {
                if (barcodeTask.isSuccessful) {
                    handleBarcodes(barcodeTask.result)
                }
                if (textTask?.isSuccessful == true) {
                    handleText(textTask.result)
                }
                imageProxy.close()
            }
        }

        /**
         * Maps a normalized rect defined in "display/rotated" space (i.e. what
         * the mask cutout looks like to the user, independent of sensor
         * rotation) back into the raw sensor buffer's coordinate space, then
         * into pixel coordinates clamped to the image bounds.
         */
        private fun computeCropRect(mediaImage: Image, rotationDegrees: Int, normalized: RectF): Rect {
            val imageWidth = mediaImage.width
            val imageHeight = mediaImage.height

            val rotated = when (rotationDegrees) {
                90 -> RectF(
                    normalized.top, 1f - normalized.right,
                    normalized.bottom, 1f - normalized.left
                )
                180 -> RectF(
                    1f - normalized.right, 1f - normalized.bottom,
                    1f - normalized.left, 1f - normalized.top
                )
                270 -> RectF(
                    1f - normalized.bottom, normalized.left,
                    1f - normalized.top, normalized.right
                )
                else -> normalized
            }

            val left = (rotated.left * imageWidth).toInt().coerceIn(0, imageWidth)
            val top = (rotated.top * imageHeight).toInt().coerceIn(0, imageHeight)
            var right = (rotated.right * imageWidth).toInt().coerceIn(left, imageWidth)
            var bottom = (rotated.bottom * imageHeight).toInt().coerceIn(top, imageHeight)

            // YUV planes are subsampled 2x2; keep the rect even-aligned to
            // avoid decoder artifacts/crashes on some devices.
            right = right and 1.inv()
            bottom = bottom and 1.inv()

            return Rect(left, top, right, bottom)
        }
    }
    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    override fun pauseCamera() {
        cameraProvider?.unbindAll()
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    override fun resumeCamera() {
        attachCamera()
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    override fun setTorch(enabled: Boolean) {
        camera?.cameraControl?.enableTorch(enabled)
    }

    override fun setOCREnabled(enabled: Boolean) {
        ocrEnabled = enabled
    }


    @SuppressLint("RestrictedApi")
    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    override fun closeCamera() {


        (activity?.activity as? LifecycleOwner)?.let { lifecycleOwner ->
            camera?.cameraInfo?.torchState?.removeObservers(lifecycleOwner)
        }
        cameraProvider?.unbindAll()


        textureEntry?.release()
        // Release references
        camera = null
        textureEntry = null
        preview = null
        cameraProvider = null


    }


}
