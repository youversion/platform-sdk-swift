Pod::Spec.new do |s|
  s.name         = 'YouVersionPlatformCore'
  s.module_name  = 'YouVersionPlatformCore'
  s.version      = '0.1.0'
  s.summary      = 'Core layer for YouVersion Platform'
  s.homepage     = 'https://github.com/youversion/yvp-swift-sdk'
  s.license      = { :type => 'Proprietary', :file => 'LICENSE.md' }
  s.author       = 'YouVersion'
  s.source       = { :git => 'https://github.com/youversion/yvp-swift-sdk.git', :tag => s.version.to_s }

  s.platforms      = { :ios => '17.0' }
  s.swift_versions = ['5.9','5.10','6.0']
  s.source_files   = 'Sources/YouVersionPlatformCore/**/*.{swift}'

  s.static_framework = true

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }
end