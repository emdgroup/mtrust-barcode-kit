import 'package:mtrust_barcode_kit/mtrust_barcode_kit.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final Set<BarcodeFormat> _formats = {BarcodeFormat.dataMatrix};

  final List<DetectedBarcode> _barcodes = [];

  final List<String> _texts = [];

  @override
  void initState() {
    super.initState();
  }

  void _onTextDetected(String text) {
    setState(() {
      _texts.add(text);
    });
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
          cameraFit: BoxFit.cover,
          maskHeight: 200,
          maskWidth: 200,
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
            child: Text(
              "Approach barcode with camera 📸",
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .copyWith(color: Colors.white),
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
                Text(_texts.lastOrNull ?? ""),
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
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => _Settings(
                              formats: _formats,
                              onFormatsChanged: (formats) {
                                setState(() {});
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
  final Function(Set<BarcodeFormat>) onFormatsChanged;

  const _Settings({
    required this.formats,
    required this.onFormatsChanged,
  });

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  Set<BarcodeFormat> _formats = {};

  @override
  void initState() {
    _formats = widget.formats;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Settings"),
        ),
        body: ListView(
            children: BarcodeFormat.values
                .map(
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
                )
                .toList()));
  }
}
