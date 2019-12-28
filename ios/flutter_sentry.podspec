#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_sentry.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_sentry'
  s.version          = '0.0.1'
  s.summary          = 'Sentry plugin for Flutter.'
  s.description      = <<-DESC
  Sentry plugin for Flutter.
                       DESC
  s.homepage         = 'https://github.com/dasfoo/flutter_sentry'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Katarina Sheremet' => 'katarina@sheremet.ch' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'Sentry', '~> 4.4'
  s.static_framework = true
  s.platform = :ios, '8.0'

  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.swift_version = '5.0'
end
