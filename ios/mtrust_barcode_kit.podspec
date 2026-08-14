#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint barcode_kit.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'mtrust_barcode_kit'
  s.version          = '0.0.1'
  s.summary          = 'Read barcodes using the camera'
  s.description      = <<-DESC
  Barcode-Kit is a flutter package that allows you to read barcodes 
  using the camera. It uses native textures to display the camera feed and the
  barcode overlay. It is built on top of the Google ML Kit and iOS Vision for
  barcode scanning.
                       DESC
  s.homepage         = 'https://github.com/emdgroup/mtrust-barcode-kit'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'EMD Group' => 'info@emdgroup.com' }
  s.source           = { :path => '.' }
  s.source_files = 'mtrust_barcode_kit/Sources/mtrust_barcode_kit/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.module_name = 'mtrust_barcode_kit'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
