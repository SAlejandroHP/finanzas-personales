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
        let url = URL(string: "ShareMedia-\(hostAppBundleIdentifier)://dataUrl=\(sharedKey)#\(type)")
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
            print("Cannot copy item at \(srcURL) to \(dstURL): \(error)")
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
