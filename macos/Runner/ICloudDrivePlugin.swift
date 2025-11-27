import FlutterMacOS
import Foundation
import AppKit

/// Plugin for iCloud Drive operations on macOS
public class ICloudDrivePlugin: NSObject, FlutterPlugin {
    private static let channelName = "icloud_drive"
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger)
        let instance = ICloudDrivePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isICloudDriveAvailable":
            isICloudDriveAvailable(result: result)
        case "getICloudDriveFolderPath":
            getICloudDriveFolderPath(result: result)
        case "ensureNextChordFolder":
            ensureNextChordFolder(result: result)
        case "uploadFile":
            uploadFile(call: call, result: result)
        case "downloadFile":
            downloadFile(call: call, result: result)
        case "getFileMetadata":
            getFileMetadata(call: call, result: result)
        case "fileExists":
            fileExists(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    /// Check if iCloud Drive is available and enabled
    private func isICloudDriveAvailable(result: @escaping FlutterResult) {
        guard let ubiquityContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            result(false)
            return
        }
        
        // Basic check: if we can resolve a ubiquity container URL, treat iCloud
        // Drive as available. More detailed status checks can be added later if
        // needed, but older URLResourceKey-based APIs are deprecated.
        let documentsPath = ubiquityContainer.appendingPathComponent("Documents")
        _ = documentsPath // avoid unused variable warning for now
        result(true)
    }
    
    /// Get the path to the iCloud Drive Documents folder
    private func getICloudDriveFolderPath(result: @escaping FlutterResult) {
        guard let ubiquityContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            result(nil)
            return
        }
        
        let documentsPath = ubiquityContainer.appendingPathComponent("Documents")
        result(documentsPath.path)
    }
    
    /// Ensure NextChord folder exists in iCloud Drive Documents
    private func ensureNextChordFolder(result: @escaping FlutterResult) {
        guard let ubiquityContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            result(false)
            return
        }
        
        let documentsPath = ubiquityContainer.appendingPathComponent("Documents")
        let nextChordPath = documentsPath.appendingPathComponent("NextChord")
        
        do {
            // Create NextChord folder if it doesn't exist
            try FileManager.default.createDirectory(at: nextChordPath, 
                                                   withIntermediateDirectories: true, 
                                                   attributes: nil)
            
            // Start downloading the folder if it's not already downloaded
            try FileManager.default.startDownloadingUbiquitousItem(at: nextChordPath)
            
            result(true)
        } catch {
            print("Error creating NextChord folder: \(error)")
            result(false)
        }
    }
    
    /// Upload a file to iCloud Drive NextChord folder
    private func uploadFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let localPath = args["localPath"] as? String,
              let relativePath = args["relativePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        guard let ubiquityContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            result(false)
            return
        }
        
        let documentsPath = ubiquityContainer.appendingPathComponent("Documents")
        let nextChordPath = documentsPath.appendingPathComponent("NextChord")
        let destinationURL = nextChordPath.appendingPathComponent(relativePath)
        
        let sourceURL = URL(fileURLWithPath: localPath)
        
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy file to iCloud Drive
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            
            // Start uploading the file
            try FileManager.default.startDownloadingUbiquitousItem(at: destinationURL)
            
            result(true)
        } catch {
            print("Error uploading file to iCloud Drive: \(error)")
            result(false)
        }
    }
    
    /// Download a file from iCloud Drive NextChord folder
    private func downloadFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let relativePath = args["relativePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        guard let ubiquityContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            result(nil)
            return
        }
        
        let documentsPath = ubiquityContainer.appendingPathComponent("Documents")
        let nextChordPath = documentsPath.appendingPathComponent("NextChord")
        let sourceURL = nextChordPath.appendingPathComponent(relativePath)
        
        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("icloud_download_\(UUID().uuidString)")
        
        do {
            // Ensure the file is downloaded from iCloud. We avoid polling
            // deprecated / unavailable URLResourceValue keys here and instead
            // optimistically proceed after requesting the download.
            try FileManager.default.startDownloadingUbiquitousItem(at: sourceURL)
            
            // Copy to temporary location
            try FileManager.default.copyItem(at: sourceURL, to: tempFile)
            result(tempFile.path)
        } catch {
            print("Error downloading file from iCloud Drive: \(error)")
            result(nil)
        }
    }
    
    /// Get file metadata from iCloud Drive
    private func getFileMetadata(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let relativePath = args["relativePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        guard let ubiquityContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            result(nil)
            return
        }
        
        let documentsPath = ubiquityContainer.appendingPathComponent("Documents")
        let nextChordPath = documentsPath.appendingPathComponent("NextChord")
        let fileURL = nextChordPath.appendingPathComponent(relativePath)
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let modificationDate = attributes[.modificationDate] as? Date ?? Date()
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            // Generate a simple hash for MD5 checksum placeholder
            let md5Checksum = "\(fileSize)_\(modificationDate.timeIntervalSince1970)"
            
            let metadata: [String: Any] = [
                "fileId": relativePath, // Use relative path as file ID
                "modifiedTime": ISO8601DateFormatter().string(from: modificationDate),
                "md5Checksum": md5Checksum,
                "headRevisionId": "\(modificationDate.timeIntervalSince1970)" // Use timestamp as revision ID
            ]
            
            result(metadata)
        } catch {
            print("Error getting file metadata from iCloud Drive: \(error)")
            result(nil)
        }
    }
    
    /// Check if file exists in iCloud Drive
    private func fileExists(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let relativePath = args["relativePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        guard let ubiquityContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            result(false)
            return
        }
        
        let documentsPath = ubiquityContainer.appendingPathComponent("Documents")
        let nextChordPath = documentsPath.appendingPathComponent("NextChord")
        let fileURL = nextChordPath.appendingPathComponent(relativePath)
        
        let exists = FileManager.default.fileExists(atPath: fileURL.path)
        result(exists)
    }
}
