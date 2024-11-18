import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mtrust_barcode_kit/src/barcode_kit_platform_interface.dart';

/// An implementation of [BarcodeKitPlatform] that uses method channels.
class MethodChannelBarcodeKit extends BarcodeKitPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('barcode_kit');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
