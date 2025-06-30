//
//  PremiumPhotoEffects.swift
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
class PremiumPhotoEffects: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var currentEffect = "Ready"
    
    private let context = CIContext()
    
    enum EffectType: String, CaseIterable {
        case vintage = "Vintage"
        case dramatic = "Dramatic"
        case artistic = "Artistic"
        case professional = "Professional"
        case cinematic = "Cinematic"
        case portrait = "Portrait"
        
        var description: String {
            switch self {
            case .vintage: return "Classic film look with warm tones"
            case .dramatic: return "High contrast with deep shadows"
            case .artistic: return "Creative interpretation with enhanced colors"
            case .professional: return "Clean, balanced professional grade"
            case .cinematic: return "Movie-like color grading"
            case .portrait: return "Optimized for faces and skin tones"
            }
        }
    }
    
    func applyPremiumEffect(_ image: UIImage, effect: EffectType) async throws -> UIImage {
        guard !isProcessing else {
            throw EffectError.alreadyProcessing
        }
        
        isProcessing = true
        progress = 0.0
        
        defer {
            isProcessing = false
            currentEffect = "Completed"
        }
        
        guard let inputCIImage = CIImage(image: image) else {
            throw EffectError.invalidImage
        }
        
        var processedImage = inputCIImage
        currentEffect = "Applying \(effect.rawValue) Effect"
        
        switch effect {
        case .vintage:
            processedImage = try await applyVintageEffect(processedImage)
        case .dramatic:
            processedImage = try await applyDramaticEffect(processedImage)
        case .artistic:
            processedImage = try await applyArtisticEffect(processedImage)
        case .professional:
            processedImage = try await applyProfessionalEffect(processedImage)
        case .cinematic:
            processedImage = try await applyCinematicEffect(processedImage)
        case .portrait:
            processedImage = try await applyPortraitEffect(processedImage)
        }
        
        progress = 1.0
        
        guard let outputCGImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            throw EffectError.processingFailed
        }
        
        return UIImage(cgImage: outputCGImage)
    }
    
    // MARK: - Effect Implementations
    
    private func applyVintageEffect(_ image: CIImage) async throws -> CIImage {
        progress = 0.2
        
        // Sepia tone
        guard let sepiaFilter = CIFilter(name: "CISepiaTone") else {
            throw EffectError.filterNotAvailable
        }
        sepiaFilter.setValue(image, forKey: kCIInputImageKey)
        sepiaFilter.setValue(0.8, forKey: kCIInputIntensityKey)
        
        guard let sepiaOutput = sepiaFilter.outputImage else {
            throw EffectError.processingFailed
        }
        
        progress = 0.5
        
        // Add vintage color grading
        guard let colorMatrixFilter = CIFilter(name: "CIColorMatrix") else {
            return sepiaOutput
        }
        
        colorMatrixFilter.setValue(sepiaOutput, forKey: kCIInputImageKey)
        colorMatrixFilter.setValue(CIVector(x: 1.1, y: 0, z: 0, w: 0), forKey: "inputRVector")
        colorMatrixFilter.setValue(CIVector(x: 0, y: 0.9, z: 0, w: 0), forKey: "inputGVector")
        colorMatrixFilter.setValue(CIVector(x: 0, y: 0, z: 0.7, w: 0), forKey: "inputBVector")
        
        progress = 0.8
        
        // Add slight vignette
        let vignetteOutput = try await addVignette(colorMatrixFilter.outputImage ?? sepiaOutput)
        
        return vignetteOutput
    }
    
    private func applyDramaticEffect(_ image: CIImage) async throws -> CIImage {
        progress = 0.2
        
        // Increase contrast dramatically
        guard let contrastFilter = CIFilter(name: "CIColorControls") else {
            throw EffectError.filterNotAvailable
        }
        contrastFilter.setValue(image, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.5, forKey: kCIInputContrastKey)
        contrastFilter.setValue(0.9, forKey: kCIInputSaturationKey)
        contrastFilter.setValue(-0.1, forKey: kCIInputBrightnessKey)
        
        progress = 0.5
        
        // Apply shadow/highlight adjustment
        guard let shadowFilter = CIFilter(name: "CIShadowHighlight") else {
            return contrastFilter.outputImage ?? image
        }
        shadowFilter.setValue(contrastFilter.outputImage, forKey: kCIInputImageKey)
        shadowFilter.setValue(0.3, forKey: "inputShadowAmount")
        shadowFilter.setValue(0.8, forKey: "inputHighlightAmount")
        
        progress = 0.8
        
        return shadowFilter.outputImage ?? image
    }
    
    private func applyArtisticEffect(_ image: CIImage) async throws -> CIImage {
        progress = 0.2
        
        // Enhance vibrancy
        guard let vibranceFilter = CIFilter(name: "CIVibrance") else {
            throw EffectError.filterNotAvailable
        }
        vibranceFilter.setValue(image, forKey: kCIInputImageKey)
        vibranceFilter.setValue(0.6, forKey: kCIInputAmountKey)
        
        progress = 0.4
        
        // Add artistic color adjustments
        guard let hueFilter = CIFilter(name: "CIHueAdjust") else {
            return vibranceFilter.outputImage ?? image
        }
        hueFilter.setValue(vibranceFilter.outputImage, forKey: kCIInputImageKey)
        hueFilter.setValue(0.2, forKey: kCIInputAngleKey)
        
        progress = 0.7
        
        // Slight stylization
        guard let stylizeFilter = CIFilter(name: "CIColorPosterize") else {
            return hueFilter.outputImage ?? image
        }
        stylizeFilter.setValue(hueFilter.outputImage, forKey: kCIInputImageKey)
        stylizeFilter.setValue(12, forKey: kCIInputLevelsKey)
        
        progress = 0.9
        
        return stylizeFilter.outputImage ?? image
    }
    
    private func applyProfessionalEffect(_ image: CIImage) async throws -> CIImage {
        progress = 0.2
        
        // Professional color correction
        guard let exposureFilter = CIFilter(name: "CIExposureAdjust") else {
            throw EffectError.filterNotAvailable
        }
        exposureFilter.setValue(image, forKey: kCIInputImageKey)
        exposureFilter.setValue(0.3, forKey: kCIInputEVKey)
        
        progress = 0.4
        
        // White balance
        guard let temperatureFilter = CIFilter(name: "CITemperatureAndTint") else {
            return exposureFilter.outputImage ?? image
        }
        temperatureFilter.setValue(exposureFilter.outputImage, forKey: kCIInputImageKey)
        temperatureFilter.setValue(CIVector(x: 6500, y: 0), forKey: kCIInputNeutralKey)
        temperatureFilter.setValue(CIVector(x: 6500, y: 0), forKey: kCIInputTargetNeutralKey)
        
        progress = 0.7
        
        // Professional sharpening
        guard let sharpenFilter = CIFilter(name: "CIUnsharpMask") else {
            return temperatureFilter.outputImage ?? image
        }
        sharpenFilter.setValue(temperatureFilter.outputImage, forKey: kCIInputImageKey)
        sharpenFilter.setValue(1.5, forKey: kCIInputRadiusKey)
        sharpenFilter.setValue(0.8, forKey: kCIInputIntensityKey)
        
        progress = 0.9
        
        return sharpenFilter.outputImage ?? image
    }
    
    private func applyCinematicEffect(_ image: CIImage) async throws -> CIImage {
        progress = 0.2
        
        // Cinematic color grading
        guard let toneCurveFilter = CIFilter(name: "CIToneCurve") else {
            throw EffectError.filterNotAvailable
        }
        
        // Create cinematic S-curve
        let point0 = CIVector(x: 0, y: 0.05)
        let point1 = CIVector(x: 0.25, y: 0.15)
        let point2 = CIVector(x: 0.5, y: 0.5)
        let point3 = CIVector(x: 0.75, y: 0.85)
        let point4 = CIVector(x: 1, y: 0.95)
        
        toneCurveFilter.setValue(image, forKey: kCIInputImageKey)
        toneCurveFilter.setValue(point0, forKey: "inputPoint0")
        toneCurveFilter.setValue(point1, forKey: "inputPoint1")
        toneCurveFilter.setValue(point2, forKey: "inputPoint2")
        toneCurveFilter.setValue(point3, forKey: "inputPoint3")
        toneCurveFilter.setValue(point4, forKey: "inputPoint4")
        
        progress = 0.5
        
        // Add cinematic color cast
        guard let colorMatrixFilter = CIFilter(name: "CIColorMatrix") else {
            return toneCurveFilter.outputImage ?? image
        }
        
        colorMatrixFilter.setValue(toneCurveFilter.outputImage, forKey: kCIInputImageKey)
        colorMatrixFilter.setValue(CIVector(x: 1.0, y: 0.05, z: 0.1, w: 0), forKey: "inputRVector")
        colorMatrixFilter.setValue(CIVector(x: 0.05, y: 1.0, z: 0.05, w: 0), forKey: "inputGVector")
        colorMatrixFilter.setValue(CIVector(x: 0.1, y: 0.1, z: 0.9, w: 0), forKey: "inputBVector")
        
        progress = 0.8
        
        return colorMatrixFilter.outputImage ?? image
    }
    
    private func applyPortraitEffect(_ image: CIImage) async throws -> CIImage {
        progress = 0.2
        
        // Skin tone enhancement
        guard let vibrantFilter = CIFilter(name: "CIVibrance") else {
            throw EffectError.filterNotAvailable
        }
        vibrantFilter.setValue(image, forKey: kCIInputImageKey)
        vibrantFilter.setValue(0.3, forKey: kCIInputAmountKey)
        
        progress = 0.4
        
        // Soften skin
        guard let gaussianFilter = CIFilter(name: "CIGaussianBlur") else {
            return vibrantFilter.outputImage ?? image
        }
        gaussianFilter.setValue(vibrantFilter.outputImage, forKey: kCIInputImageKey)
        gaussianFilter.setValue(0.5, forKey: kCIInputRadiusKey)
        
        progress = 0.6
        
        // Blend with original for subtle softening
        guard let blendFilter = CIFilter(name: "CISourceOverCompositing") else {
            return gaussianFilter.outputImage ?? image
        }
        blendFilter.setValue(gaussianFilter.outputImage, forKey: kCIInputImageKey)
        blendFilter.setValue(vibrantFilter.outputImage, forKey: kCIInputBackgroundImageKey)
        
        progress = 0.8
        
        // Final skin tone adjustment
        guard let temperatureFilter = CIFilter(name: "CITemperatureAndTint") else {
            return blendFilter.outputImage ?? image
        }
        temperatureFilter.setValue(blendFilter.outputImage, forKey: kCIInputImageKey)
        temperatureFilter.setValue(CIVector(x: 5500, y: 50), forKey: kCIInputNeutralKey)
        temperatureFilter.setValue(CIVector(x: 5500, y: 50), forKey: kCIInputTargetNeutralKey)
        
        return temperatureFilter.outputImage ?? image
    }
    
    private func addVignette(_ image: CIImage) async throws -> CIImage {
        guard let vignetteFilter = CIFilter(name: "CIVignette") else {
            return image
        }
        
        vignetteFilter.setValue(image, forKey: kCIInputImageKey)
        vignetteFilter.setValue(1.0, forKey: kCIInputIntensityKey)
        vignetteFilter.setValue(2.0, forKey: kCIInputRadiusKey)
        
        return vignetteFilter.outputImage ?? image
    }
    
    func cancelProcessing() {
        isProcessing = false
        progress = 0.0
        currentEffect = "Cancelled"
    }
}

// MARK: - Effect Errors

enum EffectError: LocalizedError {
    case alreadyProcessing
    case invalidImage
    case processingFailed
    case filterNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .alreadyProcessing:
            return "Effect processing is already in progress"
        case .invalidImage:
            return "Invalid image format"
        case .processingFailed:
            return "Effect processing failed"
        case .filterNotAvailable:
            return "Required effect filter not available"
        }
    }
}