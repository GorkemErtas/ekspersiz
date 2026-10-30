Pod::Spec.new do |s|
  s.name = 'EkspersizNative'
  s.version = '1.0.0'
  s.summary = 'Ekspersiz installation and bounded private image preparation'
  s.description = s.summary
  s.license = { :type => 'MIT' }
  s.author = 'Ekspersiz'
  s.homepage = 'https://github.com/GorkemErtas/ekspersiz'
  s.platforms = { :ios => '15.1' }
  s.source = { :git => 'https://github.com/GorkemErtas/ekspersiz.git', :tag => s.version.to_s }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.source_files = '**/*.{h,m,mm,swift}'
end
