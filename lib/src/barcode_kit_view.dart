import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mtrust_barcode_kit/mtrust_barcode_kit.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:permission_handler/permission_handler.dart';

/// A builder that is used to build the UI for the barcode kit
abstract class BarcodeKitUiBuilder {
  /// Build the widget that is shown when the user has not granted permission
  Widget buildRequestPermission(
    BuildContext context,
    void Function() onPermissionRequested,
  );

  /// Build the widget that is shown when the user has not granted permission
  Widget buildNoPermission(
    BuildContext context,
    void Function() onSettingsRequested,
  );

  /// Build the widget that is shown when the camera is not available
  Widget buildCameraNotAvailable(BuildContext context);

  /// Build the widget that is shown when the camera is not opened yet
  Widget buildCameraNotOpened(BuildContext context);
}

/// Overlay painter is used to draw a rectangle on the camera view and
/// shade the rest of the view
class MaskPainter extends CustomPainter {
  /// Create a new [MaskPainter]
  MaskPainter({
    required this.animationValue,
    this.height = 0.4,
    this.width = 0.5,
  });

  /// The animation value that is used to animate the mask
  double animationValue = 0;

  /// The height of the mask
  double height = 0;

  /// The width of the mask
  double width = 0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.largest, Paint());
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromARGB(150, 15, 26, 46),
          Colors.black,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final cutoutRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: width,
        height: height * animationValue,
      ),
      const Radius.circular(16),
    );

    canvas
      ..drawRRect(cutoutRect, Paint()..blendMode = BlendMode.clear)
      ..restore()
      ..drawRRect(
        cutoutRect,
        Paint()
          ..color = Colors.white.withAlpha(animationValue.toInt() * 255)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

/// The default overlay builder that is used to draw a rectangle on the barcode
Widget defaultBarcodeOverlayBuilder(
  BuildContext context,
  DetectedBarcode barcode,
) {
  return Container(
    height: 1,
    width: 1,
    decoration: BoxDecoration(
      color: Colors.yellowAccent.withAlpha(100),
      borderRadius: BorderRadius.circular(0.05),
    ),
  );
}

/// A utility widget that handles most functionality needed to scan barcodes
class BarcodeKitView extends StatefulWidget {
  /// Create a new [BarcodeKitView]
  const BarcodeKitView({
    required this.onBarcodeScanned,
    required this.uiBuilder,
    required this.formats,
    this.onTextDetected,
    this.backdropColor = Colors.black,
    this.barcodeOverlayBuilder = defaultBarcodeOverlayBuilder,
    this.paused = false,
    this.mask = true,
    this.maskHeight = 200,
    this.maskWidth = 200,
    this.pauseBlurAmount = 10,
    this.pauseZoomAmount = 0.2,
    this.followRotation = true,
    this.children,
    this.cameraFit = BoxFit.cover,
    this.enableOCR = false,
    this.direction = CameraLensDirection.back,
    this.widgetAboveMask,
    this.widgetBelowMask,
    this.maskAdditionpauseOpacity = 0.1,
    super.key,
  });

  /// Direction of the camera
  final CameraLensDirection direction;

  /// The formats that should be scanned
  final Set<BarcodeFormat> formats;

  /// Whether to run OCR
  final bool enableOCR;

  /// Callback for when text is detected
  final void Function(String detectedText)? onTextDetected;

  /// Widget that gets transformed to be placed on top of the barcode.
  /// Needs to be 1x1 in size to work properly
  final Widget Function(BuildContext context, DetectedBarcode barcode)?
      barcodeOverlayBuilder;

  /// The color that is used to fill around the mask
  final Color backdropColor;

  /// The ui builder that is used to build the UI for requesting permissions
  ///  etc.
  final BarcodeKitUiBuilder uiBuilder;

  /// The children that are placed on top of the camera view
  final List<Widget>? children;

  /// Opacity of [widgetAboveMask] and [widgetBelowMask] when the camera is
  /// paused
  final double maskAdditionpauseOpacity;

  /// Widget to be placed above the mask
  final Widget? widgetAboveMask;

  /// Widget to be placed below the mask
  final Widget? widgetBelowMask;

  /// The amount of blur that is applied to the camera view when the
  /// camera is paused
  final double pauseBlurAmount;

  /// The amount of zoom that is applied to the camera view when the
  /// camera is paused
  final double pauseZoomAmount;

  /// Whether the camera should be paused, will prevent calls
  /// to [onBarcodeScanned]
  final bool paused;

  /// Whether the mask should be shown
  final bool mask;

  /// The height of the mask
  final double maskHeight;

  /// The width of the mask
  final double maskWidth;

  /// The fit of the camera view
  final BoxFit cameraFit;

  /// Whether the camera should follow the rotation of the device
  final bool followRotation;

  /// The callback that is called when a barcode is scanned
  final void Function(DetectedBarcode barcode) onBarcodeScanned;

  @override
  State<BarcodeKitView> createState() => _BarcodeKitViewState();
}

class _BarcodeKitViewState extends State<BarcodeKitView>
    with TickerProviderStateMixin {
  final BarcodeKit _barcodeKitPlugin = BarcodeKit();

  int? textureId;
  double width = 0;
  double height = 0;

  Set<BarcodeFormat> _lastFormats = {};

  bool _unableToOpenCamera = false;

  DetectedBarcode? lastBarcode;

  PermissionStatus _permissionStatus = PermissionStatus.denied;

  late AnimationController _animationController;

  @override
  void initState() {
    assert(widget.formats.isNotEmpty, 'Needs at least one format to scan');
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    super.initState();
    _start();
  }

  Future<void> _start() async {
    _lastFormats = widget.formats.toList().toSet();
    _permissionStatus = await _barcodeKitPlugin.getPermissionStatus();
    if (_permissionStatus != PermissionStatus.granted) {
      setState(() {});
      return;
    }

    _unableToOpenCamera = false;

    if (widget.enableOCR) {
      _barcodeKitPlugin.setOCREnabled(true);
    } else {
      _barcodeKitPlugin.setOCREnabled(false);
    }

    try {
      final value = await _barcodeKitPlugin.openCamera(
        CameraLensDirection.back,
        widget.formats.toList(),
      );
      setState(() {
        textureId = int.parse(value.textureId!);

        height = value.height!.toDouble();
        width = value.width!.toDouble();
      });
    } catch (e) {
      setState(() {
        _unableToOpenCamera = true;
      });
    }

    _barcodeKitPlugin
      ..onBarcodeScannedCallback = (barcode) {
        if (!widget.paused) {
          widget.onBarcodeScanned(barcode);
          setState(() {
            lastBarcode = barcode;
          });
        }
      }
      ..onTextDetectedCallback = (text) {
        if (!widget.paused) {
          widget.onTextDetected?.call(text);
        }
      };
  }

  @override
  void didUpdateWidget(covariant BarcodeKitView oldWidget) {
    if (widget.paused != oldWidget.paused) {
      if (widget.paused) {
        if (Platform.isAndroid) {
          _barcodeKitPlugin.pauseCamera();
        }
        _animationController.forward();
      } else {
        if (Platform.isAndroid) {
          _barcodeKitPlugin.resumeCamera();
        }
        _animationController.reverse();
        setState(() {
          lastBarcode = null;
        });
      }
    }

    if (widget.enableOCR != oldWidget.enableOCR) {
      _barcodeKitPlugin.setOCREnabled(widget.enableOCR);
    }

    if (!setEquals(widget.formats, _lastFormats)) {
      _barcodeKitPlugin.closeCamera();
      _start();
    }

    super.didUpdateWidget(oldWidget);
  }

  Widget _wrapInRotatedBox({
    required Widget child,
    required NativeDeviceOrientation orientation,
  }) {
    if (kIsWeb) {
      return child;
    }

    return RotatedBox(
      quarterTurns: _getQuarterTurns(orientation),
      child: child,
    );
  }

  Widget _buildLastBarcode() {
    return PerspectiveBarcode(
      barcode: lastBarcode!,
      child: widget.barcodeOverlayBuilder!(context, lastBarcode!),
    );
  }

  int _getQuarterTurns(NativeDeviceOrientation orientation) {
    if (Platform.isIOS) {
      return turnsIoS[orientation] ?? 0;
    }
    return turns[orientation]!;
  }

  Map<NativeDeviceOrientation, int> turnsIoS = {
    NativeDeviceOrientation.portraitUp: 0,
    NativeDeviceOrientation.landscapeRight: 1,
    NativeDeviceOrientation.portraitDown: 2,
    NativeDeviceOrientation.landscapeLeft: 3,
  };

  Map<NativeDeviceOrientation, int> turns = {
    NativeDeviceOrientation.portraitUp: 0,
    NativeDeviceOrientation.landscapeRight: 2,
    NativeDeviceOrientation.portraitDown: 0,
    NativeDeviceOrientation.landscapeLeft: 0,
  };

  @override
  void dispose() {
    _barcodeKitPlugin
      ..closeCamera()
      ..onBarcodeScannedCallback = null;
    super.dispose();
  }

  void _openSettings() {
    _barcodeKitPlugin.openSettings();
  }

  Future<void> _requestPermission() async {
    if (await _barcodeKitPlugin.requestPermissions()) {
      await _start();
    } else {
      setState(() {
        _permissionStatus = PermissionStatus.permanentlyDenied;
      });
    }
  }

  Widget _buildAnimationWrapper(BuildContext context, Widget child) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child2) {
        final value = CurvedAnimation(
          parent: _animationController,
          curve: Curves.elasticOut,
        ).value;
        return ColorFiltered(
          colorFilter: ColorFilter.mode(
            widget.backdropColor.withOpacity(value * 0.2),
            BlendMode.srcATop,
          ),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: value * widget.pauseBlurAmount,
              sigmaY: value * widget.pauseBlurAmount,
            ),
            child: Transform.scale(
              scale: 1 + widget.pauseZoomAmount * value,
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextureWrapper() {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Texture(
            key: ValueKey(textureId),
            textureId: textureId!,
            freeze: widget.paused,
          ),
          if (lastBarcode != null && widget.barcodeOverlayBuilder != null)
            _buildLastBarcode(),
        ],
      ),
    );
  }

  Widget _buildCamera() {
    return NativeDeviceOrientationReader(
      builder: (context) {
        return Stack(
          fit: StackFit.expand,
          children: [
            _buildAnimationWrapper(
              context,
              _wrapInRotatedBox(
                orientation: NativeDeviceOrientationReader.orientation(
                  context,
                ),
                child: FittedBox(
                  fit: widget.cameraFit,
                  clipBehavior: Clip.hardEdge,
                  child: _buildTextureWrapper(),
                ),
              ),
            ),
            if (widget.mask) _buildMask(),
            _buildMaskAdditions(),
            ...?widget.children,
          ],
        );
      },
    );
  }

  Widget _buildMask() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) => SizedBox.expand(
        child: Opacity(
          opacity: 1 - _animationController.value,
          child: CustomPaint(
            painter: MaskPainter(
              height: widget.maskHeight,
              width: widget.maskWidth,
              animationValue: 1 -
                  CurvedAnimation(
                    curve: const Interval(
                      0,
                      0.3,
                      curve: Curves.easeOutCubic,
                    ),
                    parent: _animationController,
                  ).value,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaticCamera() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildAnimationWrapper(
          context,
          SizedBox.expand(
            child: FittedBox(
              fit: widget.cameraFit,
              child: _buildTextureWrapper(),
            ),
          ),
        ),
        if (widget.mask) _buildMask(),
        _buildMaskAdditions(),
        ...?widget.children,
      ],
    );
  }

  Widget _buildMaskAdditions() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) => SizedBox.expand(
        child: Opacity(
          opacity: 1 -
              (1 - widget.maskAdditionpauseOpacity) *
                  _animationController.value,
          child: SizedBox.expand(
            child: Builder(
              builder: (context) {
                return Column(
                  children: [
                    Expanded(
                      child: widget.widgetAboveMask ?? Container(),
                    ),
                    Container(
                      height: widget.maskHeight,
                    ),
                    Expanded(
                      child: widget.widgetBelowMask ?? Container(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_permissionStatus) {
      case PermissionStatus.denied:
        return widget.uiBuilder.buildRequestPermission(
          context,
          _requestPermission,
        );

      case PermissionStatus.granted:
        if (_unableToOpenCamera) {
          return widget.uiBuilder.buildCameraNotAvailable(
            context,
          );
        }
        if (textureId == null) {
          return widget.uiBuilder.buildCameraNotOpened(
            context,
          );
        }

        if (widget.followRotation) {
          return _buildCamera();
        } else {
          return _buildStaticCamera();
        }

      case PermissionStatus.permanentlyDenied:
      case PermissionStatus.restricted:
      case PermissionStatus.limited:
      case PermissionStatus.provisional:
        return widget.uiBuilder.buildNoPermission(context, _openSettings);
    }
  }
}
