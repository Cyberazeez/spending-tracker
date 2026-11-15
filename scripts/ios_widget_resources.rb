#!/usr/bin/env ruby
# Repeatable: adds the widget's resources (logo images, Rubik and the riyal-sign font) to the SpendingWidget target
# in app/ios/Runner.xcodeproj without Xcode (rebrand stage 6 follow-up, 2026-11-15).
#   gem install xcodeproj && ruby scripts/ios_widget_resources.rb
# Idempotent: a file already in the target is skipped. The result is committed; this script documents how.
# The fonts are also listed under UIAppFonts in app/ios/SpendingWidget/Info.plist.
require 'xcodeproj'

ROOT = File.expand_path('../app/ios', __dir__)
FILES = %w[HalalaLogo@2x.png HalalaLogo@3x.png Rubik-Bold.ttf Rubik-ExtraBold.ttf SaudiRiyal-Bold.ttf].freeze

project = Xcodeproj::Project.open(File.join(ROOT, 'Runner.xcodeproj'))
widget = project.targets.find { |t| t.name == 'SpendingWidget' } or abort('SpendingWidget target not found')
group = project.main_group['SpendingWidget'] or abort('SpendingWidget group not found')

FILES.each do |name|
  abort("missing app/ios/SpendingWidget/#{name}") unless File.exist?(File.join(ROOT, 'SpendingWidget', name))
  ref = group.files.find { |f| f.path == name } || group.new_file(name)
  if widget.resources_build_phase.files_references.include?(ref)
    puts "#{name}: already in the target"
  else
    widget.resources_build_phase.add_file_reference(ref, true)
    puts "#{name}: added"
  end
end

project.save
