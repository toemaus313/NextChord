//
//  ShareViewController.swift
//  NextChord
//
//  Created by Tommy Antonovich on 11/25/25.
//

import UIKit
import UniformTypeIdentifiers

private let kSchemePrefix = "ShareMedia"

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

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedContent()
    }

    private func handleSharedContent() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeRequest()
            return
        }

        sharedItems.removeAll()
        let group = DispatchGroup()

        for item in extensionItems {
            guard let attachments = item.attachments else { 
                continue 
            }

            for provider in attachments {
                group.enter()

                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] data, _ in
                        defer { group.leave() }
                        if let url = data as? URL {
                            
                            // Check if it's a file URL - if so, read the content
                            if url.isFileURL {
                                do {
                                    let fileContent = try String(contentsOf: url, encoding: .utf8)
                                    // Pass the file content as TEXT, not URL
                                    self?.appendSharedItem(path: fileContent, mimeType: "text/plain", type: .text)
                                } catch {
                                    // Fall back to passing the URL if reading fails
                                    self?.appendSharedItem(path: url.absoluteString, type: .url)
                                }
                            } else {
                                // It's a web URL, pass it as-is
                                self?.appendSharedItem(path: url.absoluteString, type: .url)
                            }
                        } else {
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] data, _ in
                        defer { group.leave() }
                        if let text = data as? String {
                            self?.appendSharedItem(path: text, mimeType: "text/plain", type: .text)
                        } else {
                        }
                    }
                } else {
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
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
        guard !sharedItems.isEmpty else {
            completeRequest()
            return
        }

        // Encode shared items as JSON and base64 for URL passing
        // Since we removed App Groups, pass data directly through the URL
        guard let jsonData = try? JSONEncoder().encode(sharedItems),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            completeRequest()
            return
        }
        
        // Base64 encode to make URL-safe
        let base64Data = Data(jsonString.utf8).base64EncodedString()
        
        // URL encode the base64 string
        guard let encodedData = base64Data.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completeRequest()
            return
        }

        // Pass data through URL query parameter (no App Groups needed)
        let urlString = "\(kSchemePrefix)-\(hostAppBundleIdentifier):share?data=\(encodedData)"
        
        if let url = URL(string: urlString) {
            openURL(url)
        } else {
        }

        completeRequest()
    }
    
    private func openURL(_ url: URL) {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = responder?.next
        }
        // Fallback for iOS 13+
        let selector = sel_registerName("openURL:")
        var responder2: UIResponder? = self
        while responder2 != nil {
            if responder2!.responds(to: selector) {
                responder2!.perform(selector, with: url)
                return
            }
            responder2 = responder2?.next
        }
    }
    
    private func completeRequest() {
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
