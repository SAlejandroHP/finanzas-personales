require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

runner_target = project.targets.find { |t| t.name == 'Runner' }
runner_group = project.main_group.find_subpath('Runner', false)

# Crear la referencia al archivo si no existe
swift_file_path = 'AppIntents.swift'
unless runner_group.files.any? { |f| f.path == swift_file_path }
  swift_ref = runner_group.new_reference(swift_file_path)
  
  # Añadir a la build phase "Compile Sources"
  runner_target.source_build_phase.add_file_reference(swift_ref)
  puts "AppIntents.swift añadido a Compile Sources del Runner."
else
  puts "AppIntents.swift ya existía en el proyecto."
end

project.save
puts "Proyecto guardado correctamente."
