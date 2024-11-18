import 'package:mtrust_barcode_kit/src/barcode_kit_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The interface that implementations of barcode_kit must implement.
abstract class BarcodeKitPlatform extends PlatformInterface {
  /// Constructs a BarcodeKitPlatform.
  BarcodeKitPlatform() : super(token: _token);

  static final Object _token = Object();

  static BarcodeKitPlatform _instance = MethodChannelBarcodeKit();

  /// The default instance of [BarcodeKitPlatform] to use.
  ///
  /// Defaults to [MethodChannelBarcodeKit].
  static BarcodeKitPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [BarcodeKitPlatform] when
  /// they register themselves.
  static set instance(BarcodeKitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Requests the platform version.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
