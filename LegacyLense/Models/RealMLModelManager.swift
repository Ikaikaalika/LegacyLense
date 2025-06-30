//
//  RealMLModelManager.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import Foundation
import CoreML
import Vision
import UIKit
import Combine

@MainActor
class RealMLModelManager: ObservableObject {
    @Published var availableModels: [MLModelInfo] = []
    @Published var downloadProgress: [String: Double] = [:]
    @Published var downloadStates: [String: DownloadState] = [:]
    @Published var isInitialized = false
    
    private var loadedModels: [String: MLModel] = [:]
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    
    enum DownloadState {
        case notDownloaded
        case downloading
        case downloaded
        case failed(Error)
        case installing
        case ready
    }
    
    struct MLModelInfo {
        let id: String
        let name: String
        let description: String
        let downloadURL: URL
        let fileSize: Int64 // in bytes
        let modelType: ModelType
        let requiredRAM: Int // in MB
        let processingTime: String // estimated time
        
        enum ModelType {
            case superResolution
            case colorization
            case faceRestoration
            case noiseReduction
            case enhancement
        }
    }
    
    init() {
        setupAvailableModels()
        initializeStates()
    }
    
    private func setupAvailableModels() {
        availableModels = [
            // Super Resolution Models
            MLModelInfo(
                id: "esrgan_4x",
                name: "ESRGAN 4x Super Resolution",
                description: "Upscales images by 4x with enhanced details",
                downloadURL: URL(string: "https://github.com/apple/coremltools/raw/main/examples/super_resolution/ESRGAN.mlmodel")!,
                fileSize: 67_000_000, // ~67MB
                modelType: .superResolution,
                requiredRAM: 512,
                processingTime: "3-8 seconds"
            ),
            
            MLModelInfo(
                id: "srcnn",
                name: "SRCNN Super Resolution",
                description: "Lightweight super resolution for faster processing",
                downloadURL: URL(string: "https://github.com/apple/coremltools/raw/main/examples/super_resolution/SRCNN.mlmodel")!,
                fileSize: 55_000_000, // ~55MB
                modelType: .superResolution,
                requiredRAM: 256,
                processingTime: "1-3 seconds"
            ),
            
            // Enhancement Models
            MLModelInfo(
                id: "dped_iphone",
                name: "DPED iPhone Enhancement",
                description: "Enhances photos to DSLR quality",
                downloadURL: URL(string: "https://github.com/apple/coremltools/raw/main/examples/image_enhancement/DPED.mlmodel")!,
                fileSize: 23_000_000, // ~23MB
                modelType: .enhancement,
                requiredRAM: 256,
                processingTime: "2-4 seconds"
            ),
            
            // Noise Reduction
            MLModelInfo(
                id: "dncnn",
                name: "DnCNN Noise Reduction",
                description: "Advanced noise reduction and deblurring",
                downloadURL: URL(string: "https://github.com/cszn/DnCNN/releases/download/v1.0/DnCNN.mlmodel")!,
                fileSize: 13_000_000, // ~13MB
                modelType: .noiseReduction,
                requiredRAM: 128,
                processingTime: "1-2 seconds"
            )
        ]
    }
    
    private func initializeStates() {
        for model in availableModels {
            downloadStates[model.id] = .notDownloaded
            downloadProgress[model.id] = 0.0
            
            // Check if model already exists
            if modelExists(model.id) {
                downloadStates[model.id] = .ready
                downloadProgress[model.id] = 1.0
            }
        }
        isInitialized = true
    }
    
    // MARK: - Model Management
    
    func downloadModel(_ modelInfo: MLModelInfo) async throws {
        guard downloadStates[modelInfo.id] != .downloading else {
            throw MLModelError.alreadyDownloading
        }
        
        downloadStates[modelInfo.id] = .downloading
        downloadProgress[modelInfo.id] = 0.0
        
        do {
            let localURL = try await downloadModelFile(modelInfo)
            downloadStates[modelInfo.id] = .installing
            
            // Verify the model can be loaded
            let model = try MLModel(contentsOf: localURL)
            loadedModels[modelInfo.id] = model
            
            downloadStates[modelInfo.id] = .ready
            downloadProgress[modelInfo.id] = 1.0
            
        } catch {
            downloadStates[modelInfo.id] = .failed(error)
            downloadProgress[modelInfo.id] = 0.0
            throw error
        }
    }
    
    func loadModel(_ modelId: String) async throws -> MLModel? {
        if let cachedModel = loadedModels[modelId] {
            return cachedModel
        }
        
        guard modelExists(modelId) else {
            return nil
        }
        
        let modelURL = getModelURL(for: modelId)
        let model = try MLModel(contentsOf: modelURL)
        loadedModels[modelId] = model
        
        return model
    }
    
    func processImage(_ image: UIImage, withModel modelId: String) async throws -> UIImage {
        guard let model = try await loadModel(modelId) else {
            throw MLModelError.modelNotFound
        }
        
        guard let modelInfo = availableModels.first(where: { $0.id == modelId }) else {
            throw MLModelError.modelNotFound
        }
        
        switch modelInfo.modelType {
        case .superResolution:
            return try await processSuperResolution(image, model: model)
        case .enhancement:
            return try await processEnhancement(image, model: model)
        case .noiseReduction:
            return try await processNoiseReduction(image, model: model)
        case .colorization:
            return try await processColorization(image, model: model)
        case .faceRestoration:
            return try await processFaceRestoration(image, model: model)
        }
    }
    
    // MARK: - Processing Methods
    
    private func processSuperResolution(_ image: UIImage, model: MLModel) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: MLModelError.invalidImage)
                return
            }
            
            do {
                let vnModel = try VNCoreMLModel(for: model)
                let request = VNCoreMLRequest(model: vnModel) { request, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let results = request.results as? [VNPixelBufferObservation],
                          let pixelBuffer = results.first?.pixelBuffer else {
                        continuation.resume(throwing: MLModelError.processingFailed)
                        return
                    }
                    
                    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                    let context = CIContext()
                    
                    guard let outputImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                        continuation.resume(throwing: MLModelError.processingFailed)
                        return
                    }
                    
                    continuation.resume(returning: UIImage(cgImage: outputImage))
                }
                
                request.imageCropAndScaleOption = .scaleFill
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])
                
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func processEnhancement(_ image: UIImage, model: MLModel) async throws -> UIImage {
        return try await processSuperResolution(image, model: model) // Similar processing
    }
    
    private func processNoiseReduction(_ image: UIImage, model: MLModel) async throws -> UIImage {
        return try await processSuperResolution(image, model: model) // Similar processing
    }
    
    private func processColorization(_ image: UIImage, model: MLModel) async throws -> UIImage {
        // Colorization would require different input/output handling
        return try await processSuperResolution(image, model: model)
    }
    
    private func processFaceRestoration(_ image: UIImage, model: MLModel) async throws -> UIImage {
        // Face restoration would require face detection first
        return try await processSuperResolution(image, model: model)
    }
    
    // MARK: - File Management
    
    private func downloadModelFile(_ modelInfo: MLModelInfo) async throws -> URL {
        let destinationURL = getModelURL(for: modelInfo.id)
        
        // Create models directory if it doesn't exist
        let modelsDirectory = getModelsDirectory()
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: modelInfo.downloadURL) { [weak self] tempURL, response, error in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let tempURL = tempURL else {
                        continuation.resume(throwing: MLModelError.downloadFailed)
                        return
                    }
                    
                    do {
                        // Move file to final destination
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try FileManager.default.removeItem(at: destinationURL)
                        }
                        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                        continuation.resume(returning: destinationURL)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // Track download progress
            let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                Task { @MainActor in
                    self?.downloadProgress[modelInfo.id] = progress.fractionCompleted
                }
            }
            
            task.resume()
            downloadTasks[modelInfo.id] = task
        }
    }
    
    private func modelExists(_ modelId: String) -> Bool {
        let modelURL = getModelURL(for: modelId)
        return FileManager.default.fileExists(atPath: modelURL.path)
    }
    
    private func getModelURL(for modelId: String) -> URL {
        return getModelsDirectory().appendingPathComponent("\(modelId).mlmodel")
    }
    
    private func getModelsDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("MLModels")
    }
    
    // MARK: - Utility Methods
    
    func getModelInfo(for modelId: String) -> MLModelInfo? {
        return availableModels.first { $0.id == modelId }
    }
    
    func getReadyModels() -> [MLModelInfo] {
        return availableModels.filter { downloadStates[$0.id] == .ready }
    }
    
    func getDownloadableModels() -> [MLModelInfo] {
        return availableModels.filter { downloadStates[$0.id] == .notDownloaded }
    }
    
    func deleteModel(_ modelId: String) throws {
        let modelURL = getModelURL(for: modelId)
        if FileManager.default.fileExists(atPath: modelURL.path) {
            try FileManager.default.removeItem(at: modelURL)
        }
        
        loadedModels.removeValue(forKey: modelId)
        downloadStates[modelId] = .notDownloaded
        downloadProgress[modelId] = 0.0
    }
    
    func getTotalDownloadSize() -> Int64 {
        return availableModels.reduce(0) { total, model in
            if downloadStates[model.id] == .notDownloaded {
                return total + model.fileSize
            }
            return total
        }
    }
    
    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Error Types

enum MLModelError: LocalizedError {
    case modelNotFound
    case alreadyDownloading
    case downloadFailed
    case invalidImage
    case processingFailed
    case insufficientMemory
    case modelCorrupted
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "ML model not found"
        case .alreadyDownloading:
            return "Model is already being downloaded"
        case .downloadFailed:
            return "Failed to download model"
        case .invalidImage:
            return "Invalid image format for processing"
        case .processingFailed:
            return "Failed to process image with ML model"
        case .insufficientMemory:
            return "Insufficient memory to load model"
        case .modelCorrupted:
            return "Model file is corrupted"
        }
    }
}