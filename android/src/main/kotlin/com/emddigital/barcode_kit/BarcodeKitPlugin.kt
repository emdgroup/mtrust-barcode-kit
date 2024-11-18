package com.emddigital.barcode_kit


import BarcodeFormat
import BarcodeKitFlutterApi
import BarcodeKitHostApi

import CameraLensDirection
import CameraOpenResponse
import CornerPoint
import DetectedBarcode
import android.annotation.SuppressLint
import android.os.Build
import android.util.Log
import android.view.Surface
import androidx.annotation.RequiresApi
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.core.TorchState
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.mlkit.vision.MlKitAnalyzer
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
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
    BarcodeFormat.DATAMATRIX to Barcode.FORMAT_DATA_MATRIX,
    BarcodeFormat.EAN8 to Barcode.FORMAT_EAN_8,
    BarcodeFormat.EAN13 to Barcode.FORMAT_EAN_13,
    BarcodeFormat.PDF417 to Barcode.FORMAT_PDF417,
    BarcodeFormat.QRCODE to Barcode.FORMAT_QR_CODE,
    BarcodeFormat.UPCA to Barcode.FORMAT_UPC_A,
    BarcodeFormat.UPCE to Barcode.FORMAT_UPC_E,
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
        // Remove references
        activity = null
        closeCamera()
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

            val analyzer =
                MlKitAnalyzer(
                    listOf(detectors.first,detectors.second),
                    ImageAnalysis.COORDINATE_SYSTEM_ORIGINAL,
                    executor
                ) {
                    processMlResult(it, detectors.first, detectors.second)
                }

            analysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build().apply { setAnalyzer(executor, analyzer) }
            // Bind to lifecycle.


            var cameraSelectorBuilder = CameraSelector.Builder()

            cameraSelectorBuilder = when (direction) {
                CameraLensDirection.BACK -> cameraSelectorBuilder.requireLensFacing(CameraSelector.LENS_FACING_BACK)
                CameraLensDirection.EXT -> cameraSelectorBuilder.requireLensFacing(CameraSelector.LENS_FACING_EXTERNAL)
                CameraLensDirection.FRONT -> cameraSelectorBuilder.requireLensFacing(CameraSelector.LENS_FACING_FRONT)
                CameraLensDirection.UNKNOWN -> cameraSelectorBuilder

            }

            cameraSelector = cameraSelectorBuilder.build()
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

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun processMlResult(result: MlKitAnalyzer.Result, barcodeScanner: BarcodeScanner, textRecognizer: TextRecognizer ) {
        val barcodes = result.getValue(barcodeScanner)



        if (!barcodes.isNullOrEmpty()) {
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
        if (ocrEnabled) {
            val texts = result.getValue(textRecognizer)
            if (texts != null) {
                for (block in texts.textBlocks) {
                    for (line in block.lines) {
                        // Handle recognized text
                        flutterApi?.onTextDetected(
                            line.text,
                        ) {}
                    }
                }
            }
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


        camera?.cameraInfo?.torchState?.removeObservers(activity!!.activity as LifecycleOwner)
        cameraProvider?.unbindAll()


        textureEntry?.release()
        // Release references
        camera = null
        textureEntry = null
        preview = null
        cameraProvider = null


    }


}
