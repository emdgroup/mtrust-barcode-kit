package com.emddigital.mtrust_barcode_kit


import BarcodeFormat
import BarcodeKitFlutterApi
import BarcodeKitHostApi

import CameraLensDirection
import CameraOpenResponse
import CornerPoint
import DetectedBarcode
import DetectedText
import MaskRegion
import android.annotation.SuppressLint
import android.graphics.Rect
import android.graphics.RectF
import android.media.Image
import android.os.Build
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

    // Minimum Text.Line confidence (0..1) required to forward a recognized
    // line to Dart. 0 (default) means no filtering. Note: Text.Line/Element/
    // Symbol.getConfidence() returns 0 (rather than throwing) on devices
    // with Play services older than ~22.30.x, which is indistinguishable
    // from a genuinely low-confidence line - see
    // https://developers.google.com/android/reference/com/google/mlkit/vision/text/Text.Line#getConfidence()
    @Volatile
    private var minTextConfidence = 0f

    // Normalized (0..1) region (shared by both barcode detection and OCR),
    // in "display" orientation (matching the width/height returned from
    // openCamera). Kept here so it survives across camera re-opens and can
    // be applied to a freshly created MaskedAnalyzer immediately. Defaults
    // to a reasonable centered region until Dart sends the real mask
    // geometry via setMaskRegion.
    @Volatile
    private var maskRegion = RectF(0.15f, 0.35f, 0.85f, 0.65f)

    // The currently active analyzer, so setMaskRegion can update it live
    // without requiring a camera restart.
    private var maskedAnalyzer: MaskedAnalyzer? = null

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

            val analyzer = MaskedAnalyzer(detectors.first, detectors.second).apply {
                maskRegion = this@BarcodeKitPlugin.maskRegion
            }
            maskedAnalyzer = analyzer

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

    /**
     * [offsetX]/[offsetY] translate corner points back from the cropped
     * sub-image's coordinate space into the full sensor frame's coordinate
     * space (i.e. add back the crop rect's top-left corner), since barcode
     * detection now runs against a cropped [InputImage] rather than the full
     * frame. No scale correction is needed since cropping doesn't resample -
     * pixel density is unchanged, only the origin shifts.
     */
    private fun handleBarcodes(barcodes: List<Barcode>?, offsetX: Int, offsetY: Int) {
        if (barcodes.isNullOrEmpty()) return
        for (barcode: Barcode in barcodes) {
            flutterApi?.onBarcodeScanned(
                DetectedBarcode(
                    rawValue = barcode.rawValue,
                    format = barcodeFormatsReversed[barcode.format],
                    cornerPoints = barcode.cornerPoints!!.map { point ->
                        CornerPoint((point.x + offsetX).toDouble(), (point.y + offsetY).toDouble())
                    }
                )
            ) {}
        }
    }

    /**
     * [offsetX]/[offsetY] translate corner points back from the cropped
     * sub-image's coordinate space into the full sensor frame's coordinate
     * space, mirroring [handleBarcodes] - OCR runs against the same cropped
     * [InputImage] as barcode detection (see [MaskedAnalyzer]).
     */
    private fun handleText(text: Text?, offsetX: Int, offsetY: Int) {
        if (text == null) return
        for ((blockIndex, block) in text.textBlocks.withIndex()) {
            for ((lineIndex, line) in block.lines.withIndex()) {
                if (line.confidence < minTextConfidence) continue

                // Prefer the (possibly skewed) corner points; fall back to
                // the axis-aligned bounding box's corners if ML Kit didn't
                // provide corner points for this line.
                val corners = line.cornerPoints?.map { point ->
                    CornerPoint((point.x + offsetX).toDouble(), (point.y + offsetY).toDouble())
                } ?: line.boundingBox?.let { rect ->
                    listOf(
                        CornerPoint((rect.left + offsetX).toDouble(), (rect.top + offsetY).toDouble()),
                        CornerPoint((rect.right + offsetX).toDouble(), (rect.top + offsetY).toDouble()),
                        CornerPoint((rect.right + offsetX).toDouble(), (rect.bottom + offsetY).toDouble()),
                        CornerPoint((rect.left + offsetX).toDouble(), (rect.bottom + offsetY).toDouble())
                    )
                } ?: emptyList()

                flutterApi?.onTextDetected(
                    DetectedText(
                        text = line.text,
                        confidence = line.confidence.toDouble(),
                        cornerPoints = corners,
                        blockIndex = blockIndex.toLong(),
                        lineIndex = lineIndex.toLong()
                    )
                ) {}
            }
        }
    }

    /**
     * SPIKE: custom [ImageAnalysis.Analyzer] that restricts both barcode
     * detection and OCR to the visible mask region, instead of the ML
     * Kit-managed [androidx.camera.mlkit.vision.MlKitAnalyzer], which always
     * evaluates every attached detector against the full frame.
     *
     * IMPORTANT: `android.media.Image.cropRect` does **not** work for this -
     * `InputImage.fromMediaImage()` silently ignores it and always reads the
     * full plane buffers (confirmed: https://github.com/googlesamples/mlkit/issues/234
     * and still-open https://github.com/googlesamples/mlkit/issues/491). An
     * earlier version of this spike relied on `cropRect` and appeared to
     * compile/run fine, but had *zero* effect - OCR kept seeing (and
     * detecting garbage from) the entire frame.
     *
     * The approach that actually works: manually extract a cropped NV21 byte
     * array from the YUV_420_888 planes (respecting each plane's
     * `rowStride`/`pixelStride`, since chroma planes are rarely tightly
     * packed) and hand that independent byte array to
     * [InputImage.fromByteArray]. This is a real copy, decoupled from the
     * shared [Image], and only large enough to cover the masked region - so
     * it both restricts *and* speeds up both detectors (less data to
     * convert/scan). Both detectors share the same extracted [ByteArray]
     * (read-only, so this is safe) to avoid extracting it twice per frame.
     *
     * Since barcode detection now runs against the cropped sub-image rather
     * than the full frame, [Barcode.getCornerPoints] come back relative to
     * the crop's own (0,0) origin - [handleBarcodes] translates them back
     * into full-frame coordinates by adding the crop rect's top-left corner,
     * since downstream Dart code (`PerspectiveTransform`/`PerspectiveBarcode`)
     * expects full-frame coordinates to position the barcode overlay.
     *
     * NOTE - this is a proof of concept, not production ready:
     *  - [maskRegion] defaults to a centered placeholder rect, but is normally
     *    kept in sync with `BarcodeKitView`'s actual mask geometry via
     *    `BarcodeKitPlugin.setMaskRegion()` (Dart computes the normalized rect
     *    from `maskWidth`/`maskHeight` vs. the rendered preview size/aspect
     *    ratio - see `_updateMaskRegion` in `barcode_kit_view.dart`).
     *  - The rotation -> sensor-space mapping in [computeCropRect] needs
     *    verification on real devices (front vs back camera, 0/90/180/270
     *    sensor rotation) before this ships.
     *  - [cropToNv21] assumes a 3-plane YUV_420_888 image with 8-bit samples,
     *    which holds for CameraX/Camera2 on all mainstream devices, but exotic
     *    plane layouts (e.g. some MediaTek chipsets historically) may need
     *    extra care/testing.
     *  - Two separate ML Kit calls (barcode + text) now run instead of one
     *    combined `MlKitAnalyzer` pass; frame lifetime (`imageProxy.close()`)
     *    is now our responsibility. Both `InputImage`s are now backed by an
     *    independent copied byte array (not references into the shared
     *    `Image`), so - unlike the very first version of this spike - neither
     *    task actually requires the `Image`/`imageProxy` to stay alive; we
     *    still wait on both before closing for simplicity.
     *  - Barcodes are now only detected within the mask cutout. This is a
     *    real behavioural change from the original (unmasked) implementation -
     *    a barcode fully outside the visible mask will no longer be reported
     *    at all.
     */
    private inner class MaskedAnalyzer(
        private val barcodeScanner: BarcodeScanner,
        private val textRecognizer: TextRecognizer
    ) : ImageAnalysis.Analyzer {

        // Normalized (0..1) rect, in the orientation the user sees on screen.
        // Updated live from Dart via BarcodeKitPlugin.setMaskRegion(), based
        // on the actual rendered mask geometry of BarcodeKitView.
        @Volatile
        var maskRegion = RectF(0.15f, 0.35f, 0.85f, 0.65f)

        @SuppressLint("UnsafeOptInUsageError")
        override fun analyze(imageProxy: ImageProxy) {
            val mediaImage = imageProxy.image
            if (mediaImage == null) {
                imageProxy.close()
                return
            }

            val rotationDegrees = imageProxy.imageInfo.rotationDegrees

            // Shared by barcode detection and OCR, so both are guaranteed to
            // agree on exactly the same region.
            val cropRect = computeCropRect(mediaImage, rotationDegrees, maskRegion)
            val nv21 = cropToNv21(mediaImage, cropRect)

            val barcodeTask: Task<List<Barcode>> = barcodeScanner.process(
                InputImage.fromByteArray(
                    nv21,
                    cropRect.width(),
                    cropRect.height(),
                    rotationDegrees,
                    InputImage.IMAGE_FORMAT_NV21
                )
            )

            // Text recognition: only the masked region, if OCR is enabled.
            val textTask: Task<Text>? = if (ocrEnabled) {
                val croppedImage = InputImage.fromByteArray(
                    nv21,
                    cropRect.width(),
                    cropRect.height(),
                    rotationDegrees,
                    InputImage.IMAGE_FORMAT_NV21
                )
                textRecognizer.process(croppedImage)
            } else {
                null
            }

            val tasks = mutableListOf<Task<*>>(barcodeTask)
            if (textTask != null) tasks.add(textTask)

            Tasks.whenAllComplete(tasks).addOnCompleteListener {
                if (barcodeTask.isSuccessful) {
                    handleBarcodes(barcodeTask.result, cropRect.left, cropRect.top)
                }
                if (textTask?.isSuccessful == true) {
                    handleText(textTask.result, cropRect.left, cropRect.top)
                }
                imageProxy.close()
            }
        }

        /**
         * Maps a normalized rect defined in "display/rotated" space (i.e. what
         * the mask cutout looks like to the user, independent of sensor
         * rotation) back into the raw sensor buffer's coordinate space, then
         * into pixel coordinates clamped to the image bounds. Left/top/right/
         * bottom are all aligned to even pixels since chroma planes are
         * subsampled 2x2 and [cropToNv21] indexes chroma via `/2`.
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

            var left = (rotated.left * imageWidth).toInt().coerceIn(0, imageWidth)
            var top = (rotated.top * imageHeight).toInt().coerceIn(0, imageHeight)
            var right = (rotated.right * imageWidth).toInt().coerceIn(left, imageWidth)
            var bottom = (rotated.bottom * imageHeight).toInt().coerceIn(top, imageHeight)

            // Even-align so the chroma (half-resolution) crop lines up exactly.
            left = left and 1.inv()
            top = top and 1.inv()
            right = right and 1.inv()
            bottom = bottom and 1.inv()

            return Rect(left, top, right, bottom)
        }

        /**
         * Extracts the pixels within [cropRect] from a YUV_420_888 [Image]
         * into a standalone NV21 (Y, then interleaved VU) byte array, honouring
         * each plane's `rowStride`/`pixelStride` (chroma planes are frequently
         * *not* tightly packed, so naive contiguous copies produce corrupted/
         * shifted output on many devices).
         *
         * [cropRect] must have even left/top/right/bottom (see
         * [computeCropRect]) so the chroma subsampling divides evenly.
         */
        private fun cropToNv21(image: Image, cropRect: Rect): ByteArray {
            val cropWidth = cropRect.width()
            val cropHeight = cropRect.height()
            val ySize = cropWidth * cropHeight
            val chromaWidth = cropWidth / 2
            val chromaHeight = cropHeight / 2
            val nv21 = ByteArray(ySize + chromaWidth * chromaHeight * 2)

            val yPlane = image.planes[0]
            val yBuffer = yPlane.buffer
            val yRowStride = yPlane.rowStride
            val yPixelStride = yPlane.pixelStride

            var pos = 0
            for (row in 0 until cropHeight) {
                val imageRow = cropRect.top + row
                val rowStart = imageRow * yRowStride
                for (col in 0 until cropWidth) {
                    val imageCol = cropRect.left + col
                    nv21[pos++] = yBuffer.get(rowStart + imageCol * yPixelStride)
                }
            }

            // NV21 expects V before U, interleaved, at half resolution.
            val uPlane = image.planes[1]
            val vPlane = image.planes[2]
            val uBuffer = uPlane.buffer
            val vBuffer = vPlane.buffer
            val uRowStride = uPlane.rowStride
            val uPixelStride = uPlane.pixelStride
            val vRowStride = vPlane.rowStride
            val vPixelStride = vPlane.pixelStride

            val chromaLeft = cropRect.left / 2
            val chromaTop = cropRect.top / 2

            for (row in 0 until chromaHeight) {
                val chromaRow = chromaTop + row
                val uRowStart = chromaRow * uRowStride
                val vRowStart = chromaRow * vRowStride
                for (col in 0 until chromaWidth) {
                    val chromaCol = chromaLeft + col
                    nv21[pos++] = vBuffer.get(vRowStart + chromaCol * vPixelStride)
                    nv21[pos++] = uBuffer.get(uRowStart + chromaCol * uPixelStride)
                }
            }

            return nv21
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

    override fun setMaskRegion(region: MaskRegion) {
        val rect = RectF(
            region.left.toFloat(),
            region.top.toFloat(),
            region.right.toFloat(),
            region.bottom.toFloat()
        )
        maskRegion = rect
        maskedAnalyzer?.maskRegion = rect
    }

    override fun setMinTextConfidence(minConfidence: Double) {
        minTextConfidence = minConfidence.toFloat()
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
        maskedAnalyzer = null


    }


}
