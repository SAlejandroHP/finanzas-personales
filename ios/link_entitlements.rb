require 'xcodeproj'
project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

widget_target = project.targets.find { |t| t.name == 'SaakWidgetExtension' }
if widget_target
  widget_target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'SaakWidget/SaakWidgetExtension.entitlements'
  end
  project.save
  puts "Linked entitlements to widget target"
else
  puts "Widget target not found"
end
