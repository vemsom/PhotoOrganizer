#!/usr/bin/env ruby
# Genererar PhotoOrganizer.xcodeproj

$LOAD_PATH.unshift(*Dir.glob(File.expand_path('~/.gem/ruby/*/gems/*/lib')))
require 'fileutils'
require 'xcodeproj'

root = File.expand_path(File.dirname(__FILE__))
project_path = File.join(root, 'PhotoOrganizer.xcodeproj')
src_root    = File.join(root, 'PhotoOrganizer')

FileUtils.rm_rf(project_path)
project = Xcodeproj::Project.new(project_path)
project.root_object.attributes['LastSwiftUpdateCheck'] = '1600'
project.root_object.attributes['LastUpgradeCheck'] = '1600'

# Target
target = project.new_target(:application, 'PhotoOrganizer', :osx, '13.0')

# Swift + bundle config
target.build_configurations.each do |c|
  c.build_settings['SWIFT_VERSION'] = '5.0'
  c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'se.fredrik.PhotoOrganizer'
  c.build_settings['PRODUCT_NAME'] = 'PhotoOrganizer'
  c.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
  c.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  c.build_settings['CODE_SIGN_IDENTITY'] = '-'
  c.build_settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
  c.build_settings['COMBINE_HIDPI_IMAGES'] = 'YES'
  c.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  c.build_settings['INFOPLIST_KEY_NSHumanReadableCopyright'] = ''
  c.build_settings['INFOPLIST_KEY_NSPrincipalClass'] = 'NSApplication'
  c.build_settings['INFOPLIST_KEY_LSApplicationCategoryType'] = 'public.app-category.photography'
  c.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'PhotoOrganizer'
  c.build_settings['INFOPLIST_KEY_CFBundleIconFile'] = 'icon'
  c.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  c.build_settings['ENABLE_PREVIEWS'] = 'YES'
  c.build_settings['DEVELOPMENT_ASSET_PATHS'] = '"PhotoOrganizer/Preview Content"'
  c.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../Frameworks']
end

# Group-struktur
main_group = project.main_group.new_group('PhotoOrganizer', 'PhotoOrganizer')

swift_files = [
  'PhotoOrganizerApp.swift',
  'ContentView.swift',
  'Views/FolderPickerView.swift',
  'Views/PlanPreviewView.swift',
  'Views/ProgressOverlayView.swift',
  'Views/SummaryView.swift',
  'Core/PhotoScanner.swift',
  'Core/ExifReader.swift',
  'Core/DNGConverter.swift',
  'Core/TargetPathResolver.swift',
  'Core/PlanBuilder.swift',
  'Core/OperationRunner.swift',
  'Core/OperationLog.swift',
  'Models/PhotoFile.swift',
  'Models/FolderContext.swift',
  'Models/PlannedOperation.swift',
]

# Skapa grupper och filreferenser
group_cache = { '' => main_group }
def group_for(path, group_cache, main_group)
  return main_group if path == '' || path == '.'
  return group_cache[path] if group_cache[path]
  parent = group_for(File.dirname(path) == '.' ? '' : File.dirname(path), group_cache, main_group)
  g = parent.new_group(File.basename(path), File.basename(path))
  group_cache[path] = g
  g
end

swift_files.each do |rel|
  dir = File.dirname(rel)
  g = group_for(dir == '.' ? '' : dir, group_cache, main_group)
  file_ref = g.new_reference(File.basename(rel))
  target.add_file_references([file_ref])
end

# Assets.xcassets
assets_dir = File.join(src_root, 'Assets.xcassets')
FileUtils.mkdir_p(File.join(assets_dir, 'AppIcon.appiconset'))
File.write(File.join(assets_dir, 'Contents.json'), %({\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n))
File.write(File.join(assets_dir, 'AppIcon.appiconset', 'Contents.json'), %({\n  "images" : [],\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n))
assets_ref = main_group.new_reference('Assets.xcassets')
target.resources_build_phase.add_file_reference(assets_ref)

# Preview Content
preview_dir = File.join(src_root, 'Preview Content', 'Preview Assets.xcassets')
FileUtils.mkdir_p(preview_dir)
File.write(File.join(preview_dir, 'Contents.json'), %({\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n))
preview_group = main_group.new_group('Preview Content', 'Preview Content')
preview_ref = preview_group.new_reference('Preview Assets.xcassets')
target.resources_build_phase.add_file_reference(preview_ref)

# Bundla in dnglab-binären i appens Resources/
resources_group = main_group.new_group('Resources', 'Resources')
dnglab_ref = resources_group.new_reference('dnglab')
target.resources_build_phase.add_file_reference(dnglab_ref)

# Ikon
icon_ref = resources_group.new_reference('icon.icns')
target.resources_build_phase.add_file_reference(icon_ref)

# Entitlements (minimal – ingen sandbox för enkel filåtkomst)
ent_path = File.join(src_root, 'PhotoOrganizer.entitlements')
File.write(ent_path, <<~PLIST)
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
  </dict>
  </plist>
PLIST
ent_ref = main_group.new_reference('PhotoOrganizer.entitlements')
target.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'PhotoOrganizer/PhotoOrganizer.entitlements'
end

project.save
puts "Skapade #{project_path}"

# Skriv ett delat schema s\u00e5 target-UUID matchar
schemes_dir = File.join(project_path, 'xcshareddata', 'xcschemes')
FileUtils.mkdir_p(schemes_dir)
target_uuid = target.uuid
scheme_xml = <<~XML
  <?xml version="1.0" encoding="UTF-8"?>
  <Scheme LastUpgradeVersion="1600" version="1.7">
     <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
        <BuildActionEntries>
           <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
              <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="#{target_uuid}" BuildableName="PhotoOrganizer.app" BlueprintName="PhotoOrganizer" ReferencedContainer="container:PhotoOrganizer.xcodeproj"></BuildableReference>
           </BuildActionEntry>
        </BuildActionEntries>
     </BuildAction>
     <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"></TestAction>
     <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
        <BuildableProductRunnable runnableDebuggingMode="0">
           <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="#{target_uuid}" BuildableName="PhotoOrganizer.app" BlueprintName="PhotoOrganizer" ReferencedContainer="container:PhotoOrganizer.xcodeproj"></BuildableReference>
        </BuildableProductRunnable>
     </LaunchAction>
     <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
        <BuildableProductRunnable runnableDebuggingMode="0">
           <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="#{target_uuid}" BuildableName="PhotoOrganizer.app" BlueprintName="PhotoOrganizer" ReferencedContainer="container:PhotoOrganizer.xcodeproj"></BuildableReference>
        </BuildableProductRunnable>
     </ProfileAction>
     <AnalyzeAction buildConfiguration="Debug"></AnalyzeAction>
     <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"></ArchiveAction>
  </Scheme>
XML
File.write(File.join(schemes_dir, 'PhotoOrganizer.xcscheme'), scheme_xml)
puts "Skrev delat schema"
