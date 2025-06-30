//
//  UIImage+Extensions.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import UIKit
import CoreImage
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

extension UIImage {
    
    // MARK: - Image Quality and Preprocessing
    
    func normalizeOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
    
    func resized(to targetSize: CGSize, maintainAspectRatio: Bool = true) -> UIImage? {
        let actualSize = maintainAspectRatio ? scaledSize(for: targetSize) : targetSize
        
        UIGraphicsBeginImageContextWithOptions(actualSize, false, 0.0)
        draw(in: CGRect(origin: .zero, size: actualSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    private func scaledSize(for targetSize: CGSize) -> CGSize {
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let scaleFactor = min(widthRatio, heightRatio)
        
        return CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
    }
    
    func compressedData(quality: CGFloat = 0.8, maxSizeBytes: Int = 5_000_000) -> Data? {
        var compressionQuality = quality
        var imageData = jpegData(compressionQuality: compressionQuality)
        
        while let data = imageData, data.count > maxSizeBytes && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            imageData = jpegData(compressionQuality: compressionQuality)
        }
        
        return imageData
    }
    
    // MARK: - Image Analysis
    
    func isGrayscale() -> Bool {
        guard let cgImage = cgImage else { return false }
        
        let colorSpace = cgImage.colorSpace
        return colorSpace?.model == .monochrome
    }
    
    func averageBrightness() -> CGFloat {
        guard let cgImage = cgImage else { return 0.5 }
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0.5 }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return 0.5 }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height)
        
        var totalBrightness: UInt64 = 0
        for i in 0..<(width * height) {
            totalBrightness += UInt64(pixels[i])
        }
        
        let averageBrightness = CGFloat(totalBrightness) / CGFloat(width * height * 255)
        return averageBrightness
    }
    
    func hasLowContrast() -> Bool {
        guard let cgImage = cgImage else { return false }
        
        // Sample the image at multiple points to check for contrast
        let samplePoints = [
            CGPoint(x: 0.25, y: 0.25),
            CGPoint(x: 0.75, y: 0.25),
            CGPoint(x: 0.25, y: 0.75),
            CGPoint(x: 0.75, y: 0.75),
            CGPoint(x: 0.5, y: 0.5)
        ]
        
        var brightnessValues: [CGFloat] = []
        
        for point in samplePoints {
            let x = Int(point.x * CGFloat(cgImage.width))
            let y = Int(point.y * CGFloat(cgImage.height))
            
            if let brightness = getPixelBrightness(at: CGPoint(x: x, y: y)) {
                brightnessValues.append(brightness)
            }
        }
        
        guard !brightnessValues.isEmpty else { return false }
        
        let maxBrightness = brightnessValues.max() ?? 0
        let minBrightness = brightnessValues.min() ?? 0
        let contrast = maxBrightness - minBrightness
        
        return contrast < 0.3 // Low contrast threshold
    }
    
    private func getPixelBrightness(at point: CGPoint) -> CGFloat? {
        guard let cgImage = cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: -Int(point.x), y: -Int(point.y), width: width, height: height))
        
        guard let data = context.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: 4)
        
        let red = CGFloat(pixels[0]) / 255.0
        let green = CGFloat(pixels[1]) / 255.0
        let blue = CGFloat(pixels[2]) / 255.0
        
        // Calculate luminance
        return 0.299 * red + 0.587 * green + 0.114 * blue
    }
    
    // MARK: - Image Enhancement
    
    func enhanced() -> UIImage? {
        guard let cgImage = cgImage else { return nil }
        
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        // Apply basic enhancements
        guard let exposureFilter = CIFilter(name: "CIExposureAdjust"),
              let contrastFilter = CIFilter(name: "CIColorControls") else {
            return self
        }
        
        // Adjust exposure based on average brightness
        let brightness = averageBrightness()
        let exposureAdjustment = brightness < 0.3 ? 0.5 : (brightness > 0.7 ? -0.3 : 0.0)
        
        exposureFilter.setValue(ciImage, forKey: kCIInputImageKey)
        exposureFilter.setValue(exposureAdjustment, forKey: kCIInputEVKey)
        
        guard let exposedImage = exposureFilter.outputImage else { return self }
        
        // Adjust contrast if needed
        let contrastAdjustment = hasLowContrast() ? 1.2 : 1.0
        
        contrastFilter.setValue(exposedImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(contrastAdjustment, forKey: kCIInputContrastKey)
        
        guard let finalImage = contrastFilter.outputImage,
              let outputCGImage = context.createCGImage(finalImage, from: finalImage.extent) else {
            return self
        }
        
        return UIImage(cgImage: outputCGImage)
    }
    
    // MARK: - CoreML Preparation
    
    func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attributes,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }
        
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        
        UIGraphicsPushContext(context)
        draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
    
    // MARK: - Metadata and EXIF
    
    func jpegDataWithMetadata(compressionQuality: CGFloat = 0.9) -> Data? {
        guard let cgImage = cgImage else { return nil }
        
        let mutableData = NSMutableData()
        
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        
        let metadata: [String: Any] = [
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifVersion as String: "LegacyLense",
                kCGImagePropertyExifDateTimeOriginal as String: ISO8601DateFormatter().string(from: Date())
            ],
            kCGImagePropertyTIFFDictionary as String: [
                kCGImagePropertyTIFFSoftware as String: "LegacyLense AI Photo Restoration"
            ]
        ]
        
        let options: [String: Any] = [
            kCGImageDestinationLossyCompressionQuality as String: compressionQuality
        ]
        
        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
        CGImageDestinationSetProperties(destination, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else { return nil }
        
        return mutableData as Data
    }
    
    // MARK: - Utility Methods
    
    var aspectRatio: CGFloat {
        return size.width / size.height
    }
    
    var megapixels: Double {
        return Double(size.width * size.height) / 1_000_000
    }
    
    func cropped(to rect: CGRect) -> UIImage? {
        guard let cgImage = cgImage?.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
    
    static func from(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}