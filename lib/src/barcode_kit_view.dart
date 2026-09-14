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
    this.minTextConfidence = 0,
    this.direction = CameraLensDirection.back,
    this.fallbackDirections = const [CameraLensDirection.front],
    this.widgetAboveMask,
    this.widgetBelowMask,
    this.maskAdditionpauseOpacity = 0.1,
    super.key,
  });

  /// Direction of the camera
  final CameraLensDirection direction;

  /// Fallback camera directions to try if the primary direction is not
  /// available
  final List<CameraLensDirection> fallbackDirections;

  /// The formats that should be scanned
  final Set<BarcodeFormat> formats;

  /// Whether to run OCR
  final bool enableOCR;

  /// Minimum confidence (0..1) a recognized text line must have to be
  /// forwarded to [onTextDetected]. Defaults to 0 (no filtering). Note that
  /// on Android this relies on ML Kit's `Text.Line.getConfidence()`, which
  /// returns 0 on devices with an outdated Google Play services install -
  /// indistinguishable from a genuinely low-confidence line.
  final double minTextConfidence;

  /// Callback for when a line of text is detected
  final void Function(DetectedText detectedText)? onTextDetected;

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

  // The last MaskRegion sent to the native side, used to avoid spamming the
  // platform channel with redundant updates on every layout pass.
  Rect? _lastMaskRegionSent;

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
    _barcodeKitPlugin.setMinTextConfidence(widget.minTextConfidence);

    try {
      final value = await _barcodeKitPlugin.openCamera(
        widget.direction,
        widget.formats.toList(),
        widget.fallbackDirections,
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
      ..onTextDetectedCallback = (detectedText) {
        if (!widget.paused) {
          widget.onTextDetected?.call(detectedText);
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

    if (widget.minTextConfidence != oldWidget.minTextConfidence) {
      _barcodeKitPlugin.setMinTextConfidence(widget.minTextConfidence);
    }

    if (!setEquals(widget.formats, _lastFormats) ||
        widget.direction != oldWidget.direction ||
        !listEquals(widget.fallbackDirections, oldWidget.fallbackDirections)) {
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
      ..onTextDetectedCallback = null
      ..onBarcodeScannedCallback = null;
    _animationController.dispose();
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
            widget.backdropColor.withAlpha((value * 55).toInt()),
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

  /// Computes the normalized (0..1) camera-frame region covered by the mask
  /// cutout, and forwards it to the native side to restrict both barcode
  /// detection and OCR to that area (see `MaskedAnalyzer` on Android; not yet
  /// implemented on iOS).
  ///
  /// [renderSize] is the actual measured size of the Stack that hosts the
  /// camera preview + mask. [quarterTurns] is the number of quarter turns
  /// applied by [_wrapInRotatedBox] (0 when not following rotation, e.g. in
  /// [_buildStaticCamera]).
  ///
  /// The math relies on the fact that both the mask and the RotatedBox pivot
  /// are centered on the Stack's center: rotating a centered rect by a
  /// multiple of 90 degrees is equivalent to swapping its width/height, so we
  /// can express the mask's extents directly in the pre-rotation coordinate
  /// space that [FittedBox] operates in, without tracking any translation.
  /// [applyBoxFit] mirrors exactly what [FittedBox] itself uses internally,
  /// so this stays correct for any [BarcodeKitView.cameraFit] value.
  void _updateMaskRegion(Size renderSize, int quarterTurns) {
    if (textureId == null || width <= 0 || height <= 0) return;
    if (renderSize.width <= 0 || renderSize.height <= 0) return;

    final textureSize = Size(width, height);

    final rotated = quarterTurns.isOdd;
    final contentSize =
        rotated ? Size(renderSize.height, renderSize.width) : renderSize;
    final maskSizeInContent = rotated
        ? Size(widget.maskHeight, widget.maskWidth)
        : Size(widget.maskWidth, widget.maskHeight);

    final fitted = applyBoxFit(widget.cameraFit, textureSize, contentSize);
    if (fitted.destination.width <= 0 ||
        fitted.destination.height <= 0 ||
        fitted.source.width <= 0 ||
        fitted.source.height <= 0) {
      return;
    }

    final scaleX = fitted.destination.width / fitted.source.width;
    final scaleY = fitted.destination.height / fitted.source.height;

    // FittedBox defaults to Alignment.center (never overridden here), so the
    // visible source sub-rect is centered on the texture's own center too.
    final sourceCenter = Offset(textureSize.width / 2, textureSize.height / 2);

    final regionRect = Rect.fromCenter(
      center: sourceCenter,
      width: maskSizeInContent.width / scaleX,
      height: maskSizeInContent.height / scaleY,
    );

    final normalized = Rect.fromLTRB(
      (regionRect.left / textureSize.width).clamp(0.0, 1.0),
      (regionRect.top / textureSize.height).clamp(0.0, 1.0),
      (regionRect.right / textureSize.width).clamp(0.0, 1.0),
      (regionRect.bottom / textureSize.height).clamp(0.0, 1.0),
    );

    const epsilon = 0.001;
    final last = _lastMaskRegionSent;
    if (last != null &&
        (normalized.left - last.left).abs() < epsilon &&
        (normalized.top - last.top).abs() < epsilon &&
        (normalized.right - last.right).abs() < epsilon &&
        (normalized.bottom - last.bottom).abs() < epsilon) {
      return;
    }
    _lastMaskRegionSent = normalized;

    _barcodeKitPlugin.setMaskRegion(
      MaskRegion(
        left: normalized.left,
        top: normalized.top,
        right: normalized.right,
        bottom: normalized.bottom,
      ),
    );
  }

  Widget _buildCamera() {
    return NativeDeviceOrientationReader(
      builder: (context) {
        final orientation = NativeDeviceOrientationReader.orientation(
          context,
        );
        final quarterTurns = kIsWeb ? 0 : _getQuarterTurns(orientation);
        return LayoutBuilder(
          builder: (context, constraints) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _updateMaskRegion(constraints.biggest, quarterTurns);
              }
            });
            return Stack(
              fit: StackFit.expand,
              children: [
                _buildAnimationWrapper(
                  context,
                  _wrapInRotatedBox(
                    orientation: orientation,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _updateMaskRegion(constraints.biggest, 0);
          }
        });
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
      },
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
