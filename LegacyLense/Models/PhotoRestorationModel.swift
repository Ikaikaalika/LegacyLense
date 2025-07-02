//
//  PhotoRestorationModel.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import Foundation
@preconcurrency import CoreML
import Vision
import UIKit
import Combine

@MainActor
class PhotoRestorationModel: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var currentStage: ProcessingStage = .idle
    @Published var processingError: Error?
    
    private var models: [RestorationModelType: MLModel] = [:]
    private var modelDownloader = ModelDownloader()
    
    enum ProcessingStage: String, CaseIterable {
        case idle = "Ready"
        case preprocessing = "Preparing Image"
        case scratchRemoval = "Removing Scratches"
        case colorization = "Adding Color"
        case faceRestoration = "Restoring Faces"
        case superResolution = "Enhancing Quality"
        case postprocessing = "Finalizing"
        case completed = "Complete"
    }
    
    enum RestorationModelType: String, CaseIterable {
        case scratchRemoval = "ScratchRemoval"
        case colorization = "DeOldify"
        case faceRestoration = "GFPGAN"
        case superResolution = "RealESRGAN"
        
        var displayName: String {
            switch self {
            case .scratchRemoval: return "Scratch Removal"
            case .colorization: return "Colorization"
            case .faceRestoration: return "Face Restoration"
            case .superResolution: return "Super Resolution"
            }
        }
        
        var modelURL: URL {
            switch self {
            case .scratchRemoval:
                return URL(string: "https://huggingface.co/apple/coreml-stable-diffusion/resolve/main/coreml-stable-diffusion-v1-5_split_einsum/VAEDecoder.mlpackage.zip")!
            case .colorization:
                return URL(string: "https://huggingface.co/coreml/DeOldify/resolve/main/deoldify.mlmodel")!
            case .faceRestoration:
                return URL(string: "https://huggingface.co/coreml/GFPGAN/resolve/main/gfpgan.mlmodel")!
            case .superResolution:
                return URL(string: "https://huggingface.co/coreml/RealESRGAN/resolve/main/real_esrgan_4x.mlmodel")!
            }
        }
    }
    
    private let realProcessor = RealPhotoProcessor()
    private let mlModelManager = RealMLModelManager()
    
    init() {
        Task {
            await loadAvailableModels()
        }
    }
    
    func loadAvailableModels() async {
        for modelType in RestorationModelType.allCases {
            do {
                if let model = try await modelDownloader.loadModel(for: modelType) {
                    models[modelType] = model
                }
            } catch {
                print("Failed to load model \(modelType.displayName): \(error)")
            }
        }
    }
    
    func areAllModelsAvailable() -> Bool {
        return RestorationModelType.allCases.allSatisfy { models[$0] != nil }
    }
    
    func getAvailableModels() -> [RestorationModelType] {
        return RestorationModelType.allCases.filter { models[$0] != nil }
    }
    
    func getMissingModels() -> [RestorationModelType] {
        return RestorationModelType.allCases.filter { models[$0] == nil }
    }
    
    func restorePhoto(_ image: UIImage, enabledStages: Set<RestorationModelType> = Set(RestorationModelType.allCases)) async throws -> UIImage {
        guard !isProcessing else {
            throw PhotoRestorationError.alreadyProcessing
        }
        
        isProcessing = true
        progress = 0.0
        processingError = nil
        currentStage = .preprocessing
        
        defer {
            isProcessing = false
            currentStage = .completed
        }
        
        do {
            // Check if we have real ML models available
            let readyModels = mlModelManager.getReadyModels()
            
            if readyModels.isEmpty {
                // Use real photo processor with CoreImage filters
                currentStage = .preprocessing
                
                // Monitor progress from real processor
                let progressTask = Task {
                    while isProcessing {
                        await MainActor.run {
                            self.progress = realProcessor.progress
                            if let stage = ProcessingStage(rawValue: realProcessor.currentStage) {
                                self.currentStage = stage
                            }
                        }
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    }
                }
                
                let result = try await realProcessor.processPhoto(image)
                progressTask.cancel()
                return result
                
            } else {
                // Use real ML models for processing
                return try await processWithRealMLModels(image, availableModels: readyModels)
            }
            
        } catch {
            processingError = error
            throw error
        }
    }
    
    private func processWithMLModels(_ image: UIImage, enabledStages: Set<RestorationModelType>) async throws -> UIImage {
        var processedImage = image
        let totalStages = enabledStages.count + 2 // +2 for pre/post processing
        var completedStages = 0
        
        // Preprocessing
        currentStage = .preprocessing
        processedImage = try await preprocessImage(processedImage)
        completedStages += 1
        progress = Double(completedStages) / Double(totalStages)
        
        // Process through each enabled stage
        let orderedStages: [RestorationModelType] = [
            .scratchRemoval,
            .colorization,
            .faceRestoration,
            .superResolution
        ]
        
        for stage in orderedStages {
            if enabledStages.contains(stage) {
                guard let model = models[stage] else {
                    throw PhotoRestorationError.modelNotAvailable(stage.displayName)
                }
                
                currentStage = ProcessingStage(rawValue: stage.displayName) ?? .idle
                processedImage = try await processImageWithModel(processedImage, model: model, type: stage)
                completedStages += 1
                progress = Double(completedStages) / Double(totalStages)
            }
        }
        
        // Postprocessing
        currentStage = .postprocessing
        processedImage = try await postprocessImage(processedImage)
        completedStages += 1
        progress = 1.0
        
        return processedImage
    }
    
    private func processWithRealMLModels(_ image: UIImage, availableModels: [RealMLModelManager.MLModelInfo]) async throws -> UIImage {
        var processedImage = image
        currentStage = .preprocessing
        progress = 0.1
        
        // Process with available ML models in priority order
        let processingOrder: [RealMLModelManager.MLModelInfo.ModelType] = [
            .noiseReduction,
            .enhancement,
            .superResolution,
            .faceRestoration,
            .colorization
        ]
        
        let totalSteps = availableModels.count + 1 // +1 for preprocessing
        var currentStep = 1
        
        for modelType in processingOrder {
            if let model = availableModels.first(where: { $0.modelType == modelType }) {
                // Update progress and stage
                progress = Double(currentStep) / Double(totalSteps)
                
                switch modelType {
                case .noiseReduction:
                    currentStage = .preprocessing // Noise reduction is part of preprocessing
                case .enhancement:
                    currentStage = .superResolution // General enhancement
                case .superResolution:
                    currentStage = .superResolution
                case .faceRestoration:
                    currentStage = .faceRestoration
                case .colorization:
                    currentStage = .colorization
                }
                
                do {
                    let enhancedImage = try await mlModelManager.processImage(processedImage, withModel: model.id)
                    processedImage = enhancedImage
                } catch {
                    // If ML processing fails, continue with next model or fallback
                    print("ML model processing failed for \(model.name): \(error)")
                    continue
                }
                
                currentStep += 1
            }
        }
        
        // Final postprocessing
        currentStage = .postprocessing
        progress = 0.95
        
        // If no ML models were successfully applied, fallback to CoreImage processing
        if currentStep == 1 {
            return try await realProcessor.processPhoto(image)
        }
        
        progress = 1.0
        return processedImage
    }
    
    private func preprocessImage(_ image: UIImage) async throws -> UIImage {
        // Resize if too large, normalize colors, convert to appropriate format
        let maxDimension: CGFloat = 2048
        let size = image.size
        
        if max(size.width, size.height) > maxDimension {
            let scale = maxDimension / max(size.width, size.height)
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
                    image.draw(in: CGRect(origin: .zero, size: newSize))
                    let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    
                    if let resizedImage = resizedImage {
                        continuation.resume(returning: resizedImage)
                    } else {
                        continuation.resume(throwing: PhotoRestorationError.preprocessingFailed)
                    }
                }
            }
        }
        
        return image
    }
    
    private func processImageWithModel(_ image: UIImage, model: MLModel, type: RestorationModelType) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard let cgImage = image.cgImage else {
                        continuation.resume(throwing: PhotoRestorationError.invalidImage)
                        return
                    }
                    
                    // Create Vision request
                    let request = VNCoreMLRequest(model: try VNCoreMLModel(for: model)) { request, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }
                        
                        // Process the results based on model type
                        if let results = request.results as? [VNPixelBufferObservation],
                           let pixelBuffer = results.first?.pixelBuffer {
                            
                            if let processedImage = self.pixelBufferToUIImage(pixelBuffer) {
                                continuation.resume(returning: processedImage)
                            } else {
                                continuation.resume(throwing: PhotoRestorationError.processingFailed)
                            }
                        } else {
                            continuation.resume(throwing: PhotoRestorationError.processingFailed)
                        }
                    }
                    
                    // Configure request based on model type
                    request.imageCropAndScaleOption = .scaleFill
                    
                    // Execute the request
                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    try handler.perform([request])
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func postprocessImage(_ image: UIImage) async throws -> UIImage {
        // Apply final adjustments, color correction, etc.
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // For now, just return the image as-is
                // In a real implementation, you might apply final color correction,
                // sharpening, or other post-processing effects
                continuation.resume(returning: image)
            }
        }
    }
    
    nonisolated private func pixelBufferToUIImage(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    func cancelProcessing() {
        isProcessing = false
        currentStage = .idle
        progress = 0.0
    }
    
    func getProcessingProgress() -> (stage: String, progress: Double) {
        return (currentStage.rawValue, progress)
    }
}

enum PhotoRestorationError: LocalizedError {
    case alreadyProcessing
    case modelNotAvailable(String)
    case invalidImage
    case preprocessingFailed
    case processingFailed
    case networkError(String)
    case insufficientMemory
    
    var errorDescription: String? {
        switch self {
        case .alreadyProcessing:
            return "Photo restoration is already in progress"
        case .modelNotAvailable(let modelName):
            return "Model '\(modelName)' is not available"
        case .invalidImage:
            return "Invalid image format"
        case .preprocessingFailed:
            return "Failed to prepare image for processing"
        case .processingFailed:
            return "Failed to process image"
        case .networkError(let message):
            return "Network error: \(message)"
        case .insufficientMemory:
            return "Insufficient memory to process this image"
        }
    }
}