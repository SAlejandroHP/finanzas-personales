require 'xcodeproj'
require 'fileutils'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Ver si ya existe
if project.targets.any? { |t| t.name == 'ShareExtension' }
  puts "ShareExtension ya existe."
  exit
end

# Crear directorio
ext_dir = 'ShareExtension'
FileUtils.mkdir_p(ext_dir)

# Crear archivos
File.write(File.join(ext_dir, 'ShareViewController.swift'), <<~SWIFT
import UIKit
import Social
import MobileCoreServices
import Photos

class ShareViewController: SLComposeServiceViewController {
    let hostAppBundleIdentifier = "com.saaksolutions.app.finanzas"
    let appGroupId = "group.com.saaksolutions.app.finanzas"
    let sharedKey = "ShareKey"
    var sharedMedia: [SharedMediaFile] = []
    var sharedText: [String] = []
    let imageContentType = kUTTypeImage as String
    let videoContentType = kUTTypeMovie as String
    let textContentType = kUTTypeText as String
    let urlContentType = kUTTypeURL as String
    let fileURLType = kUTTypeFileURL as String

    override func isContentValid() -> Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let content = extensionContext!.inputItems[0] as? NSExtensionItem {
            if let contents = content.attachments {
                for (index, attachment) in (contents).enumerated() {
                    if attachment.hasItemConformingToTypeIdentifier(imageContentType) {
                        handleImages(content: content, attachment: attachment, index: index)
                    } else if attachment.hasItemConformingToTypeIdentifier(textContentType) {
                        handleText(content: content, attachment: attachment, index: index)
                    } else if attachment.hasItemConformingToTypeIdentifier(fileURLType) {
                        handleFiles(content: content, attachment: attachment, index: index)
                    } else if attachment.hasItemConformingToTypeIdentifier(urlContentType) {
                        handleUrl(content: content, attachment: attachment, index: index)
                    } else if attachment.hasItemConformingToTypeIdentifier(videoContentType) {
                        handleVideos(content: content, attachment: attachment, index: index)
                    }
                }
            }
        }
    }

    override func didSelectPost() {
        print("didSelectPost")
    }

    override func configurationItems() -> [Any]! {
        return []
    }

    private func handleText (content: NSExtensionItem, attachment: NSItemProvider, index: Int) {
        attachment.loadItem(forTypeIdentifier: textContentType, options: nil) { [weak self] data, error in
            if error == nil, let item = data as? String, let this = self {
                this.sharedText.append(item)
                if index == (content.attachments?.count ?? 0) - 1 {
                    let userDefaults = UserDefaults(suiteName: this.appGroupId)
                    userDefaults?.set(this.sharedText, forKey: this.sharedKey)
                    userDefaults?.synchronize()
                    this.redirectToHostApp(type: .text)
                }
            }
        }
    }

    private func handleUrl (content: NSExtensionItem, attachment: NSItemProvider, index: Int) {
        attachment.loadItem(forTypeIdentifier: urlContentType, options: nil) { [weak self] data, error in
            if error == nil, let item = data as? URL, let this = self {
                this.sharedText.append(item.absoluteString)
                if index == (content.attachments?.count ?? 0) - 1 {
                    let userDefaults = UserDefaults(suiteName: this.appGroupId)
                    userDefaults?.set(this.sharedText, forKey: this.sharedKey)
                    userDefaults?.synchronize()
                    this.redirectToHostApp(type: .text)
                }
            }
        }
    }

    private func handleImages (content: NSExtensionItem, attachment: NSItemProvider, index: Int) {
        attachment.loadItem(forTypeIdentifier: imageContentType, options: nil) { [weak self] data, error in
            if error == nil, let url = data as? URL, let this = self {
                var fileName = this.getFileName(from: url, type: .image)
                let newPath = FileManager.default
                    .containerURL(forSecurityApplicationGroupIdentifier: this.appGroupId)!
                    .appendingPathComponent(fileName)
                let copied = this.copyFile(at: url, to: newPath)
                if copied {
                    this.sharedMedia.append(SharedMediaFile(path: newPath.absoluteString, thumbnail: nil, duration: nil, type: .image))
                }
                if index == (content.attachments?.count ?? 0) - 1 {
                    let userDefaults = UserDefaults(suiteName: this.appGroupId)
                    userDefaults?.set(this.toData(data: this.sharedMedia), forKey: this.sharedKey)
                    userDefaults?.synchronize()
                    this.redirectToHostApp(type: .media)
                }
            }
        }
    }

    private func handleVideos (content: NSExtensionItem, attachment: NSItemProvider, index: Int) {
        attachment.loadItem(forTypeIdentifier: videoContentType, options: nil) { [weak self] data, error in
            if error == nil, let url = data as? URL, let this = self {
                var fileName = this.getFileName(from: url, type: .video)
                let newPath = FileManager.default
                    .containerURL(forSecurityApplicationGroupIdentifier: this.appGroupId)!
                    .appendingPathComponent(fileName)
                let copied = this.copyFile(at: url, to: newPath)
                if copied {
                    this.sharedMedia.append(SharedMediaFile(path: newPath.absoluteString, thumbnail: nil, duration: nil, type: .video))
                }
                if index == (content.attachments?.count ?? 0) - 1 {
                    let userDefaults = UserDefaults(suiteName: this.appGroupId)
                    userDefaults?.set(this.toData(data: this.sharedMedia), forKey: this.sharedKey)
                    userDefaults?.synchronize()
                    this.redirectToHostApp(type: .media)
                }
            }
        }
    }

    private func handleFiles (content: NSExtensionItem, attachment: NSItemProvider, index: Int) {
        attachment.loadItem(forTypeIdentifier: fileURLType, options: nil) { [weak self] data, error in
            if error == nil, let url = data as? URL, let this = self {
                var fileName = this.getFileName(from: url, type: .file)
                let newPath = FileManager.default
                    .containerURL(forSecurityApplicationGroupIdentifier: this.appGroupId)!
                    .appendingPathComponent(fileName)
                let copied = this.copyFile(at: url, to: newPath)
                if copied {
                    this.sharedMedia.append(SharedMediaFile(path: newPath.absoluteString, thumbnail: nil, duration: nil, type: .file))
                }
                if index == (content.attachments?.count ?? 0) - 1 {
                    let userDefaults = UserDefaults(suiteName: this.appGroupId)
                    userDefaults?.set(this.toData(data: this.sharedMedia), forKey: this.sharedKey)
                    userDefaults?.synchronize()
                    this.redirectToHostApp(type: .media)
                }
            }
        }
    }

    private func redirectToHostApp(type: RedirectType) {
        let url = URL(string: "ShareMedia-\\(hostAppBundleIdentifier)://dataUrl=\\(sharedKey)#\\(type)")
        var responder = self as UIResponder?
        let selectorOpenURL = sel_registerName("openURL:")

        while (responder != nil) {
            if (responder?.responds(to: selectorOpenURL))! {
                let _ = responder?.perform(selectorOpenURL, with: url)
            }
            responder = responder!.next
        }
        extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    enum RedirectType {
        case media
        case text
        case file
    }

    func getExtension(from url: URL, type: SharedMediaType) -> String {
        let parts = url.lastPathComponent.components(separatedBy: ".")
        var ex: String? = nil
        if (parts.count > 1) {
            ex = parts.last
        }

        if (ex == nil) {
            switch type {
            case .image:
                ex = "PNG"
            case .video:
                ex = "MP4"
            case .file:
                ex = "TXT"
            }
        }
        return ex ?? "Unknown"
    }

    func getFileName(from url: URL, type: SharedMediaType) -> String {
        var name = url.lastPathComponent
        if (name == "") {
            name = UUID().uuidString + "." + getExtension(from: url, type: type)
        }
        return name
    }

    func copyFile(at srcURL: URL, to dstURL: URL) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: dstURL.path) {
                try FileManager.default.removeItem(at: dstURL)
            }
            try FileManager.default.copyItem(at: srcURL, to: dstURL)
        } catch (let error) {
            print("Cannot copy item at \\(srcURL) to \\(dstURL): \\(error)")
            return false
        }
        return true
    }

    func toData(data: Any) -> Data {
        let encodedData = try? JSONEncoder().encode(data as? [SharedMediaFile])
        return encodedData!
    }
}

class SharedMediaFile: Codable {
    var path: String
    var thumbnail: String?
    var duration: Double?
    var type: SharedMediaType

    init(path: String, thumbnail: String?, duration: Double?, type: SharedMediaType) {
        self.path = path
        self.thumbnail = thumbnail
        self.duration = duration
        self.type = type
    }
}

enum SharedMediaType: Int, Codable {
    case image
    case video
    case file
}
SWIFT
)

File.write(File.join(ext_dir, 'Info.plist'), <<~PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>Share</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>NSExtensionActivationRule</key>
            <dict>
                <key>NSExtensionActivationSupportsImageWithMaxCount</key>
                <integer>100</integer>
                <key>NSExtensionActivationSupportsMovieWithMaxCount</key>
                <integer>100</integer>
                <key>NSExtensionActivationSupportsText</key>
                <true/>
                <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
                <integer>1</integer>
            </dict>
        </dict>
        <key>NSExtensionMainStoryboard</key>
        <string>MainInterface</string>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.share-services</string>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
    </dict>
    <key>AppGroupId</key>
    <string>group.com.saaksolutions.app.finanzas</string>
</dict>
</plist>
PLIST
)

File.write(File.join(ext_dir, 'ShareExtension.entitlements'), <<~ENTITLEMENTS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.saaksolutions.app.finanzas</string>
    </array>
</dict>
</plist>
ENTITLEMENTS
)

# Entitlements para el Runner principal
runner_entitlements_path = 'Runner/Runner.entitlements'
File.write(runner_entitlements_path, <<~ENTITLEMENTS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.saaksolutions.app.finanzas</string>
    </array>
</dict>
</plist>
ENTITLEMENTS
)

# Agregarlo al proyecto
main_group = project.main_group
ext_group = main_group.new_group('ShareExtension', 'ShareExtension')

swift_ref = ext_group.new_reference('ShareViewController.swift')
plist_ref = ext_group.new_reference('Info.plist')
ent_ref = ext_group.new_reference('ShareExtension.entitlements')

runner_group = main_group.find_subpath('Runner', false)
runner_ent_ref = runner_group.new_reference('Runner.entitlements') rescue nil

# Crear el target
ext_target = project.new_target(:app_extension, 'ShareExtension', :ios, '12.0')
ext_target.product_name = 'ShareExtension'

# Configurar build settings
ext_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = 'ShareExtension/Info.plist'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'ShareExtension/ShareExtension.entitlements'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.saaksolutions.app.finanzas.ShareExtension'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = project.targets.first.build_configurations.first.build_settings['DEVELOPMENT_TEAM'] || ""
end

# Añadir fuente
ext_target.source_build_phase.add_file_reference(swift_ref)

# Configurar entitlements en el Runner
runner_target = project.targets.find { |t| t.name == 'Runner' }
runner_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# Añadir dependencia: Runner depende de ShareExtension
project.targets.find { |t| t.name == 'Runner' }.add_dependency(ext_target)

# Crear un Copy Files Build Phase para embeber la extensión en el App
embed_phase = runner_target.new_copy_files_build_phase('Embed App Extensions')
embed_phase.symbol_dst_subfolder_spec = :plug_ins
embed_phase.add_file_reference(ext_target.product_reference)

project.save
puts "ShareExtension añadido y configurado con éxito."
