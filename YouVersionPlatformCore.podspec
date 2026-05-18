Pod::Spec.new do |s|
  s.name         = 'YouVersionPlatformCore'
  s.module_name  = 'YouVersionPlatformCore'
  s.version      = '6.0.0'
  s.summary      = 'Core layer for YouVersion Platform'
  s.homepage     = 'https://github.com/youversion/platform-sdk-swift'
  s.license      = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author       = 'YouVersion'
  s.source       = { :git => 'https://github.com/youversion/platform-sdk-swift.git', :tag => s.version.to_s }

  s.platforms      = { :ios => '17.0' }
  s.swift_versions = ['5.9','5.10','6.0']
  s.source_files   = 'Sources/YouVersionPlatformCore/**/*.{swift}'

  s.static_framework = true

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule',
    # SPM passes -package-name automatically based on Package.swift's `name`.
    # CocoaPods does not, so any `package`-access-level symbol fails to build
    # without this flag. Must match Package.swift's package name and be
    # identical across all sibling pods that share `package` symbols.
    'OTHER_SWIFT_FLAGS' => '$(inherited) -package-name YouVersionPlatform'
  }
end
