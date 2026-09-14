import 'package:pigeon/pigeon.dart';

enum BarcodeFormat {
  aztec, // MLKit  AVFoundation
  codabar, // MLKit,
  code39, // MLKit, AVFoundation
  code93, // MLKit,  AVFoundation
  code128, // MLKit,  AVFoundation
  dataMatrix, // MLKit,  AVFoundation
  ean8, // MLKit,  AVFoundation
  ean13, // MLKit,  AVFoundation
  pdf417, // MLKit, AVFoundation
  qrCode, // MLKit, AVFoundation
  upcA, // MLKit,
  upcE, // MLKit,  AVFoundation
  itf, // AVFoundation
}

class CameraOpenResponse {
  bool? supportsFlash;
  int? height;
  int? width;
  String? textureId;
}

class DetectedBarcode {
  String? rawValue;
  List<CornerPoint?>? cornerPoints;
  BarcodeFormat? format;
  String? textValue;
}

class CornerPoint {
  CornerPoint(this.x, this.y);
  final double x;
  final double y;
}

/// A single recognized line of OCR text, with geometry mirroring
/// [DetectedBarcode] so both can be positioned/compared using the same
/// full camera-texture pixel coordinate space (post sensor-rotation,
/// "display" orientation, matching the width/height returned by
/// [BarcodeKitHostApi.openCamera]).
class DetectedText {
  DetectedText(
    this.text,
    this.confidence,
    this.cornerPoints,
    this.blockIndex,
    this.lineIndex,
  );

  /// The recognized text content of this line.
  final String text;

  /// Recognition confidence (0..1). On Android this is ML Kit's
  /// `Text.Line.getConfidence()`. On iOS this is
  /// `VNRecognizedText.confidence` for the top candidate.
  final double confidence;

  /// The four corners of the line's bounding quadrilateral, in the same
  /// coordinate space as [DetectedBarcode.cornerPoints].
  final List<CornerPoint?> cornerPoints;

  /// Groups lines belonging to the same OCR text block (ML Kit only).
  /// Always 0 on iOS, since Vision has no block concept - only individual
  /// line-level observations.
  final int blockIndex;

  /// The line's order within its block (reading order).
  final int lineIndex;
}

/// A normalized (0..1) rectangular region of a camera frame, expressed in
/// the same "display" orientation as the width/height returned by
/// [BarcodeKitHostApi.openCamera] (i.e. already accounting for sensor
/// rotation, before any further widget-level rotation).
class MaskRegion {
  MaskRegion(this.left, this.top, this.right, this.bottom);
  final double left;
  final double top;
  final double right;
  final double bottom;
}

enum CameraLensDirection { front, back, ext, unknown }

@HostApi()
abstract class BarcodeKitHostApi {
  @async
  CameraOpenResponse openCamera(
    CameraLensDirection direction,
    List<int> formats,
    List<CameraLensDirection> fallbackDirections,
  );

  // ignore: avoid_positional_boolean_parameters
  void setOCREnabled(bool enabled);

  /// Restricts both barcode detection and OCR (when enabled) to [region] of
  /// the camera frame instead of scanning the entire frame, matching the
  /// visible mask cutout. Android only for now.
  void setMaskRegion(MaskRegion region);

  /// Discards recognized text lines whose confidence score is below
  /// [minConfidence] (0..1) before forwarding them via
  /// `BarcodeKitFlutterApi.onTextDetected`. Defaults to 0 (no filtering) if
  /// never called.
  void setMinTextConfidence(double minConfidence);

  void closeCamera();

  void pauseCamera();

  void resumeCamera();

  //ignore: avoid_positional_boolean_parameters
  void setTorch(bool enabled);
}

@FlutterApi()
abstract class BarcodeKitFlutterApi {
  /// Caleld from the host when a barcode is detected.
  void onBarcodeScanned(DetectedBarcode barcode);

  /// Called from the host when a line of text is detected.
  void onTextDetected(DetectedText detectedText);

  /// Called from the host when the torch state changes.
  //ignore: avoid_positional_boolean_parameters
  void onTorchStateChanged(bool enabled);
}
