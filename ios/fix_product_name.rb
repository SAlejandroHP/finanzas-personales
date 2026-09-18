require 'xcodeproj'
project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
ext_target = project.targets.find { |t| t.name == 'ShareExtension' }
if ext_target
  ext_target.build_configurations.each do |config|
    config.build_settings['PRODUCT_NAME'] = 'ShareExtension'
  end
  project.save
  puts "PRODUCT_NAME set to ShareExtension"
else
  puts "Target not found"
end
