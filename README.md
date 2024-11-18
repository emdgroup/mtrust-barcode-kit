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
  mtrust_barcode_kit: ^2.0.2
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


## Contributing
We welcome contributions! Please fork the repository and submit a pull request with your changes. Ensure that your code adheres to our coding standards and includes appropriate tests.

## License
This project is licensed under the Apache 2.0 License. See the [LICENSE](./LICENSE) file for details.
