require 'xcodeproj'
project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

widget_target = project.targets.find { |t| t.name == 'SaakWidgetExtension' }
runner_group = project.main_group.find_subpath('Runner', false)

if runner_group
  file_ref = runner_group.files.find { |f| f.path == 'AppIntents.swift' }
  if widget_target && file_ref
    unless widget_target.source_build_phase.files_references.include?(file_ref)
      widget_target.source_build_phase.add_file_reference(file_ref)
      project.save
      puts "Successfully added AppIntents.swift to SaakWidgetExtension"
    else
      puts "Already added"
    end
  else
    puts "Target or file not found"
  end
else
  puts "Runner group not found"
end
