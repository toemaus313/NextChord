//
//  ShareViewController.swift
//  NextChord
//
//  Created by Tommy Antonovich on 11/25/25.
//

import UIKit
import UniformTypeIdentifiers

private let kSchemePrefix = "ShareMedia"
private let kUserDefaultsKey = "ShareKey"
private let kUserDefaultsMessageKey = "ShareMessageKey"
private let kAppGroupIdKey = "AppGroupId"

// Global debug function for iOS share extension
func myDebug(_ message: String) {
    let timestamp = DateFormatter.timeStamp.string(from: Date())
    print("[\(timestamp)] ShareViewController: \(message)")
}

private extension DateFormatter {
    static let timeStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

class ShareViewController: UIViewController {
    private var sharedItems: [SharedMediaFile] = []

    private var hostAppBundleIdentifier: String {
        guard
            let bundleIdentifier = Bundle.main.bundleIdentifier,
            let lastDot = bundleIdentifier.lastIndex(of: ".")
        else {
            return ""
        }
        return String(bundleIdentifier[..<lastDot])
    }

    private var appGroupId: String {
        if let customGroupId = Bundle.main.object(forInfoDictionaryKey: kAppGroupIdKey) as? String,
           !customGroupId.isEmpty {
            return customGroupId
        }
        return "group.\(hostAppBundleIdentifier)"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        myDebug("ShareViewController: viewDidLoad called - TESTING DEBUG OUTPUT")
        myDebug("ShareViewController: Bundle ID: \(Bundle.main.bundleIdentifier ?? "UNKNOWN")")
        myDebug("ShareViewController: Host App Bundle ID: \(hostAppBundleIdentifier)")
        myDebug("ShareViewController: App Group ID: \(appGroupId)")
        handleSharedContent()
    }

    private func handleSharedContent() {
        myDebug("ShareViewController: handleSharedContent called")
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            myDebug("ShareViewController: No extension items, completing request")
            completeRequest()
            return
        }

        myDebug("ShareViewController: Found \(extensionItems.count) extension items")
        sharedItems.removeAll()
        let group = DispatchGroup()

        for item in extensionItems {
            guard let attachments = item.attachments else { 
                myDebug("ShareViewController: No attachments for item")
                continue 
            }

            myDebug("ShareViewController: Found \(attachments.count) attachments")
            for provider in attachments {
                group.enter()

                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    myDebug("ShareViewController: Loading URL content")
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] data, _ in
                        defer { group.leave() }
                        if let url = data as? URL {
                            myDebug("ShareViewController: Loaded URL: \(url.absoluteString)")
                            
                            // Check if it's a file URL - if so, read the content
                            if url.isFileURL {
                                myDebug("ShareViewController: Detected file URL, attempting to read content")
                                do {
                                    let fileContent = try String(contentsOf: url, encoding: .utf8)
                                    myDebug("ShareViewController: Successfully read file, content length: \(fileContent.count)")
                                    // Pass the file content as TEXT, not URL
                                    self?.appendSharedItem(path: fileContent, mimeType: "text/plain", type: .text)
                                } catch {
                                    myDebug("ShareViewController: Failed to read file: \(error.localizedDescription)")
                                    // Fall back to passing the URL if reading fails
                                    self?.appendSharedItem(path: url.absoluteString, type: .url)
                                }
                            } else {
                                // It's a web URL, pass it as-is
                                self?.appendSharedItem(path: url.absoluteString, type: .url)
                            }
                        } else {
                            myDebug("ShareViewController: Failed to load URL content")
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    myDebug("ShareViewController: Loading text content")
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] data, _ in
                        defer { group.leave() }
                        if let text = data as? String {
                            myDebug("ShareViewController: Loaded text: \(text.prefix(100))...")
                            self?.appendSharedItem(path: text, mimeType: "text/plain", type: .text)
                        } else {
                            myDebug("ShareViewController: Failed to load text content")
                        }
                    }
                } else {
                    myDebug("ShareViewController: Unsupported content type")
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            myDebug("ShareViewController: All content loaded, saving and redirecting")
            self?.saveAndRedirect()
        }
    }

    private func appendSharedItem(path: String, mimeType: String? = nil, type: SharedMediaType) {
        sharedItems.append(
            SharedMediaFile(
                path: path,
                mimeType: mimeType,
                thumbnail: nil,
                duration: nil,
                message: nil,
                type: type
            )
        )
    }

    private func saveAndRedirect() {
        myDebug("ShareViewController: saveAndRedirect called with \(sharedItems.count) items")
        guard !sharedItems.isEmpty else {
            myDebug("ShareViewController: No shared items, completing request")
            completeRequest()
            return
        }

        let userDefaults = UserDefaults(suiteName: appGroupId)
        myDebug("ShareViewController: Using app group ID: \(appGroupId)")

        if let data = try? JSONEncoder().encode(sharedItems) {
            userDefaults?.set(data, forKey: kUserDefaultsKey)
            userDefaults?.removeObject(forKey: kUserDefaultsMessageKey)
            userDefaults?.synchronize()
            myDebug("ShareViewController: Saved shared data to UserDefaults")
        } else {
            myDebug("ShareViewController: Failed to encode shared items")
        }

        let urlString = "\(kSchemePrefix)-\(hostAppBundleIdentifier):share"
        myDebug("ShareViewController: Opening URL: \(urlString)")
        
        if let url = URL(string: urlString) {
            openURL(url)
        } else {
            myDebug("ShareViewController: Failed to create URL")
        }

        completeRequest()
    }
    
    private func openURL(_ url: URL) {
        myDebug("ShareViewController: openURL called with: \(url)")
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                myDebug("ShareViewController: Found UIApplication, opening URL")
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = responder?.next
        }
        
        myDebug("ShareViewController: UIApplication not found, trying fallback")
        // Fallback for iOS 13+
        let selector = sel_registerName("openURL:")
        var responder2: UIResponder? = self
        while responder2 != nil {
            if responder2!.responds(to: selector) {
                myDebug("ShareViewController: Found responder for openURL selector")
                responder2!.perform(selector, with: url)
                return
            }
            responder2 = responder2?.next
        }
        
        myDebug("ShareViewController: No responder found for opening URL")
    }
    
    private func completeRequest() {
        myDebug("ShareViewController: completeRequest called")
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

private struct SharedMediaFile: Codable {
    let path: String
    let mimeType: String?
    let thumbnail: String?
    let duration: Double?
    let message: String?
    let type: SharedMediaType
}

private enum SharedMediaType: String, Codable {
    case image
    case video
    case text
    case file
    case url
}
