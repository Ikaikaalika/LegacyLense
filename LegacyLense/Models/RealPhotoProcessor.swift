//
//  RealPhotoProcessor.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import Foundation
import UIKit
import CoreImage
import CoreML
import Vision

@MainActor
class RealPhotoProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var currentStage = "Ready"
    
    private let context = CIContext()
    
    enum ProcessingStage: String, CaseIterable {
        case enhancement = "Enhancing Quality"
        case colorCorrection = "Correcting Colors"
        case noiseReduction = "Reducing Noise"
        case sharpening = "Sharpening Details"
        case restoration = "Final Restoration"
        
        var progress: Double {
            switch self {
            case .enhancement: return 0.2
            case .colorCorrection: return 0.4
            case .noiseReduction: return 0.6
            case .sharpening: return 0.8
            case .restoration: return 1.0
            }
        }
    }
    
    func processPhoto(_ image: UIImage) async throws -> UIImage {
        guard !isProcessing else {
            throw ProcessingError.alreadyProcessing
        }
        
        isProcessing = true
        progress = 0.0
        
        defer {
            isProcessing = false
            currentStage = "Completed"
        }
        
        guard let inputCIImage = CIImage(image: image) else {
            throw ProcessingError.invalidImage
        }
        
        var processedImage = inputCIImage
        
        // Process through each stage
        for stage in ProcessingStage.allCases {
            currentStage = stage.rawValue
            
            switch stage {
            case .enhancement:
                processedImage = try await enhanceImage(processedImage)
            case .colorCorrection:
                processedImage = try await correctColors(processedImage)
            case .noiseReduction:
                processedImage = try await reduceNoise(processedImage)
            case .sharpening:
                processedImage = try await sharpenImage(processedImage)
            case .restoration:
                processedImage = try await finalRestoration(processedImage)
            }
            
            progress = stage.progress
            
            // Add small delay to show progress
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        guard let outputCGImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            throw ProcessingError.processingFailed
        }
        
        return UIImage(cgImage: outputCGImage)
    }
    
    // MARK: - Processing Stages
    
    private func enhanceImage(_ image: CIImage) async throws -> CIImage {
        // Auto-enhance filter
        guard let enhanceFilter = CIFilter(name: "CIColorControls") else {
            throw ProcessingError.filterNotAvailable
        }
        
        enhanceFilter.setValue(image, forKey: kCIInputImageKey)
        enhanceFilter.setValue(1.1, forKey: kCIInputContrastKey)
        enhanceFilter.setValue(1.05, forKey: kCIInputSaturationKey)
        enhanceFilter.setValue(0.05, forKey: kCIInputBrightnessKey)
        
        guard let output = enhanceFilter.outputImage else {
            throw ProcessingError.processingFailed
        }
        
        return output
    }
    
    private func correctColors(_ image: CIImage) async throws -> CIImage {
        // White balance and exposure correction
        guard let exposureFilter = CIFilter(name: "CIExposureAdjust") else {
            throw ProcessingError.filterNotAvailable
        }
        
        exposureFilter.setValue(image, forKey: kCIInputImageKey)
        exposureFilter.setValue(0.2, forKey: kCIInputEVKey)
        
        guard let exposureOutput = exposureFilter.outputImage else {
            throw ProcessingError.processingFailed
        }
        
        // Vibrance adjustment
        guard let vibranceFilter = CIFilter(name: "CIVibrance") else {
            return exposureOutput
        }
        
        vibranceFilter.setValue(exposureOutput, forKey: kCIInputImageKey)
        vibranceFilter.setValue(0.3, forKey: kCIInputAmountKey)
        
        return vibranceFilter.outputImage ?? exposureOutput
    }
    
    private func reduceNoise(_ image: CIImage) async throws -> CIImage {
        // Noise reduction filter
        guard let noiseFilter = CIFilter(name: "CINoiseReduction") else {
            return image // Skip if filter not available
        }
        
        noiseFilter.setValue(image, forKey: kCIInputImageKey)
        noiseFilter.setValue(0.02, forKey: "inputNoiseLevel")
        noiseFilter.setValue(0.4, forKey: "inputSharpness")
        
        return noiseFilter.outputImage ?? image
    }
    
    private func sharpenImage(_ image: CIImage) async throws -> CIImage {
        // Unsharp mask for detail enhancement
        guard let sharpenFilter = CIFilter(name: "CIUnsharpMask") else {
            throw ProcessingError.filterNotAvailable
        }
        
        sharpenFilter.setValue(image, forKey: kCIInputImageKey)
        sharpenFilter.setValue(2.5, forKey: kCIInputRadiusKey)
        sharpenFilter.setValue(0.5, forKey: kCIInputIntensityKey)
        
        guard let output = sharpenFilter.outputImage else {
            throw ProcessingError.processingFailed
        }
        
        return output
    }
    
    private func finalRestoration(_ image: CIImage) async throws -> CIImage {
        // Final pass with tone curve adjustment
        guard let toneCurveFilter = CIFilter(name: "CIToneCurve") else {
            return image
        }
        
        // Create subtle S-curve for better contrast
        let point0 = CIVector(x: 0, y: 0)
        let point1 = CIVector(x: 0.25, y: 0.2)
        let point2 = CIVector(x: 0.5, y: 0.5)
        let point3 = CIVector(x: 0.75, y: 0.8)
        let point4 = CIVector(x: 1, y: 1)
        
        toneCurveFilter.setValue(image, forKey: kCIInputImageKey)
        toneCurveFilter.setValue(point0, forKey: "inputPoint0")
        toneCurveFilter.setValue(point1, forKey: "inputPoint1")
        toneCurveFilter.setValue(point2, forKey: "inputPoint2")
        toneCurveFilter.setValue(point3, forKey: "inputPoint3")
        toneCurveFilter.setValue(point4, forKey: "inputPoint4")
        
        return toneCurveFilter.outputImage ?? image
    }
    
    // MARK: - Advanced ML Processing (for when you add real models)
    
    func processWithMLModel(_ image: UIImage, modelName: String) async throws -> UIImage {
        // This is where you'll integrate actual CoreML models
        // For now, falls back to CoreImage processing
        
        currentStage = "Loading AI Model"
        progress = 0.1
        
        // Simulate model loading
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Check if we have a real ML model
        if let modelURL = getModelURL(for: modelName) {
            return try await processWithCoreML(image, modelURL: modelURL)
        } else {
            // Fallback to CoreImage processing
            return try await processPhoto(image)
        }
    }
    
    private func processWithCoreML(_ image: UIImage, modelURL: URL) async throws -> UIImage {
        currentStage = "Processing with AI"
        progress = 0.5
        
        // Check if this is a placeholder file (Core Image model)
        if let data = try? Data(contentsOf: modelURL),
           let content = String(data: data, encoding: .utf8),
           content.contains("LegacyLense Core Image Model Placeholder") {
            // This is a placeholder - use Core Image processing instead
            return try await processPhoto(image)
        }
        
        // Load the CoreML model
        let model = try MLModel(contentsOf: modelURL)
        let vnModel = try VNCoreMLModel(for: model)
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: ProcessingError.invalidImage)
                return
            }
            
            let request = VNCoreMLRequest(model: vnModel) { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Process the ML model results
                if let results = request.results as? [VNPixelBufferObservation],
                   let pixelBuffer = results.first?.pixelBuffer {
                    
                    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                    if let cgImage = self.context.createCGImage(ciImage, from: ciImage.extent) {
                        let processedImage = UIImage(cgImage: cgImage)
                        continuation.resume(returning: processedImage)
                    } else {
                        continuation.resume(throwing: ProcessingError.processingFailed)
                    }
                } else {
                    continuation.resume(throwing: ProcessingError.processingFailed)
                }
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func getModelURL(for modelName: String) -> URL? {
        // Check for downloaded models in Documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelPath = documentsPath.appendingPathComponent("Models/\(modelName).mlmodel")
        
        if FileManager.default.fileExists(atPath: modelPath.path) {
            return modelPath
        }
        
        // Check for bundled models
        return Bundle.main.url(forResource: modelName, withExtension: "mlmodel")
    }
    
    func cancelProcessing() {
        isProcessing = false
        progress = 0.0
        currentStage = "Cancelled"
    }
}

// MARK: - Processing Errors

enum ProcessingError: LocalizedError {
    case alreadyProcessing
    case invalidImage
    case processingFailed
    case filterNotAvailable
    case modelNotFound
    
    var errorDescription: String? {
        switch self {
        case .alreadyProcessing:
            return "Processing is already in progress"
        case .invalidImage:
            return "Invalid image format"
        case .processingFailed:
            return "Photo processing failed"
        case .filterNotAvailable:
            return "Required filter not available"
        case .modelNotFound:
            return "AI model not found"
        }
    }
}