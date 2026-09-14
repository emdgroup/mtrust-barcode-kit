import Flutter
import AVFoundation
import UIKit
import Vision

public class BarcodeKitPlugin: NSObject, FlutterPlugin , BarcodeKitHostApi, FlutterTexture, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate{
    
    
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        if latestBuffer == nil {
                   return nil
               }
        return Unmanaged<CVPixelBuffer>.passRetained(latestBuffer!)
    }
    
    
    let registry: FlutterTextureRegistry?
    var sink: FlutterEventSink? = nil
    var textureId: Int64? = nil
    var captureSession: AVCaptureSession? = nil
    var device: AVCaptureDevice? = nil
    var latestBuffer: CVImageBuffer? = nil
    var analyzeMode: Int = 0
    var analyzing: Bool = false
    
    var height: Int32 = 0
    var width: Int32 = 0
    
    // Callback queue for AVCaptureVideoDataOutputSampleBufferDelegate. Kept
    // off the main queue so the (potentially expensive) OCR work triggered
    // from it never contends with UI work - this is separate from the
    // deadlock fix below, and doesn't affect `AVCaptureMetadataOutput`
    // (barcode) detection, which uses its own delegate queue (kept as the
    // main queue - see `metadataOutput.setMetadataObjectsDelegate` in
    // `openCamera`).
    private let sampleBufferQueue = DispatchQueue(label: "com.barcodekit.SampleBufferQueue")

    // Runs `AVCaptureSession.stopRunning()` (see `closeCamera`) and
    // `startRunning()` (see `openCamera`) off the main thread - both are
    // documented by Apple as blocking calls that must never be invoked on
    // the main thread. This alone is enough to avoid the deadlock that
    // otherwise occurs when `stopRunning()` is called synchronously on the
    // main thread while a capture output's delegate callback queue is also
    // the main queue (`stopRunning()` blocks until in-flight delegate
    // callbacks drain, so calling it on the same queue as those callbacks
    // self-deadlocks) - since neither `openCamera`/`closeCamera` themselves
    // ever block waiting on `sessionQueue`, the main thread stays free to
    // keep servicing `AVCaptureMetadataOutput`'s main-queue delegate
    // callbacks while `stopRunning()` drains them from this queue. Since
    // `openCamera`/`closeCamera` are invoked directly from Pigeon's
    // main-thread message handlers, using one shared serial queue for both
    // also keeps close-then-open sequencing (see
    // `BarcodeKitView.didUpdateWidget`) processed in order without
    // overlapping hardware start/stop calls.
    private let sessionQueue = DispatchQueue(label: "com.barcodekit.SessionQueue")

    private let visionQueue = DispatchQueue(label: "com.barcodekit.VisionQueue")
    private let semaphore = DispatchSemaphore(value: 1)

    // Recreated on every `openCamera()` call (see there) rather than reused
    // across sessions - an `AVCaptureOutput` can only be attached to one
    // `AVCaptureSession` at a time, and reusing a single instance raced
    // with the previous session's (now asynchronous, see `sessionQueue`)
    // teardown removing it from the old session: `canAddOutput` would
    // silently return false if the old removal hadn't completed yet,
    // silently skipping metadata object type / delegate setup entirely -
    // symptom: camera opens fine, but nothing is ever scanned.
    private var metadataOutput = AVCaptureMetadataOutput()
    
    var ocrEnabled = false

    // Minimum VNRecognizedText.confidence (0..1) required to forward a
    // recognized text observation to Dart. 0 (default) means no filtering.
    var minTextConfidence: Float = 0

    // Normalized (0..1) region (shared by both barcode detection and OCR),
    // in the same "display" orientation as width/height. Since this plugin
    // pins the capture connection's videoOrientation to .portrait (see
    // openCamera), the delivered CVPixelBuffer's own dimensions already
    // match width/height directly - unlike Android, no per-frame rotation
    // un-mapping is needed here.
    var maskRegion = MaskRegion(left: 0.15, top: 0.35, right: 0.85, bottom: 0.65)

    private let flutterApi: BarcodeKitFlutterApi

    // Tagged for easy filtering in the Xcode/device console (Console.app:
    // search "[BarcodeKit]").
    private func log(_ message: String) {
        print("[BarcodeKit] \(message)")
    }

    // Setup  pigeon
    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger : FlutterBinaryMessenger = registrar.messenger()
        BarcodeKitHostApiSetup.setUp(binaryMessenger: messenger, api: BarcodeKitPlugin(registrar.textures(), registrar: registrar));
        
    }
    
    init(_ registry: FlutterTextureRegistry, registrar: FlutterPluginRegistrar) {
            self.registry = registry
            analyzeMode = 0
            flutterApi = BarcodeKitFlutterApi(binaryMessenger: registrar.messenger())
            analyzing = false
            super.init()
        }
    
    
    
    func setOCREnabled(enabled: Bool)  throws {
        ocrEnabled = enabled
    }

    // Restricts both barcode detection (AVCaptureMetadataOutput.rectOfInterest)
    // and OCR (VNRecognizeTextRequest.regionOfInterest, applied per-request in
    // captureOutput) to region.
    func setMaskRegion(region: MaskRegion) throws {
        maskRegion = region
        applyMaskRegionToMetadataOutput()
    }

    // AVCaptureMetadataOutput.rectOfInterest is normalized (0..1, top-left
    // origin) relative to a landscape image with the home button on the
    // right, regardless of device/connection orientation - the exact same
    // landscape-right sensor space already used for barcode/OCR corner
    // point conversion elsewhere in this file (see `metadataOutput(_:
    // didOutput:from:)` and the OCR corner mapping in `captureOutput`),
    // where a normalized sensor point (x_sensor, y_sensor) maps to our
    // portrait "display" pixel space as:
    //   x_display = width - y_sensor * width
    //   y_display = x_sensor * height
    // `maskRegion` is expressed in that same portrait display space,
    // already normalized (0..1, top-left origin) relative to width/height.
    // Inverting the transform above (dropping the width/height factors
    // since both sides are already normalized fractions) gives:
    //   x_sensor = y_display_frac
    //   y_sensor = 1 - x_display_frac
    // Applying this to all four corners of `maskRegion` and taking the
    // bounding rect produces the `rectOfInterest` below.
    //
    // This previously used a throwaway `AVCaptureVideoPreviewLayer` purely
    // for its `metadataOutputRectConverted(fromLayerRect:)` helper, which
    // was intended to avoid hand-deriving this transform - but in practice
    // it logged `CGAffineTransformInvert: singular matrix` and always
    // produced a degenerate zero-area rect (since the layer was never
    // attached to any view/window), silently making barcode detection
    // impossible regardless of format. Computing the transform directly
    // avoids the dependency on that layer entirely.
    private func applyMaskRegionToMetadataOutput() {
        guard captureSession != nil else { return }

        let region = maskRegion
        metadataOutput.rectOfInterest = CGRect(
            x: CGFloat(region.top),
            y: CGFloat(1 - region.right),
            width: CGFloat(region.bottom - region.top),
            height: CGFloat(region.right - region.left)
        )
    }

    func setMinTextConfidence(minConfidence: Double) throws {
        minTextConfidence = Float(minConfidence)
    }

    // No op on iOS
    func pauseCamera() {

    }

    // No op on iOS
    func resumeCamera() {

    }
    

    
    func openCamera(direction: CameraLensDirection, formats: [Int64], fallbackDirections: [CameraLensDirection], completion: @escaping (Result<CameraOpenResponse, Error>) -> Void) {
        textureId = registry!.register(self)
        captureSession = AVCaptureSession()
        // Recreated per session - see the comment on the `metadataOutput`
        // property.
        metadataOutput = AVCaptureMetadataOutput()

        // Try the primary direction first, then fallback directions
        let directionsToTry = [direction] + fallbackDirections
        var selectedDevice: AVCaptureDevice? = nil
        var selectedPosition: AVCaptureDevice.Position = .back
        
        for directionToTry in directionsToTry {
            let position = directionToTry == .front ? AVCaptureDevice.Position.front : .back
            
            var devices: [AVCaptureDevice] = []
            
            if #available(iOS 10.0, *) {
                devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: position).devices
            } else {
                devices = AVCaptureDevice.devices(for: .video).filter({$0.position == position})
            }
            
            if !devices.isEmpty {
                selectedDevice = devices.first
                selectedPosition = position
                break
            }
        }
        
        if selectedDevice == nil {
            log("openCamera: FAILED - no suitable camera found for directions \(directionsToTry)")
            completion(.failure(NSError(domain: "BarcodeKit", code: 1, userInfo: ["message": "No suitable camera found from the provided directions"])))
            return
        }
        
        device = selectedDevice!

        device!.addObserver(self, forKeyPath: #keyPath(AVCaptureDevice.torchMode), options: .new, context: nil)
        captureSession!.beginConfiguration()
        // Add device input.
        do {
            let input = try AVCaptureDeviceInput(device: device!)
            captureSession!.addInput(input)
        } catch {
            log("openCamera: FAILED to create/add device input: \(error)")
            completion(.failure(error))
        }
        // Add video output.
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)
        captureSession!.addOutput(videoOutput)
        for connection in videoOutput.connections {
            connection.videoOrientation = .portrait
            if selectedPosition == .front && connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
        
            
        if(captureSession!.canAddOutput(metadataOutput)){
            captureSession!.addOutput(metadataOutput)
            
            if(formats.isEmpty){
                metadataOutput.metadataObjectTypes = metadataOutput.availableMetadataObjectTypes
            }else{
                var objectTypes: [AVMetadataObject.ObjectType] = []

                for formatItem in formats {
                    let objectType = BarcodeFormat(rawValue: Int(formatItem)).flatMap { barcodeMap[$0] }
                    if(objectType != nil){
                        objectTypes.append(objectType!)
                    }
                }
                metadataOutput.metadataObjectTypes = objectTypes
            }

            // Kept on the main queue - unlike the video sample buffer
            // delegate, moving this to a background queue was found to make
            // AVCaptureMetadataOutput's on-device barcode detection
            // unreliable (it stopped firing) despite Apple's docs not
            // explicitly requiring the main queue here. The deadlock this
            // plugin previously had is instead avoided by running
            // `stopRunning()` off the main thread (see `sessionQueue`),
            // which is sufficient on its own since the main thread is never
            // blocked waiting on it.
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        } else {
            log("openCamera: FAILED - could not add metadata output to capture session, barcode scanning will not work for this session")
        }
        
        
        // `startRunning()` can take a noticeable amount of time on some
        // devices, so it - like the original implementation - is deferred
        // off the main thread here. See the comment on `sessionQueue` for
        // why this alone is enough to avoid the previous deadlock, even
        // though the metadata delegate queue is main.
        //
        // Local copies of session/device/textureId are captured here
        // (rather than reading `self.captureSession`/`self.device`/
        // `self.textureId` inside the closure) so that a rapid subsequent
        // closeCamera()+openCamera() call - which would reassign those
        // shared instance properties on the main thread before this
        // dispatched block runs - can't cause this block to operate on the
        // wrong (newer, unrelated) session or crash on a nil force-unwrap.
        let openedSession = captureSession!
        let openedDevice = device!
        let openedTextureId = textureId!
        sessionQueue.async {
            openedSession.commitConfiguration()
            openedSession.startRunning()

            let dimensions = CMVideoFormatDescriptionGetDimensions(openedDevice.activeFormat.formatDescription)
            self.width = dimensions.height
            self.height = dimensions.width

            // width/height are only known now; applyMaskRegionToMetadataOutput
            // itself no longer depends on them directly, but dispatching to
            // main keeps this consistent with other UI-adjacent state
            // updates.
            DispatchQueue.main.async {
                self.applyMaskRegionToMetadataOutput()
            }

            completion(.success(CameraOpenResponse(
                supportsFlash: openedDevice.hasTorch,
                height: Int64(self.height),
                width: Int64(self.width),
                textureId: String(openedTextureId)
            )))
        }
    }

    var lastFrameTime: Double = 0

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get pixel buffer from sample buffer")
            return
        }

        // `closeCamera()` resets `textureId`/`registry` state synchronously
        // on the main thread as soon as it's called, while the *old*
        // session's `stopRunning()` (which is what actually stops frame
        // delivery) is deferred to a background queue - see `closeCamera`.
        // A frame from the dying old session can therefore still arrive
        // here, on `sampleBufferQueue`, in the brief window after
        // `textureId` has already been nil'd out but before the old
        // session has actually stopped. Previously this force-unwrapped
        // `textureId!` and crashed; just drop the stale frame instead.
        guard let registry = registry, let textureId = textureId else {
            return
        }

        latestBuffer = pixelBuffer

        registry.textureFrameAvailable(textureId)

        // Throttle frame processing to improve performance
        let currentTime = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        
        let frameRateThrottle = 0.5 // Process 10 frames per second
        if currentTime - lastFrameTime < frameRateThrottle {
            return
        }
        lastFrameTime = currentTime

        if #available(iOS 13.0, *)  {
            
            if ocrEnabled{
                
                visionQueue.async {
                    
                    self.semaphore.wait()
                    defer { self.semaphore.signal() }
                    
                    // Create a request handler using the sample buffer's pixel buffer
                    let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                    
                    // Create a text detection request
                    let request = VNRecognizeTextRequest { (request, error) in
                        guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                        
                        for (lineIndex, observation) in observations.enumerated() {
                            // Get the top recognized text
                            guard let topCandidate = observation.topCandidates(1).first else { continue }

                            if topCandidate.confidence < self.minTextConfidence { continue }

                            // Vision's boundingBox is normalized (0..1) relative to the
                            // *full* image regardless of regionOfInterest, with a
                            // bottom-left origin - unlike AVFoundation metadata's
                            // top-left, landscape-sensor-based normalized space. We
                            // first flip to a top-left origin, then reuse the exact
                            // same landscape-sensor -> portrait-pixel transform applied
                            // to barcode corners below, so OCR and barcode geometry end
                            // up in the same coordinate space Dart already expects.
                            let box = observation.boundingBox
                            let rawCorners: [(x: CGFloat, y: CGFloat)] = [
                                (box.minX, 1 - box.minY), // bottom-left (top-left post-flip)
                                (box.maxX, 1 - box.minY), // bottom-right
                                (box.maxX, 1 - box.maxY), // top-right (bottom-right post-flip)
                                (box.minX, 1 - box.maxY), // top-left
                            ]
                            let corners = rawCorners.map { corner in
                                CornerPoint(
                                    x: CGFloat(self.width) - corner.y * CGFloat(self.width),
                                    y: corner.x * CGFloat(self.height)
                                )
                            }

                            let detectedText = DetectedText(
                                text: topCandidate.string,
                                confidence: Double(topCandidate.confidence),
                                cornerPoints: corners,
                                // Vision has no block concept - every observation is
                                // effectively its own line-level block.
                                blockIndex: 0,
                                lineIndex: Int64(lineIndex)
                            )

                            DispatchQueue.main.async {
                                self.flutterApi.onTextDetected(detectedText: detectedText, completion: {_ in 
                                    
                                })
                            }
                            
                        }
                    }

                    // Vision's regionOfInterest uses a bottom-left origin,
                    // unlike our top-left-origin maskRegion.
                    let region = self.maskRegion
                    request.regionOfInterest = CGRect(
                        x: CGFloat(region.left),
                        y: CGFloat(1 - region.bottom),
                        width: CGFloat(region.right - region.left),
                        height: CGFloat(region.bottom - region.top)
                    )
                    
                    do {
                        // Perform the text recognition request
                        try requestHandler.perform([request])
                    } catch {
                        print("Failed to perform text recognition: \(error.localizedDescription)")
                    }
                    
                }
            }
        }
    }
    
    func closeCamera() throws {
        // Capture local references to the current session/device/texture so
        // the actual teardown can happen asynchronously (see below), while
        // resetting instance state synchronously below lets a subsequent
        // openCamera() call - which Dart issues immediately after
        // closeCamera() without awaiting it, see
        // BarcodeKitView.didUpdateWidget - proceed right away without
        // observing or racing with this teardown.
        let sessionToClose = captureSession
        let deviceToRelease = device
        let textureIdToUnregister = textureId

        analyzeMode = 0
        latestBuffer = nil
        captureSession = nil
        device = nil
        textureId = nil

        sessionQueue.async { [weak self] in
            // AVCaptureSession.stopRunning() is a blocking call that waits
            // for any in-flight delegate callbacks to finish, and must
            // never be called on the main thread - see the comment on
            // `sessionQueue`. This is called from the Pigeon `closeCamera`
            // method handler, which always runs on the main thread, so it
            // must be dispatched off of it here.
            if let session = sessionToClose {
                session.stopRunning()
                session.beginConfiguration()
                for input in session.inputs {
                    session.removeInput(input)
                }
                for output in session.outputs {
                    session.removeOutput(output)
                }
                session.commitConfiguration()
            }
            if let deviceToRelease = deviceToRelease, let self = self {
                deviceToRelease.removeObserver(self, forKeyPath: #keyPath(AVCaptureDevice.torchMode))
            }

            if let textureIdToUnregister = textureIdToUnregister {
                DispatchQueue.main.async {
                    self?.registry?.unregisterTexture(textureIdToUnregister)
                }
            }
        }
    }
    
    
    
    // Called on the main queue (see openCamera's
    // setMetadataObjectsDelegate), so it's safe to call directly into
    // Flutter/Pigeon APIs below without an extra thread hop.
    public func metadataOutput(_: AVCaptureMetadataOutput, didOutput: [AVMetadataObject], from: AVCaptureConnection){
        for metadataObject in didOutput {
            if let barcodeMetadataObject = metadataObject as? AVMetadataMachineReadableCodeObject {
                let barcode = DetectedBarcode(
                    rawValue: barcodeMetadataObject.rawValue?.base64EncodedString(),
                    cornerPoints: barcodeMetadataObject.corners.map({cornerpoint in
                        return CornerPoint( x: CGFloat(width)-cornerpoint.y*CGFloat(width),y: cornerpoint.x*CGFloat(height))
                    }),
                    format: barcodeMap.first(where: { (key: BarcodeFormat, value: AVMetadataObject.ObjectType) in
                        value == barcodeMetadataObject.type
                    })?.key,
                    textValue: barcodeMetadataObject.stringValue
                )
                flutterApi.onBarcodeScanned(barcode: barcode, completion: {_ in 
                    
                })
            }
            
        }
        
    }
    
   
 
    
    func setTorch(enabled: Bool) throws {
        
        try device?.lockForConfiguration()
        device?.torchMode = enabled ? .on : .off
        device?.unlockForConfiguration()
        
    }

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        case "torchMode":
            // off = 0; on = 1; auto = 2;
            let state = change?[.newKey] as? Int
            flutterApi.onTorchStateChanged(enabled: state == 1, completion: {_ in 
                
            })
            
        default:
            break
        }
    }
    
    

    
    // NOTE: intentionally missing .upcA and .codabar - see below. If
    // `openCamera(formats:)` is used to restrict to *only* one of these two
    // formats, this map's lookup in `openCamera` silently drops it, leaving
    // `metadataOutput.metadataObjectTypes` empty and barcode scanning
    // silently non-functional for that session (no error is raised).
    //
    // - .codabar: AVFoundation has no Codabar support at all - there is no
    //   corresponding `AVMetadataObject.ObjectType` case. This is a platform
    //   limitation, not something fixable by adding an entry here.
    // - .upcA: AVFoundation has no distinct UPC-A object type either - it
    //   reports UPC-A barcodes as `.ean13` (UPC-A numbers are valid EAN-13
    //   values with a leading `0`). With unrestricted `formats: []` scanning,
    //   a UPC-A barcode is still detected, but currently comes back as
    //   `format: .ean13` rather than `.upcA` (and with the leading `0` still
    //   present in `rawValue`/`textValue`). Handling this "properly" would
    //   require inspecting `.ean13` results for a leading-zero 13-digit
    //   value and remapping to `.upcA` (stripping the leading digit), which
    //   hasn't been implemented here.
    var barcodeMap: [BarcodeFormat: AVMetadataObject.ObjectType] = [
        .aztec: .aztec,
        .code93: .code93,
        .code39: .code39,
        .code128: .code128,
        .dataMatrix: .dataMatrix,
        .ean8: .ean8,
        .ean13: .ean13,
        .pdf417: .pdf417,
        .qrCode: .qr,
        .upcE: .upce,
        .itf: .interleaved2of5
    ]

    
}
