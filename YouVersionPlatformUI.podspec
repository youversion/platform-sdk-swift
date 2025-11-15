Pod::Spec.new do |s|
  s.name         = 'YouVersionPlatformUI'
  s.module_name  = 'YouVersionPlatformUI'
  s.version      = '0.1.0'
  s.summary      = 'UI components for YouVersion Platform'
  s.homepage     = 'https://github.com/youversion/platform-sdk-swift'
  s.license      = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author       = 'YouVersion'
  s.source       = { :git => 'https://github.com/youversion/platform-sdk-swift.git', :tag => s.version.to_s }
  s.platforms      = { :ios => '17.0' }
  s.swift_versions = ['5.9','5.10','6.0']
  s.source_files   = 'Sources/YouVersionPlatformUI/**/*.{swift}'

  s.dependency 'YouVersionPlatformCore', s.version.to_s

  s.static_framework = true

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }
end
