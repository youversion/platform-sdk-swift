Pod::Spec.new do |s|
  s.name         = 'YouVersionPlatform'
  s.module_name  = 'YouVersionPlatform'
  s.version      = '0.1.0'
  s.summary      = 'YouVersion Platform features'
  s.homepage     = 'https://github.com/youversion/platform-sdk-swift'
  s.license      = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author       = 'YouVersion'
  s.source       = { :git => 'https://github.com/youversion/platform-sdk-swift.git', :tag => s.version.to_s }

  s.platforms      = { :ios => '17.0' }
  s.swift_versions = ['5.9','5.10','6.0']
  s.source_files   = 'Sources/YouVersionPlatformAll/**/*.{swift}'
  s.static_framework = true

  s.dependency 'YouVersionPlatformCore',   s.version.to_s
  s.dependency 'YouVersionPlatformUI',     s.version.to_s
  s.dependency 'YouVersionPlatformReader', s.version.to_s

  s.resource_bundles = {
  'YouVersionPlatformResources' => [
    'Sources/YouVersionPlatformUI/Resources/**/*',
    'Sources/YouVersionPlatformReader/Resources/**/*'
  ]
}

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }
end
