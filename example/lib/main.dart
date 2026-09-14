import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mtrust_barcode_kit/mtrust_barcode_kit.dart';

class _Ui extends BarcodeKitUiBuilder {
  @override
  Widget buildCameraNotAvailable(BuildContext context) {
    return const Stack(
      children: [
        Center(
          child: Text("Camera not available"),
        )
      ],
    );
  }

  @override
  Widget buildCameraNotOpened(BuildContext context) {
    return const Stack(
      children: [
        Center(
          child: CircularProgressIndicator(),
        )
      ],
    );
  }

  @override
  Widget buildNoPermission(
      BuildContext context, Function() onSettingsRequested) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("No permissions granted"),
              ElevatedButton(
                onPressed: () async {
                  onSettingsRequested();
                },
                child: const Text("Open settings"),
              )
            ],
          ),
        )
      ],
    );
  }

  @override
  Widget buildRequestPermission(
      BuildContext context, Function() onPermissionRequested) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("We need permissions to use the camera"),
              ElevatedButton(
                onPressed: () async {
                  onPermissionRequested();
                },
                child: const Text("Request permissions"),
              )
            ],
          ),
        )
      ],
    );
  }
}

void main() {
  runApp(const MaterialApp(
    home: BarcodeKitDemo(),
  ));
}

class BarcodeKitDemo extends StatefulWidget {
  const BarcodeKitDemo({
    super.key,
  });

  @override
  State<BarcodeKitDemo> createState() => _BarcodeKitDemoState();
}

class _BarcodeKitDemoState extends State<BarcodeKitDemo> {
  bool _paused = false;
  bool _rotate = false;
  bool _ocr = false;
  double _maskWidth = 200;
  double _maskHeight = 200;
  double _minTextConfidence = 0.8;
  BoxFit _cameraFit = BoxFit.cover;
  final Set<BarcodeFormat> _formats = {BarcodeFormat.dataMatrix};

  final List<DetectedBarcode> _barcodes = [];

  final List<ScoredToken> _texts = [];

  // Whether detected OCR text is scored/highlighted as a likely
  // lot/product/serial identifier via [IdentifierClassifier]. Only
  // meaningful while OCR (`_ocr`) is also enabled.
  bool _classifyIdentifiers = false;

  // Confidence (0..1) above which a scored token is highlighted as a
  // likely identifier in the list and considered for `_bestIdentifier`.
  // Tune via the settings screen.
  double _identifierConfidenceThreshold = 0.6;

  // Illustrative config - real apps should tailor `contextLabels` to their
  // actual printed labels/locale, and `negativeWordList` to common words
  // that show up on their packaging but should never be treated as an
  // identifier.
  final IdentifierClassifier _classifier = IdentifierClassifier(
    IdentifierClassifierConfig(
      minLength: 6,
      contextLabels: [
        'LOT',
        'REF',
        'S/N',
        'SN',
        'PN',
        'P/N',
        'BATCH',
        'EXP',
        'MFG',
      ],
      negativeWordList: {
        'the',
        'and',
        'for',
        'made',
        'net',
        'weight',
        'contents',
        'warning',
      },
    ),
  );

  // The highest-confidence identifier candidate seen so far this session.
  ScoredToken? _bestIdentifier;

  @override
  void initState() {
    super.initState();
  }

  void _onTextDetected(DetectedText detectedText) {
    final scored = _classifier.classify(detectedText);
    setState(() {
      _texts.add(scored);
      if (_classifyIdentifiers &&
          !scored.isContextLabel &&
          scored.confidence >= _identifierConfidenceThreshold &&
          (_bestIdentifier == null ||
              scored.confidence > _bestIdentifier!.confidence)) {
        _bestIdentifier = scored;
      }
    });
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= _identifierConfidenceThreshold) return Colors.greenAccent;
    if (confidence >= _identifierConfidenceThreshold / 2) {
      return Colors.orangeAccent;
    }
    return Colors.white54;
  }

  Widget _buildTextRow(ScoredToken scored) {
    if (!_classifyIdentifiers) {
      return Text(
        scored.token,
        style: const TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      );
    }

    if (scored.isContextLabel) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          "${scored.token} (label)",
          style: const TextStyle(
            color: Colors.white54,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              scored.token,
              style: TextStyle(color: _confidenceColor(scored.confidence)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: _confidenceColor(scored.confidence).withAlpha(60),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "${(scored.confidence * 100).round()}%"
              "${scored.matchedContextLabel ? ' · ${scored.matchedLabelText}' : ''}",
              style: TextStyle(
                color: _confidenceColor(scored.confidence),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestIdentifierBanner(ScoredToken best) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.greenAccent),
      ),
      child: Row(
        children: [
          const Icon(Icons.tag, color: Colors.greenAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              best.token,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            "${(best.confidence * 100).round()}%",
            style: const TextStyle(color: Colors.greenAccent),
          ),
        ],
      ),
    );
  }

  void _onBarcodeScanned(DetectedBarcode barcode) {
    setState(() {
      _paused = true;
    });

    setState(() {
      _barcodes.add(barcode);
    });

    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Scanned barcode ${barcode.rawValue?.substring(0, 10)} ${barcode.format}",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        body: BarcodeKitView(
          formats: _formats,
          cameraFit: _cameraFit,
          maskHeight: _maskHeight,
          maskWidth: _maskWidth,
          minTextConfidence: _minTextConfidence,
          onTextDetected: _onTextDetected,
          widgetAboveMask: Center(
            child: Text(
              "Look for the barcode",
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium!
                  .copyWith(color: Colors.white),
            ),
          ),
          widgetBelowMask: Center(
            child: Column(
              children: [
                Text(
                  "Approach barcode with camera 📸",
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge!
                      .copyWith(color: Colors.white),
                ),
                if (_classifyIdentifiers && _bestIdentifier != null)
                  _buildBestIdentifierBanner(_bestIdentifier!),
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    itemCount: _texts.length,
                    itemBuilder: (context, index) {
                      final scored = _texts.reversed.toList()[index];
                      return _buildTextRow(scored);
                    },
                  ),
                ),
              ],
            ),
          ),
          paused: _paused,
          maskAdditionpauseOpacity: 0.2,
          enableOCR: _ocr,
          followRotation: _rotate,
          onBarcodeScanned: (barcode) {
            _onBarcodeScanned(barcode);
          },
          uiBuilder: _Ui(),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(color: Colors.white),
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: SafeArea(
            child: Row(
              children: [
                ElevatedButton(
                  child:
                      _paused ? const Text("Start Scan") : const Text("Pause"),
                  onPressed: () {
                    setState(() {
                      _paused = !_paused;
                    });
                  },
                ),
                const Spacer(),
                IconButton(
                    icon: Icon(_rotate
                        ? Icons.screen_rotation
                        : Icons.screen_lock_rotation),
                    onPressed: () {
                      setState(() {
                        _rotate = !_rotate;
                      });
                    }),
                IconButton(
                    icon: Icon(_ocr ? Icons.text_format : Icons.text_decrease),
                    onPressed: () {
                      setState(() {
                        _ocr = !_ocr;
                      });

                      if (_ocr) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "OCR enabled",
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "OCR disabled",
                            ),
                          ),
                        );
                      }
                    }),
                IconButton(
                    tooltip: "Classify OCR text as lot/product identifiers",
                    icon: Icon(
                      Icons.tag,
                      color: _classifyIdentifiers ? Colors.greenAccent : null,
                    ),
                    onPressed: !_ocr
                        ? null
                        : () {
                            setState(() {
                              _classifyIdentifiers = !_classifyIdentifiers;
                              if (!_classifyIdentifiers) {
                                _bestIdentifier = null;
                              }
                            });
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _classifyIdentifiers
                                      ? "Identifier classification enabled"
                                      : "Identifier classification disabled",
                                ),
                              ),
                            );
                          }),
                IconButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => _Settings(
                              formats: _formats,
                              maskWidth: _maskWidth,
                              maskHeight: _maskHeight,
                              minTextConfidence: _minTextConfidence,
                              identifierConfidenceThreshold:
                                  _identifierConfidenceThreshold,
                              cameraFit: _cameraFit,
                              onFormatsChanged: (formats) {
                                setState(() {});
                              },
                              onMaskSizeChanged: (width, height) {
                                setState(() {
                                  _maskWidth = width;
                                  _maskHeight = height;
                                });
                              },
                              onMinTextConfidenceChanged: (value) {
                                setState(() {
                                  _minTextConfidence = value;
                                });
                              },
                              onIdentifierConfidenceThresholdChanged: (value) {
                                setState(() {
                                  _identifierConfidenceThreshold = value;
                                });
                              },
                              onCameraFitChanged: (fit) {
                                setState(() {
                                  _cameraFit = fit;
                                });
                              })));
                    },
                    icon: const Icon(Icons.settings))
              ],
            ),
          ),
        ));
  }
}

class _Settings extends StatefulWidget {
  final Set<BarcodeFormat> formats;
  final double maskWidth;
  final double maskHeight;
  final double minTextConfidence;
  final double identifierConfidenceThreshold;
  final BoxFit cameraFit;
  final Function(Set<BarcodeFormat>) onFormatsChanged;
  final void Function(double width, double height) onMaskSizeChanged;
  final void Function(double value) onMinTextConfidenceChanged;
  final void Function(double value) onIdentifierConfidenceThresholdChanged;
  final void Function(BoxFit fit) onCameraFitChanged;

  const _Settings({
    required this.formats,
    required this.maskWidth,
    required this.maskHeight,
    required this.minTextConfidence,
    required this.identifierConfidenceThreshold,
    required this.cameraFit,
    required this.onFormatsChanged,
    required this.onMaskSizeChanged,
    required this.onMinTextConfidenceChanged,
    required this.onIdentifierConfidenceThresholdChanged,
    required this.onCameraFitChanged,
  });

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  Set<BarcodeFormat> _formats = {};
  late double _maskWidth;
  late double _maskHeight;
  late double _minTextConfidence;
  late double _identifierConfidenceThreshold;
  late BoxFit _cameraFit;

  @override
  void initState() {
    _formats = widget.formats;
    _maskWidth = widget.maskWidth;
    _maskHeight = widget.maskHeight;
    _minTextConfidence = widget.minTextConfidence;
    _identifierConfidenceThreshold = widget.identifierConfidenceThreshold;
    _cameraFit = widget.cameraFit;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Settings"),
        ),
        body: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                "Mask cutout size",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: Text("Width: ${_maskWidth.round()}"),
              subtitle: Slider(
                value: _maskWidth,
                min: 50,
                max: 350,
                divisions: 30,
                label: _maskWidth.round().toString(),
                onChanged: (value) {
                  setState(() {
                    _maskWidth = value;
                  });
                  widget.onMaskSizeChanged(_maskWidth, _maskHeight);
                },
              ),
            ),
            ListTile(
              title: Text("Height: ${_maskHeight.round()}"),
              subtitle: Slider(
                value: _maskHeight,
                min: 50,
                max: 350,
                divisions: 30,
                label: _maskHeight.round().toString(),
                onChanged: (value) {
                  setState(() {
                    _maskHeight = value;
                  });
                  widget.onMaskSizeChanged(_maskWidth, _maskHeight);
                },
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text(
                "OCR text confidence",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: Text(
                "Minimum confidence: ${_minTextConfidence.toStringAsFixed(2)}",
              ),
              subtitle: Slider(
                value: _minTextConfidence,
                divisions: 20,
                label: _minTextConfidence.toStringAsFixed(2),
                onChanged: (value) {
                  setState(() {
                    _minTextConfidence = value;
                  });
                  widget.onMinTextConfidenceChanged(_minTextConfidence);
                },
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text(
                "Identifier classification threshold",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                "Minimum confidence for detected text to be highlighted as "
                "a likely lot/product identifier (green) vs. an uncertain "
                "candidate (orange) or plain text (grey).",
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            ListTile(
              title: Text(
                "Threshold: ${_identifierConfidenceThreshold.toStringAsFixed(2)}",
              ),
              subtitle: Slider(
                value: _identifierConfidenceThreshold,
                divisions: 20,
                label: _identifierConfidenceThreshold.toStringAsFixed(2),
                onChanged: (value) {
                  setState(() {
                    _identifierConfidenceThreshold = value;
                  });
                  widget.onIdentifierConfidenceThresholdChanged(
                    _identifierConfidenceThreshold,
                  );
                },
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text(
                "Camera fit",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButton<BoxFit>(
                value: _cameraFit,
                isExpanded: true,
                items: BoxFit.values
                    .map(
                      (fit) => DropdownMenuItem(
                        value: fit,
                        child: Text(fit.name),
                      ),
                    )
                    .toList(),
                onChanged: (fit) {
                  if (fit == null) return;
                  setState(() {
                    _cameraFit = fit;
                  });
                  widget.onCameraFitChanged(fit);
                },
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text(
                "Barcode formats",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...BarcodeFormat.values.map(
              (e) => CheckboxListTile(
                  title: Text(e.toString()),
                  value: _formats.contains(e),
                  onChanged: (value) {
                    setState(() {
                      if (value == false) {
                        _formats.remove(e);
                      } else {
                        _formats.add(e);
                      }
                    });
                    widget.onFormatsChanged(_formats);
                  }),
            ),
          ],
        ));
  }
}
