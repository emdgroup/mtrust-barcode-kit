# Barcode-Kit

<img src="https://github.com/emdgroup/mtrust-barcode-kit/raw/main/banner.png"  alt="Description" width="200">

[![Documentation Status](https://img.shields.io/badge/Documentation-Barcode--Kit%20Docs-blue?style=flat&logo=readthedocs)](https://docs.mtrust.io/sdks/barcode-kit/)


[![pub package](https://img.shields.io/pub/v/mtrust_barcode_kit.svg)](https://pub.dev/packages/mtrust_barcode_kit)
[![pub points](https://img.shields.io/pub/points/mtrust_barcode_kit)](https://pub.dev/packages/mtrust_barcode_kit/score)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

## Overview

Barcode-Kit is a flutter package that allows you to read barcodes using the camera. It uses native textures to display the camera feed and the barcode overlay. It is built on top of the [Google ML Kit](https://developers.google.com/ml-kit) and [iOS Vision](https://developer.apple.com/documentation/vision) for barcode scanning.

It ships as a single widget that handles most of the work for you.

<img src="https://github.com/emdgroup/mtrust-barcode-kit/raw/main/demo.gif" width="200" alt="Demo video">

## Prerequisites

- Flutter SDK installed on your machine.
- Familiarity with Flutter development.

## Installation

Add the `mtrust_barcode_kit` to your Flutter project via the `pub add` command

```
flutter pub add mtrust_barcode_kit
```
or manually add it to your `pubspec.yaml`
```yaml
dependencies:
  mtrust_barcode_kit: ^2.1.0
```

## Usage

```dart
BarcodeKitView(
    // The barcode formats to scan
    formats: _formats,
    cameraFit: BoxFit.cover,
    // The camera overlay mask
    maskHeight: 200,
    maskWidth: 200,
    widgetAboveMask: Widget // Place something above the camera cutout,
    widgetBelowMask: Widget // Place something below the camera cutout,

    // Whether the camera feed is frozen and barcode scanning is paused
    paused: true/false,

    maskAdditionpauseOpacity: 0.2,

    // Whether the camera is rotated along with the device.
    followRotation: true/false,

    // The callback when a barcode is scanned
    onBarcodeScanned: (barcode) {

    },
    // Custom ui for building requesting permissions and loading screens.
    // Build your own by extending the BarcodeKitUiBuilder
    uiBuilder: BarcodeKitUiBuilder(),
)
```

## Barcode Formats

The `formats` parameter is a list of barcode formats to scan. The supported formats are:

| Format      | iOS | Android |
| ----------- | --- | ------- |
| AZTEC       | ✅   | ✅       |
| CODABAR     | ❌   | ✅       |
| CODE39      | ✅   | ✅       |
| CODE93      | ✅   | ✅       |
| CODE128     | ✅   | ✅       |
| DATAM ATRIX | ✅   | ✅       |
| EAN8        | ✅   | ✅       |
| EAN13       | ✅   | ✅       |
| ITF         | ✅   | ✅       |
| PDF417      | ✅   | ✅       |
| QR-CODE     | ✅   | ✅       |
| UPCA        | ❌   | ✅       |
| UPCE        | ✅   | ✅       |

## OCR (Optional Text Recognition)

In addition to barcode scanning, `BarcodeKitView` can optionally run on-device
OCR (Google ML Kit on Android, Apple Vision on iOS) over the same masked
camera region, useful as a fallback for reading identifiers (e.g. lot/product/
serial numbers) that aren't printed as a barcode.

```dart
BarcodeKitView(
    // ...
    enableOCR: true,
    // Discards recognized text lines below this confidence (0..1).
    // Defaults to 0 (no filtering).
    minTextConfidence: 0.6,
    onTextDetected: (DetectedText detectedText) {
      print(detectedText.text);
    },
)
```

`onTextDetected` is called once per recognized line of text, with a
`DetectedText` carrying:

- `text` - the recognized line content.
- `confidence` - recognition confidence (0..1).
- `cornerPoints` - the line's bounding quadrilateral, in the same full
  camera-texture pixel coordinate space as `DetectedBarcode.cornerPoints`.
- `blockIndex`/`lineIndex` - grouping/ordering within the page (ML Kit only
  groups lines into blocks; `blockIndex` is always `0` on iOS).

The mask cutout (`maskWidth`/`maskHeight`) restricts both barcode detection
and OCR to the same visible region.

## Identifier Classification

Raw OCR text doesn't tell you which line is actually the identifier you care
about (a lot number, product number, etc.) versus surrounding label text or
unrelated printed text. `IdentifierClassifier` scores each detected line by
how "identifier-like" it is, using shape-agnostic heuristics (digit/letter
mixing, character-class transitions, phonotactic naturalness, separators,
length, digit ratio) plus optional proximity to configurable context labels
(e.g. `LOT`, `REF`, `S/N`), without needing to know the exact format/length of
the identifier in advance.

```dart
final classifier = IdentifierClassifier(
  IdentifierClassifierConfig(
    // Labels that identify nearby/inline text as an identifier value.
    contextLabels: ['LOT', 'REF', 'S/N', 'SN', 'PN', 'BATCH'],
    // Known real words that should never be treated as an identifier.
    negativeWordList: {'net', 'weight', 'contents'},
  ),
);

BarcodeKitView(
    // ...
    enableOCR: true,
    onTextDetected: (detectedText) {
      final scored = classifier.classify(detectedText);
      if (!scored.isContextLabel && scored.confidence > 0.6) {
        print('Likely identifier: ${scored.token} (${scored.confidence})');
      }
    },
)
```

Feed every `DetectedText` event into `classify()` - the classifier
internally maintains its own sliding window of recently seen labels (by
position and time), so no manual batching or frame bookkeeping is required.
See the dartdoc on `IdentifierClassifierConfig` for all available tuning
options (feature weights, proximity threshold, context window duration,
minimum identifier length, etc.).

## Contributing
We welcome contributions! Please fork the repository and submit a pull request with your changes. Ensure that your code adheres to our coding standards and includes appropriate tests.

## License
This project is licensed under the Apache 2.0 License. See the [LICENSE](./LICENSE) file for details.
