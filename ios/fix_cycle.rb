require 'xcodeproj'
project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
runner_target = project.targets.find { |t| t.name == 'Runner' }

# Identify the phases
embed_phase = runner_target.build_phases.find { |p| p.display_name == 'Embed App Extensions' }
if embed_phase
  # Remove it
  runner_target.build_phases.delete(embed_phase)
  
  # Find the index of "Copy Bundle Resources" or "Compile Sources"
  insert_index = 0
  runner_target.build_phases.each_with_index do |phase, index|
    if phase.respond_to?(:name) && phase.name == 'Copy Bundle Resources'
      insert_index = index + 1
    elsif phase.respond_to?(:display_name) && phase.display_name == 'Copy Bundle Resources'
      insert_index = index + 1
    end
  end
  
  # Insert it back
  runner_target.build_phases.insert(insert_index, embed_phase)
  project.save
  puts "Build phases reordered successfully."
else
  puts "Embed App Extensions phase not found."
end
