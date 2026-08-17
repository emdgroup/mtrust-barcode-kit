## 2.1.0-2
Released on: 8/17/2026, changelog automatically generated.

## 2.1.0-1
Released on: 8/14/2026, changelog automatically generated.


### Features

- **ios:** migrate to Swift Package Manager ([#3](issues/3)) ([90a447f](commit/90a447f))

### API Changes

#### 💣 Breaking changes

**`meta` pubspec.yaml** ([pubspec.yaml](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.1.0-0..v2.1.0-1#diff-8b7e9df87668ffa6a04b32e1769a33434999e54ae081c52e5d943c541d4c0d25))
- 🎯 Minimum Flutter SDK version increased: from `>=3.3.0` to `>=3.44.0`
- 🍎 Minimum iOS SDK version increased: from `9.0` to `13.0`

#### 👀 Patch changes

**`class` _PerspectiveMatrix** ([lib/src/perspective.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.1.0-0..v2.1.0-1#diff-6ff0e5d0c22aada208821c900684ca46eaf98c7e97cde3d9b76fd4834c501e83))
- ➖ Mixin removed: EquatableMixin
- ➕ Mixin added: Equatable

**`meta` pubspec.yaml** ([pubspec.yaml](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.1.0-0..v2.1.0-1#diff-8b7e9df87668ffa6a04b32e1769a33434999e54ae081c52e5d943c541d4c0d25))
- 📦 `equatable` version changed: from `^2.0.5` to `^2.1.0`
- 📦 `native_device_orientation` version changed: from `^2.0.3` to `^2.1.1`
- 📦 `permission_handler` version changed: from `^11.4.0` to `^13.0.1`

## 2.1.0-0
Released on: 9/8/2025, changelog automatically generated.


### Bug Fixes

- add camera fallback logic and update gradle configs ([4d80acd](commit/4d80acd))
- correctly handle fallback directions on iOS ([20973ff](commit/20973ff))
- update build.gradle and pubspec.lock for improved compatibility and dependency management ([4f3b6ef](commit/4f3b6ef))
- update build.gradle to align with Flutter configuration ([121aa7e](commit/121aa7e))
- enhance camera selection logic with fallback for unavailable cameras ([f9de003](commit/f9de003))
- add namespace to android configuration in build.gradle ([7ee23aa](commit/7ee23aa))
- migrate to Kotlin DSL (build.gradle.kts) update gradle version ([16f7ed0](commit/16f7ed0))
- update permission_handler dependency to resolve build issue with newer flutter versions ([5704eda](commit/5704eda))
### Features

- enhance BarcodeKitView to support fallback directions for improved control over camera availability ([114786b](commit/114786b))

### API Changes

#### 💣 Breaking changes

**`class` BarcodeKitHostApi** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.0.3-0..v2.1.0-0#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❇️ Param added in method `openCamera`: `fallbackDirections` (positional, required)

#### ✨ Minor changes

**`class` BarcodeKit** ([lib/src/barcode_kit.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.0.3-0..v2.1.0-0#diff-6c1e62c053047fbc8d516040f9274ece318a413ee92aa5cfd3e6672096caa00c))
- ❇️ Param added in method `openCamera`: `fallbackDirections` (positional, optional, default: const [])

**`class` BarcodeKitView** ([lib/src/barcode_kit_view.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.0.3-0..v2.1.0-0#diff-8cd8d66c2e6b0f5dbbee58d73962a9e2819ccb420602079f63fcc2089108f8d3))
- ❇️ Param added in default constructor: `fallbackDirections` (named, optional, default: const [CameraLensDirection.front])
- ❇️ Property added: `fallbackDirections`

#### 👀 Patch changes

**`meta` pubspec.yaml** ([pubspec.yaml](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.0.3-0..v2.1.0-0#diff-8b7e9df87668ffa6a04b32e1769a33434999e54ae081c52e5d943c541d4c0d25))
- 📦 `permission_handler` version changed: from `^11.3.1` to `^11.4.0`

## 2.0.3-0
Released on: 2/10/2025, changelog automatically generated.


### Bug Fixes

- animation controller, callback disposal ([#1](issues/1)) ([aa0a72b](commit/aa0a72b))

### API Changes

#### 💣 Breaking changes

**`class` BarcodeKitFlutterApi** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.0.2..v2.0.3-0#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❌ Property removed: `codec`
- ❌ Method removed: `setup`

**`class` BarcodeKitHostApi** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.0.2..v2.0.3-0#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❌ Property removed: `codec`
- ❌ Param removed in method `openCamera`: `arg_formats` (positional, required)
- ❇️ Param added in method `openCamera`: `formats` (positional, required)

#### ✨ Minor changes

**`class` BarcodeKitFlutterApi** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.0.2..v2.0.3-0#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❇️ Property added: `pigeonChannelCodec`
- ❇️ Method added: `setUp`

**`class` BarcodeKitHostApi** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.0.2..v2.0.3-0#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❇️ Param added in default constructor: `messageChannelSuffix` (named, optional, default: '')
- ❇️ Properties added: `pigeonVar_binaryMessenger`, `pigeonChannelCodec`, `pigeonVar_messageChannelSuffix`

**`function` wrapResponse** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.0.2..v2.0.3-0#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❇️ Function added: `wrapResponse`

#### 👀 Patch changes

**`class` BarcodeKitHostApi** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.0.2..v2.0.3-0#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❌ Property removed: `_binaryMessenger`
- ✏️ Param renamed in method `openCamera`: `arg_direction` → `direction`
- ✏️ Param renamed in method `setOCREnabled`: `arg_enabled` → `enabled`
- ✏️ Param renamed in method `setTorch`: `arg_enabled` → `enabled`

**`class` _BarcodeKitFlutterApiCodec** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.0.2..v2.0.3-0#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❌ Class removed: `_BarcodeKitFlutterApiCodec`

**`class` _BarcodeKitHostApiCodec** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.0.2..v2.0.3-0#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❌ Class removed: `_BarcodeKitHostApiCodec`

**`class` _PigeonCodec** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.0.2..v2.0.3-0#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❇️ Class added: `_PigeonCodec`

**`function` _createConnectionError** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.0.2..v2.0.3-0#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❇️ Function added: `_createConnectionError`

## 2.0.2
Released on: 11/18/2024, changelog automatically generated.

### API Changes

#### 👀 Patch changes

**`class` _BarcodeKitViewState** ([lib/src/barcode_kit_view.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v2.0.1..v2.0.2#diff-8cd8d66c2e6b0f5dbbee58d73962a9e2819ccb420602079f63fcc2089108f8d3))
- ❌ Param removed in method `_wrapInRotatedBox`: `orentation` (named, required)
- ❇️ Param added in method `_wrapInRotatedBox`: `orientation` (named, required)
- ✏️ Param renamed in method `_getQuarterTurns`: `orentation` → `orientation`

## 2.0.1
Released on: 10/8/2024, changelog automatically generated.

## 2.0.0
Released on: 9/11/2024, changelog automatically generated.


### Features

- ocr for ios ([5de36d0](commit/5de36d0))
- OCR implementation & fix: pausing on android ([8bcb9bf](commit/8bcb9bf))

### API Changes

#### 💣 Breaking changes

**`meta` pubspec.yaml** ([pubspec.yaml](https://github.com/emdgroup/mtrust-barcode-kit/compare/v1.0.9..v2.0.0#diff-8b7e9df87668ffa6a04b32e1769a33434999e54ae081c52e5d943c541d4c0d25))
- 🎯 Minimum Dart SDK version increased: from `>=2.18.6 <4.0.0` to `>=3.3.1 <4.0.0`
- 🎯 Minimum Flutter SDK version increased: from `>=2.5.0` to `>=3.3.0`

#### ✨ Minor changes

**`class` BarcodeKit** ([lib/src/barcode_kit.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v1.0.9..v2.0.0#diff-6c1e62c053047fbc8d516040f9274ece318a413ee92aa5cfd3e6672096caa00c))
- ❇️ Property added: `onTextDetectedCallback`
- ❇️ Methods added: `onTextDetected`, `pauseCamera`, `resumeCamera`, `setOCREnabled`

**`class` BarcodeKitFlutterApi** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v1.0.9..v2.0.0#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❇️ Method added: `onTextDetected`

**`class` BarcodeKitHostApi** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v1.0.9..v2.0.0#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❇️ Methods added: `setOCREnabled`, `pauseCamera`, `resumeCamera`

**`class` BarcodeKitView** ([lib/src/barcode_kit_view.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v1.0.9..v2.0.0#diff-8cd8d66c2e6b0f5dbbee58d73962a9e2819ccb420602079f63fcc2089108f8d3))
- ❇️ Params added in default constructor: `onTextDetected` (named, optional), `enableOCR` (named, optional, default: false)
- ❇️ Properties added: `enableOCR`, `onTextDetected`

**`typedef` OnTextDetectedCallback** ([lib/src/barcode_kit.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v1.0.9..v2.0.0#diff-6c1e62c053047fbc8d516040f9274ece318a413ee92aa5cfd3e6672096caa00c))
- ❇️ Typedef added: `OnTextDetectedCallback`

## 1.0.9
Released on: 6/17/2024, changelog automatically generated.


### Bug Fixes

- error not rendered with priority ([d37df33](commit/d37df33))

## 1.0.8
Released on: 6/17/2024, changelog automatically generated.


### Bug Fixes

- ios simulator crashes ([46da62f](commit/46da62f))

### API Changes

#### 👀 Patch changes

**`class` _BarcodeKitViewState** ([lib/src/barcode_kit_view.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v1.0.7..v1.0.8#diff-8cd8d66c2e6b0f5dbbee58d73962a9e2819ccb420602079f63fcc2089108f8d3))
- ❇️ Property added: `_unableToOpenCamera`

**`meta` pubspec.yaml** ([pubspec.yaml](https://github.com/emdgroup/mtrust-barcode-kit/compare/v1.0.7..v1.0.8#diff-8b7e9df87668ffa6a04b32e1769a33434999e54ae081c52e5d943c541d4c0d25))
- 📦 `native_device_orientation` version changed: from `^1.1.4` to `^2.0.3`
- 📦 `permission_handler` version changed: from `^10.3.0` to `^11.3.1`
- 📦 `plugin_platform_interface` version changed: from `^2.0.2` to `^2.1.8`

## 1.0.7
Released on: 10/9/2023, changelog automatically generated.

### API Changes

#### 👀 Patch changes

**`meta` pubspec.yaml** ([pubspec.yaml](https://github.com/emdgroup/mtrust-barcode-kit/compare/v1.0.6..v1.0.7#diff-8b7e9df87668ffa6a04b32e1769a33434999e54ae081c52e5d943c541d4c0d25))
- 🎯 Maximum Dart SDK version increased: from `>=2.18.6 <3.0.0` to `>=2.18.6 <4.0.0`

## 1.0.6
Released on: 9/29/2023, changelog automatically generated.

## 1.0.5
Released on: 8/31/2023, changelog automatically generated.


### Features

- barcode formats ([d4fd1b8](commit/d4fd1b8))

### API Changes

#### ✨ Minor changes

**`class` DetectedBarcode** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v1.0.4..v1.0.5#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❇️ Params added in default constructor: `format` (named, optional), `textValue` (named, optional)
- ❇️ Properties added: `format`, `textValue`

#### 👀 Patch changes

**`class` BarcodeKit** ([lib/src/barcode_kit.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v1.0.4..v1.0.5#diff-6c1e62c053047fbc8d516040f9274ece318a413ee92aa5cfd3e6672096caa00c))
- ❇️ Method added: `_convertDataMatrix`

## 1.0.4
Released on: 7/21/2023, changelog automatically generated.


### Features

- widget above and below scanning area ([059d65a](commit/059d65a))

### API Changes

#### ✨ Minor changes

**`class` BarcodeKitView** ([lib/src/barcode_kit_view.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v1.0.3..v1.0.4#diff-8cd8d66c2e6b0f5dbbee58d73962a9e2819ccb420602079f63fcc2089108f8d3))
- ❇️ Params added in default constructor: `widgetAboveMask` (named, optional), `widgetBelowMask` (named, optional), `maskAdditionpauseOpacity` (named, optional, default: 0.1)
- ❇️ Properties added: `maskAdditionpauseOpacity`, `widgetAboveMask`, `widgetBelowMask`

#### 👀 Patch changes

**`class` _BarcodeKitViewState** ([lib/src/barcode_kit_view.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v1.0.3..v1.0.4#diff-8cd8d66c2e6b0f5dbbee58d73962a9e2819ccb420602079f63fcc2089108f8d3))
- ❇️ Property added: `_lastFormats`
- ❇️ Method added: `_buildMaskAdditions`

## 1.0.3
Released on: 7/2/2023, changelog automatically generated.


### Bug Fixes

- null pointer exception due to unecessary restart ([7ce5010](commit/7ce5010))

### API Changes

#### 👀 Patch changes

**`class` _BarcodeKitViewState** ([lib/src/barcode_kit_view.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/v1.0.2..v1.0.3#diff-8cd8d66c2e6b0f5dbbee58d73962a9e2819ccb420602079f63fcc2089108f8d3))
- ❌ Property removed: `openedFormats`

## 1.0.2
Released on: 6/28/2023, changelog automatically generated.


### Bug Fixes

- pipeline trigger is main ([350df8f](commit/350df8f))

## 1.0.1
Released on: 6/28/2023, changelog automatically generated.


### Bug Fixes

- standard-version configuration ([f426bfc](commit/f426bfc))
- pipeline cmds ([c2bec10](commit/c2bec10))
### Features

- pipeline ([73607fb](commit/73607fb))
- Select barcodes, better BarocdeKitView ([57a49d8](commit/57a49d8))
- VeryGoodAnalysis ([9810b16](commit/9810b16))

### API Changes

#### 💣 Breaking changes

**`class` BarcodeKit** ([lib/src/barcode_kit.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/e4a78b9227630c28acbffc928276fbaa71d467ea..v1.0.1#diff-6c1e62c053047fbc8d516040f9274ece318a413ee92aa5cfd3e6672096caa00c))
- ❌ Property removed: `onTextDetectedCallback`
- ❌ Methods removed: `onTextDetected`, `pauseCamera`, `resumeCamera`, `setOCREnabled`

**`class` BarcodeKitFlutterApi** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/e4a78b9227630c28acbffc928276fbaa71d467ea..v1.0.1#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❌ Method removed: `onTextDetected`

**`class` BarcodeKitHostApi** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/e4a78b9227630c28acbffc928276fbaa71d467ea..v1.0.1#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❌ Methods removed: `setOCREnabled`, `pauseCamera`, `resumeCamera`

**`class` BarcodeKitView** ([lib/src/barcode_kit_view.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/e4a78b9227630c28acbffc928276fbaa71d467ea..v1.0.1#diff-8cd8d66c2e6b0f5dbbee58d73962a9e2819ccb420602079f63fcc2089108f8d3))
- ❌ Properties removed: `enableOCR`, `onTextDetected`, `maskAdditionpauseOpacity`, `widgetAboveMask`, `widgetBelowMask`

**`class` DetectedBarcode** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/e4a78b9227630c28acbffc928276fbaa71d467ea..v1.0.1#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❌ Properties removed: `format`, `textValue`

**`typedef` OnTextDetectedCallback** ([lib/src/barcode_kit.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/e4a78b9227630c28acbffc928276fbaa71d467ea..v1.0.1#diff-6c1e62c053047fbc8d516040f9274ece318a413ee92aa5cfd3e6672096caa00c))
- ❌ Typedef removed: `OnTextDetectedCallback`

**`meta` pubspec.yaml** ([pubspec.yaml](https://github.com/emdgroup/mtrust-barcode-kit/compare/e4a78b9227630c28acbffc928276fbaa71d467ea..v1.0.1#diff-8b7e9df87668ffa6a04b32e1769a33434999e54ae081c52e5d943c541d4c0d25))
- 🎯 Maximum Dart SDK version decreased: from `>=3.3.1 <4.0.0` to `>=2.18.6 <3.0.0`

#### ✨ Minor changes

**`class` BarcodeKitView** ([lib/src/barcode_kit_view.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/e4a78b9227630c28acbffc928276fbaa71d467ea..v1.0.1#diff-8cd8d66c2e6b0f5dbbee58d73962a9e2819ccb420602079f63fcc2089108f8d3))
- ❌ Params removed in default constructor: `onTextDetected` (named, optional), `enableOCR` (named, optional, default: false), `widgetAboveMask` (named, optional), `widgetBelowMask` (named, optional), `maskAdditionpauseOpacity` (named, optional, default: 0.1)

**`class` DetectedBarcode** ([lib/src/pigeon.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/e4a78b9227630c28acbffc928276fbaa71d467ea..v1.0.1#diff-6f7883e658ce56db7488001ea24120f6db668ed2793be484d6f3bd7070bb06d3))
- ❌ Params removed in default constructor: `format` (named, optional), `textValue` (named, optional)

#### 👀 Patch changes

**`class` BarcodeKit** ([lib/src/barcode_kit.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/e4a78b9227630c28acbffc928276fbaa71d467ea..v1.0.1#diff-6c1e62c053047fbc8d516040f9274ece318a413ee92aa5cfd3e6672096caa00c))
- ❌ Method removed: `_convertDataMatrix`

**`class` _BarcodeKitViewState** ([lib/src/barcode_kit_view.dart](https://github.com/emdgroup/mtrust-barcode-kit/compare/e4a78b9227630c28acbffc928276fbaa71d467ea..v1.0.1#diff-8cd8d66c2e6b0f5dbbee58d73962a9e2819ccb420602079f63fcc2089108f8d3))
- ❌ Properties removed: `_lastFormats`, `_unableToOpenCamera`
- ❇️ Property added: `openedFormats`
- ❌ Param removed in method `_wrapInRotatedBox`: `orientation` (named, required)
- ❇️ Param added in method `_wrapInRotatedBox`: `orentation` (named, required)
- ✏️ Param renamed in method `_getQuarterTurns`: `orientation` → `orentation`
- ❌ Method removed: `_buildMaskAdditions`

**`meta` pubspec.yaml** ([pubspec.yaml](https://github.com/emdgroup/mtrust-barcode-kit/compare/e4a78b9227630c28acbffc928276fbaa71d467ea..v1.0.1#diff-8b7e9df87668ffa6a04b32e1769a33434999e54ae081c52e5d943c541d4c0d25))
- 📦 `native_device_orientation` version changed: from `^2.0.3` to `^1.1.4`
- 📦 `permission_handler` version changed: from `^11.3.1` to `^10.3.0`
- 📦 `plugin_platform_interface` version changed: from `^2.1.8` to `^2.0.2`
- 🎯 Minimum Dart SDK version decreased: from `>=3.3.1 <4.0.0` to `>=2.18.6 <3.0.0`
- 🎯 Minimum Flutter SDK version decreased: from `>=3.3.0` to `>=2.5.0`
