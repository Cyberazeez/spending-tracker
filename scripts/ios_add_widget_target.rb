#!/usr/bin/env ruby
# One-off, repeatable: adds the SpendingWidget extension to app/ios/Runner.xcodeproj without Xcode.
#   gem install xcodeproj && ruby scripts/ios_add_widget_target.rb
# It is idempotent: it stops if the target already exists. The result is committed; this script documents how.
require 'xcodeproj'

ROOT = File.expand_path('../app/ios', __dir__)
project = Xcodeproj::Project.open(File.join(ROOT, 'Runner.xcodeproj'))
runner = project.targets.find { |t| t.name == 'Runner' } or abort('Runner target not found')
if project.targets.any? { |t| t.name == 'SpendingWidget' }
  puts 'SpendingWidget already present'
  exit 0
end

APP_ID = 'com.cyberazeez.spendingtracker'
WIDGET_ID = "#{APP_ID}.widget"

# 1. Files
widget_group = project.main_group.new_group('SpendingWidget', 'SpendingWidget')
swift_ref = widget_group.new_file('SpendingWidget.swift')
widget_group.new_file('Info.plist')
widget_group.new_file('SpendingWidget.entitlements')
runner_group = project.main_group['Runner']
runner_group.new_file('Runner.entitlements')

# 2. Target
ext = project.new_target(:app_extension, 'SpendingWidget', :ios, '16.0')
ext.add_file_references([swift_ref])
# WidgetKit and SwiftUI are linked automatically by `import` (no hard-coded SDK paths in the project file).
# new_target adds a Foundation.framework reference with a hard-coded SDK path; drop it (Swift links Foundation too).
ext.frameworks_build_phase.files.to_a.each do |build_file|
  build_file.file_ref&.remove_from_project
  build_file.remove_from_project
end
project.frameworks_group.remove_from_project if project.frameworks_group.children.empty?

runner_configs = runner.build_configurations.to_h { |c| [c.name, c] }
ext.build_configurations.each do |config|
  # Same Flutter xcconfig as Runner, so $(FLUTTER_BUILD_NAME) / $(FLUTTER_BUILD_NUMBER) exist here too.
  source = runner_configs[config.name] || runner_configs['Release']
  config.base_configuration_reference = source.base_configuration_reference
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => WIDGET_ID,
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'INFOPLIST_FILE' => 'SpendingWidget/Info.plist',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'CODE_SIGN_ENTITLEMENTS' => 'SpendingWidget/SpendingWidget.entitlements',
    'SWIFT_VERSION' => '5.0',
    'TARGETED_DEVICE_FAMILY' => '1',
    'IPHONEOS_DEPLOYMENT_TARGET' => '16.0',
    'MARKETING_VERSION' => '$(FLUTTER_BUILD_NAME)',
    'CURRENT_PROJECT_VERSION' => '$(FLUTTER_BUILD_NUMBER)',
    'SKIP_INSTALL' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'],
    'CODE_SIGN_STYLE' => 'Automatic'
  )
end

# 3. Runner embeds the extension and shares the App Group
runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end
runner.add_dependency(ext)
embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
build_file = embed.add_file_reference(ext.product_reference, true)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# Flutter's "Thin Binary" script must run after the embed phase, or Xcode reports a build cycle.
thin = runner.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
if thin
  runner.build_phases.delete(embed)
  runner.build_phases.insert(runner.build_phases.index(thin), embed)
end

project.save
puts "Added SpendingWidget (#{WIDGET_ID}) and embedded it in Runner"
