import Flutter
import AVFoundation
import UIKit
import Vision

public class SwiftBarcodeKitPlugin: NSObject, FlutterPlugin , BarcodeKitHostApi, FlutterTexture, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate{
    
    
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
    
    private let metadataObjectsQueue = DispatchQueue(label: "metadata objects queue", attributes: [], target: nil)

    private let visionQueue = DispatchQueue(label: "com.barcodekit.VisionQueue")
    private let semaphore = DispatchSemaphore(value: 1)
    private let metadataOutput = AVCaptureMetadataOutput()
    
    var ocrEnabled = false

    
    private let flutterApi: BarcodeKitFlutterApi
    
    // Setup  pigeon
    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger : FlutterBinaryMessenger = registrar.messenger()
        BarcodeKitHostApiSetup.setUp(binaryMessenger: messenger, api: SwiftBarcodeKitPlugin(registrar.textures(), registrar: registrar));
        
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
    
    // No op on iOS
    func pauseCamera() {

    }

    // No op on iOS
    func resumeCamera() {

    }
    

    
    func openCamera(direction: CameraLensDirection,formats: [Int64] , completion: @escaping (Result<CameraOpenResponse, Error>) -> Void) {
        textureId = registry!.register(self)
        captureSession = AVCaptureSession()
        
        let position = direction == .front ? AVCaptureDevice.Position.front : .back
        
        
        var devices: [AVCaptureDevice] = []
        
        if #available(iOS 10.0, *) {
            devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: position).devices
        } else {
            devices = AVCaptureDevice.devices(for: .video).filter({$0.position == position})
        }
        
        if(devices.isEmpty){
            completion(.failure(NSError(domain: "BarcodeKit", code: 1, userInfo: ["message": "No camera found"])))
            return
        }else{
            device = devices.first
        }
        
        device!.addObserver(self, forKeyPath: #keyPath(AVCaptureDevice.torchMode), options: .new, context: nil)
        captureSession!.beginConfiguration()
        // Add device input.
        do {
            let input = try AVCaptureDeviceInput(device: device!)
            captureSession!.addInput(input)
        } catch {
            completion(.failure(error))
        }
        // Add video output.
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        captureSession!.addOutput(videoOutput)
        for connection in videoOutput.connections {
            connection.videoOrientation = .portrait
            if position == .front && connection.isVideoMirroringSupported {
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
                    let objectType = barcodeMap[BarcodeFormat(rawValue: Int(formatItem))!]
                    if(objectType != nil){
                        objectTypes.append(objectType!)
                    }
                }
                metadataOutput.metadataObjectTypes = objectTypes
            }
            


            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main )
            print("Added capture output for metadata")
        }
        
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession!.commitConfiguration()
            self.captureSession!.startRunning()
            
            let dimensions = CMVideoFormatDescriptionGetDimensions(self.device!.activeFormat.formatDescription)
            self.width = dimensions.height
            self.height = dimensions.width
            
            completion(.success(CameraOpenResponse(
                supportsFlash: self.device!.hasTorch,
                height: Int64(self.height),
                width: Int64(self.width),
                textureId: String(self.textureId!)
                
                
            )))
        }
        
        
    }

     var lastFrameTime: Double = 0
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get pixel buffer from sample buffer")
            return
        }

        latestBuffer = pixelBuffer

        registry!.textureFrameAvailable(textureId!)

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
                        
                        for observation in observations {
                            // Get the top recognized text
                            guard let topCandidate = observation.topCandidates(1).first else { continue }
                            
                            
                            DispatchQueue.main.async {
                                self.flutterApi.onTextDetected(text: topCandidate.string,completion: {
                                    
                                })
                            }
                            
                        }
                    }
                    
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
        if(captureSession != nil){
            captureSession!.stopRunning()
            for input in captureSession!.inputs {
                captureSession!.removeInput(input)
            }
            for output in captureSession!.outputs {
                captureSession!.removeOutput(output)
            }
        }
        device?.removeObserver(self, forKeyPath: #keyPath(AVCaptureDevice.torchMode))
        if(textureId != nil){
            registry?.unregisterTexture(textureId!)
        }
        
        
        analyzeMode = 0
        latestBuffer = nil
        captureSession = nil
        device = nil
        textureId = nil
            
            
    }
    
    
    
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
                flutterApi.onBarcodeScanned(barcode: barcode,completion: {
                    
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
            flutterApi.onTorchStateChanged(enabled: state == 1, completion: {
                
            })
            
        default:
            break
        }
    }
    
    

    
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
