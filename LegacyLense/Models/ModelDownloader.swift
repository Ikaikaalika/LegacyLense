//
//  ModelDownloader.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import Foundation
import CoreML
import Combine

@MainActor
class ModelDownloader: NSObject, ObservableObject {
    @Published var downloadProgress: [PhotoRestorationModel.RestorationModelType: Double] = [:]
    @Published var downloadStates: [PhotoRestorationModel.RestorationModelType: DownloadState] = [:]
    @Published var totalDownloadProgress: Double = 0.0
    
    private var downloadTasks: [PhotoRestorationModel.RestorationModelType: URLSessionDownloadTask] = [:]
    private var urlSession: URLSession
    
    enum DownloadState: Equatable {
        case notStarted
        case downloading
        case completed
        case failed(Error)
        case cancelled
        
        static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
            switch (lhs, rhs) {
            case (.notStarted, .notStarted),
                 (.downloading, .downloading),
                 (.completed, .completed),
                 (.cancelled, .cancelled):
                return true
            case (.failed, .failed):
                return true
            default:
                return false
            }
        }
    }
    
    override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 3600.0 // 1 hour for large model downloads
        self.urlSession = URLSession(configuration: config)
        
        super.init()
        
        // Initialize download states
        for modelType in PhotoRestorationModel.RestorationModelType.allCases {
            downloadStates[modelType] = .notStarted
            downloadProgress[modelType] = 0.0
        }
    }
    
    func loadModel(for modelType: PhotoRestorationModel.RestorationModelType) async throws -> MLModel? {
        let modelURL = getLocalModelURL(for: modelType)
        
        // Check if model exists locally
        if FileManager.default.fileExists(atPath: modelURL.path) {
            // Check if this is a placeholder file (Core Image model)
            if let data = try? Data(contentsOf: modelURL),
               let content = String(data: data, encoding: .utf8),
               content.contains("LegacyLense Core Image Model Placeholder") {
                // This is a placeholder - mark as completed but return nil for Core Image processing
                downloadStates[modelType] = .completed
                return nil
            }
            
            do {
                let model = try MLModel(contentsOf: modelURL)
                downloadStates[modelType] = .completed
                return model
            } catch {
                // Model file is corrupted, delete and re-download
                try? FileManager.default.removeItem(at: modelURL)
            }
        }
        
        return nil
    }
    
    func downloadModel(for modelType: PhotoRestorationModel.RestorationModelType) async throws {
        guard downloadStates[modelType] != .downloading else {
            throw ModelDownloadError.alreadyDownloading
        }
        
        downloadStates[modelType] = .downloading
        downloadProgress[modelType] = 0.0
        
        do {
            let localURL = try await downloadModelFile(for: modelType)
            
            // Verify the downloaded model (skip verification for placeholder files)
            if let data = try? Data(contentsOf: localURL),
               let content = String(data: data, encoding: .utf8),
               content.contains("LegacyLense Core Image Model Placeholder") {
                // This is a placeholder file - no need to verify as MLModel
            } else {
                // Try to verify as actual MLModel
                let _ = try MLModel(contentsOf: localURL)
            }
            
            downloadStates[modelType] = .completed
            downloadProgress[modelType] = 1.0
            updateTotalProgress()
            
        } catch {
            downloadStates[modelType] = .failed(error)
            downloadProgress[modelType] = 0.0
            updateTotalProgress()
            throw error
        }
    }
    
    func downloadAllModels() async throws {
        let models = PhotoRestorationModel.RestorationModelType.allCases
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for modelType in models {
                if downloadStates[modelType] != .completed {
                    group.addTask {
                        try await self.downloadModel(for: modelType)
                    }
                }
            }
            
            // Wait for all downloads to complete
            for try await _ in group {
                // All downloads completed
            }
        }
    }
    
    private func downloadModelFile(for modelType: PhotoRestorationModel.RestorationModelType) async throws -> URL {
        let remoteURL = modelType.modelURL
        let localURL = getLocalModelURL(for: modelType)
        
        // Create models directory if it doesn't exist
        let modelsDirectory = localURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true, attributes: nil)
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.downloadTask(with: remoteURL) { tempURL, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let tempURL = tempURL else {
                        continuation.resume(throwing: ModelDownloadError.downloadFailed)
                        return
                    }
                    
                    do {
                        // Move downloaded file to final location
                        if FileManager.default.fileExists(atPath: localURL.path) {
                            try FileManager.default.removeItem(at: localURL)
                        }
                        try FileManager.default.moveItem(at: tempURL, to: localURL)
                        continuation.resume(returning: localURL)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // Store the task for potential cancellation
            downloadTasks[modelType] = task
            task.resume()
        }
    }
    
    private func getLocalModelURL(for modelType: PhotoRestorationModel.RestorationModelType) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsPath = documentsPath.appendingPathComponent("Models")
        return modelsPath.appendingPathComponent("\(modelType.rawValue).mlmodel")
    }
    
    func cancelDownload(for modelType: PhotoRestorationModel.RestorationModelType) {
        downloadTasks[modelType]?.cancel()
        downloadTasks[modelType] = nil
        downloadStates[modelType] = .cancelled
        downloadProgress[modelType] = 0.0
        updateTotalProgress()
    }
    
    func cancelAllDownloads() {
        for modelType in PhotoRestorationModel.RestorationModelType.allCases {
            cancelDownload(for: modelType)
        }
    }
    
    func deleteModel(for modelType: PhotoRestorationModel.RestorationModelType) throws {
        let localURL = getLocalModelURL(for: modelType)
        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }
        downloadStates[modelType] = .notStarted
        downloadProgress[modelType] = 0.0
        updateTotalProgress()
    }
    
    func deleteAllModels() throws {
        for modelType in PhotoRestorationModel.RestorationModelType.allCases {
            try deleteModel(for: modelType)
        }
    }
    
    func getModelSize(for modelType: PhotoRestorationModel.RestorationModelType) -> Int64? {
        let localURL = getLocalModelURL(for: modelType)
        guard FileManager.default.fileExists(atPath: localURL.path) else { return nil }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    func getTotalModelsSize() -> Int64 {
        var totalSize: Int64 = 0
        for modelType in PhotoRestorationModel.RestorationModelType.allCases {
            totalSize += getModelSize(for: modelType) ?? 0
        }
        return totalSize
    }
    
    func getAvailableModels() -> [PhotoRestorationModel.RestorationModelType] {
        return PhotoRestorationModel.RestorationModelType.allCases.filter { modelType in
            downloadStates[modelType] == .completed
        }
    }
    
    func getMissingModels() -> [PhotoRestorationModel.RestorationModelType] {
        return PhotoRestorationModel.RestorationModelType.allCases.filter { modelType in
            downloadStates[modelType] != .completed
        }
    }
    
    private func updateTotalProgress() {
        let totalModels = PhotoRestorationModel.RestorationModelType.allCases.count
        let totalProgress = downloadProgress.values.reduce(0, +)
        self.totalDownloadProgress = totalProgress / Double(totalModels)
    }
    
    func getDownloadInfo() -> (completed: Int, total: Int, totalSizeMB: Double) {
        let completed = getAvailableModels().count
        let total = PhotoRestorationModel.RestorationModelType.allCases.count
        let totalSizeBytes = getTotalModelsSize()
        let totalSizeMB = Double(totalSizeBytes) / (1024 * 1024)
        
        return (completed, total, totalSizeMB)
    }
}

// MARK: - URLSessionDownloadDelegate
extension ModelDownloader: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        // Find which model this task belongs to
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        DispatchQueue.main.async {
            // Update progress for the specific model
            for (modelType, task) in self.downloadTasks {
                if task == downloadTask {
                    self.downloadProgress[modelType] = progress
                    self.updateTotalProgress()
                    break
                }
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // This is handled in the download task completion handler
    }
}

enum ModelDownloadError: LocalizedError {
    case alreadyDownloading
    case downloadFailed
    case invalidModel
    case insufficientStorage
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .alreadyDownloading:
            return "Model is already being downloaded"
        case .downloadFailed:
            return "Failed to download model"
        case .invalidModel:
            return "Downloaded model is invalid or corrupted"
        case .insufficientStorage:
            return "Insufficient storage space to download model"
        case .networkUnavailable:
            return "Network connection is unavailable"
        }
    }
}