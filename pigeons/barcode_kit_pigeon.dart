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

enum CameraLensDirection { front, back, ext, unknown }

@HostApi()
abstract class BarcodeKitHostApi {
  @async
  CameraOpenResponse openCamera(
    CameraLensDirection direction,
    List<int> formats,
  );

  // ignore: avoid_positional_boolean_parameters
  void setOCREnabled(bool enabled);

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

  /// Called from the host when text is detected.
  void onTextDetected(String text);

  /// Called from the host when the torch state changes.
  //ignore: avoid_positional_boolean_parameters
  void onTorchStateChanged(bool enabled);
}
