import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mtrust_barcode_kit/src/pigeon.dart';
import 'package:permission_handler/permission_handler.dart';

/// Callback for when a barcode is scanned.
typedef OnBarcodeScannedCallback = void Function(DetectedBarcode barcode);

/// Callback for when a text is detected.
typedef OnTextDetectedCallback = void Function(DetectedText detectedText);

/// The main class of the plugin.
class BarcodeKit extends BarcodeKitFlutterApi {
  /// Create a new instance of the plugin.
  BarcodeKit() {
    BarcodeKitFlutterApi.setUp(this);
  }
  final BarcodeKitHostApi _host = BarcodeKitHostApi();

  bool _torchEnabled = false;

  /// Returns whether the torch is enabled.
  bool get torchEnabled => _torchEnabled;

  /// Callback for when a barcode is scanned.
  OnBarcodeScannedCallback? onBarcodeScannedCallback;

  /// Callback for when a text is scanned.
  OnTextDetectedCallback? onTextDetectedCallback;

  /// Returns the current permission status.
  Future<PermissionStatus> getPermissionStatus() async {
    return Permission.camera.status;
  }

  /// Requests the camera permission.
  Future<bool> requestPermissions() async {
    final status = await Permission.camera.status;

    if (status.isRestricted || status.isDenied || status.isLimited) {
      await Permission.camera.request();
    }

    return Permission.camera.status.isGranted;
  }

  /// Opens the camera in [direction] and scans for [formats].
  Future<CameraOpenResponse> openCamera(
    CameraLensDirection direction,
    List<BarcodeFormat> formats, [
    List<CameraLensDirection> fallbackDirections = const [],
  ]) async {
    return _host.openCamera(
      direction,
      formats.map((e) => e.index).toList(),
      fallbackDirections,
    );
  }

  /// Opens the app settings to fix the permissions.
  void openSettings() {
    openAppSettings();
  }

  /// Called from the host when the torch state changes.
  @override
  void onTorchStateChanged(bool enabled) {
    _torchEnabled = enabled;
  }

  /// Sets the torch state.
  void setTorch({required bool enabled}) {
    _host.setTorch(enabled);
  }

  /// Pauses the camera.
  void pauseCamera() {
    _host.pauseCamera();
  }

  /// Resumes the camera.
  void resumeCamera() {
    _host.resumeCamera();
  }

  String _convertDataMatrix(String base64Input) {
    final input = base64.decode(base64Input);

    var string = '';

    for (final byte in input) {
      // 232 is the GS1 FNC1 character
      if (byte == 232) {
        string += String.fromCharCode(29);
      }
      // This byte represents two digits. We pad left if the value < 10
      if (byte >= 130 && byte <= 229) {
        // numeric value
        final value = byte - 130;
        string += value.toString().padLeft(2, '0');
      }
      // This byte represents a single character
      if (byte < 128) {
        string += String.fromCharCode(byte - 1);
      }
      // Padding byte. Signals the end of the actual content
      if (byte == 129) {
        break;
      }
    }

    return string;
  }

  /// Called from the host when a barcode is detected.
  @override
  void onBarcodeScanned(DetectedBarcode barcode) {
    var finalBarcode = barcode;
    if (!kIsWeb &&
        Platform.isIOS &&
        barcode.rawValue != null &&
        barcode.format == BarcodeFormat.dataMatrix) {
      // Decode base 64 value

      finalBarcode = DetectedBarcode(
        rawValue: _convertDataMatrix(barcode.rawValue!),
        cornerPoints: barcode.cornerPoints,
      );
    }

    onBarcodeScannedCallback?.call(finalBarcode);
  }

  /// Closes the camera.
  void closeCamera() {
    BarcodeKitHostApi().closeCamera();
  }

  /// Sets the OCR state.
  // ignore: avoid_positional_boolean_parameters
  void setOCREnabled(bool enabled) {
    _host.setOCREnabled(enabled);
  }

  /// Restricts both barcode detection and OCR (when enabled) to a normalized
  /// (0..1) region of the camera frame, matching the same "display"
  /// orientation reported by [openCamera]'s width/height.
  void setMaskRegion(MaskRegion region) {
    _host.setMaskRegion(region);
  }

  /// Discards recognized text lines whose confidence score is below
  /// [minConfidence] (0..1) before [onTextDetectedCallback] is invoked.
  /// Defaults to 0 (no filtering).
  void setMinTextConfidence(double minConfidence) {
    _host.setMinTextConfidence(minConfidence);
  }

  @override
  void onTextDetected(DetectedText detectedText) {
    onTextDetectedCallback?.call(detectedText);
  }
}
