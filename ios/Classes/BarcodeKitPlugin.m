#import "BarcodeKitPlugin.h"
#if __has_include(<mtrust_barcode_kit/mtrust_barcode_kit-Swift.h>)
#import <mtrust_barcode_kit/mtrust_barcode_kit-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "mtrust_barcode_kit-Swift.h"
#endif

@implementation BarcodeKitPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftBarcodeKitPlugin registerWithRegistrar:registrar];
}
@end
