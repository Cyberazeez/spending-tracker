#!/usr/bin/env ruby
# One-off, repeatable: adds the native capture sources to the Runner target and raises its iOS minimum to 16.0
# (App Intents need iOS 16), without Xcode.  ruby scripts/ios_add_runner_sources.rb   (needs the xcodeproj gem)
# Idempotent: files already in the project are skipped.
require 'xcodeproj'

ROOT = File.expand_path('../app/ios', __dir__)
project = Xcodeproj::Project.open(File.join(ROOT, 'Runner.xcodeproj'))
runner = project.targets.find { |t| t.name == 'Runner' } or abort('Runner target not found')
group = project.main_group['Runner'] or abort('Runner group not found')

%w[CaptureStore.swift AddBankMessageIntent.swift].each do |name|
  if group.files.any? { |f| f.path == name }
    puts "#{name} already present"
    next
  end
  ref = group.new_file(name)
  runner.add_file_references([ref])
  puts "Added #{name}"
end

runner.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
end
project.save
