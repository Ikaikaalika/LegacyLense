//
//  TestHelpers.swift
//  LegacyLenseTests
//
//  Created by Tyler Gee on 6/12/25.
//

import UIKit
import XCTest
@testable import LegacyLense

// MARK: - Test Image Helpers

struct TestImageFactory {
    
    static func createSolidColorImage(color: UIColor = .red, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    static func createTestPatternImage(size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        // Create a checkerboard pattern
        let squareSize = min(size.width, size.height) / 4
        
        for row in 0..<Int(size.height / squareSize) {
            for col in 0..<Int(size.width / squareSize) {
                let color: UIColor = (row + col) % 2 == 0 ? .black : .white
                color.setFill()
                
                let rect = CGRect(
                    x: CGFloat(col) * squareSize,
                    y: CGFloat(row) * squareSize,
                    width: squareSize,
                    height: squareSize
                )
                UIRectFill(rect)
            }
        }
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    static func createGradientImage(size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return UIImage()
        }
        
        let colors = [UIColor.red.cgColor, UIColor.blue.cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil) else {
            return UIImage()
        }
        
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    static func createGrayscaleImage(size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        // Create grayscale pattern
        let squareSize = size.width / 8
        
        for i in 0..<8 {
            let grayValue = CGFloat(i) / 7.0
            UIColor(white: grayValue, alpha: 1.0).setFill()
            
            let rect = CGRect(
                x: CGFloat(i) * squareSize,
                y: 0,
                width: squareSize,
                height: size.height
            )
            UIRectFill(rect)
        }
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    static func createLargeTestImage() -> UIImage {
        return createTestPatternImage(size: CGSize(width: 2048, height: 2048))
    }
    
    static func createSmallTestImage() -> UIImage {
        return createTestPatternImage(size: CGSize(width: 50, height: 50))
    }
}

// MARK: - Mock Objects

class MockModelDownloader: ModelDownloader {
    
    var shouldFailDownload = false
    var downloadDelay: TimeInterval = 0.1
    
    override func loadModel(for modelType: PhotoRestorationModel.RestorationModelType) async throws -> MLModel? {
        if shouldFailDownload {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock download failure"])
        }
        
        // Simulate download delay
        try await Task.sleep(nanoseconds: UInt64(downloadDelay * 1_000_000_000))
        
        return nil // Return nil to simulate no actual model loading
    }
}

class MockRealPhotoProcessor: RealPhotoProcessor {
    
    var shouldFailProcessing = false
    var processingDelay: TimeInterval = 0.1
    var mockProgress: Double = 0.0
    var mockCurrentStage: String = "Ready"
    
    override var progress: Double {
        return mockProgress
    }
    
    override var currentStage: String {
        return mockCurrentStage
    }
    
    override func processPhoto(_ image: UIImage) async throws -> UIImage {
        if shouldFailProcessing {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock processing failure"])
        }
        
        // Simulate processing with progress updates
        for i in 1...5 {
            mockProgress = Double(i) / 5.0
            mockCurrentStage = "Processing step \(i)"
            try await Task.sleep(nanoseconds: UInt64(processingDelay * 200_000_000)) // 0.02s per step
        }
        
        mockProgress = 1.0
        mockCurrentStage = "Complete"
        
        return image // Return the same image for testing
    }
}

// MARK: - Test Assertions

extension XCTestCase {
    
    func assertImagesEqual(_ image1: UIImage, _ image2: UIImage, accuracy: Double = 0.1, file: StaticString = #file, line: UInt = #line) {
        guard let data1 = image1.pngData(),
              let data2 = image2.pngData() else {
            XCTFail("Failed to get PNG data from images", file: file, line: line)
            return
        }
        
        XCTAssertEqual(data1.count, data2.count, accuracy: Int(Double(data1.count) * accuracy), "Image sizes should be similar", file: file, line: line)
    }
    
    func assertImageSize(_ image: UIImage, expectedSize: CGSize, accuracy: CGFloat = 1.0, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(image.size.width, expectedSize.width, accuracy: accuracy, "Image width should match", file: file, line: line)
        XCTAssertEqual(image.size.height, expectedSize.height, accuracy: accuracy, "Image height should match", file: file, line: line)
    }
    
    func assertImageIsNotEmpty(_ image: UIImage, file: StaticString = #file, line: UInt = #line) {
        XCTAssertGreaterThan(image.size.width, 0, "Image width should be greater than 0", file: file, line: line)
        XCTAssertGreaterThan(image.size.height, 0, "Image height should be greater than 0", file: file, line: line)
        XCTAssertNotNil(image.cgImage, "Image should have CGImage", file: file, line: line)
    }
    
    func waitForCondition(_ condition: @escaping () -> Bool, timeout: TimeInterval = 5.0, description: String = "Condition", file: StaticString = #file, line: UInt = #line) {
        let expectation = XCTestExpectation(description: description)
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if condition() {
                timer.invalidate()
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout)
        timer.invalidate()
    }
}

// MARK: - Performance Test Helpers

struct PerformanceTestHelper {
    
    static func measureImageProcessingTime<T>(_ operation: () throws -> T) -> (result: T?, duration: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let result = try operation()
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            return (result, duration)
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            return (nil, duration)
        }
    }
    
    static func measureAsyncImageProcessingTime<T>(_ operation: () async throws -> T) async -> (result: T?, duration: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let result = try await operation()
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            return (result, duration)
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            return (nil, duration)
        }
    }
}

// MARK: - Memory Test Helpers

struct MemoryTestHelper {
    
    static func getCurrentMemoryUsage() -> Int64 {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(taskInfo.phys_footprint) : 0
    }
    
    static func measureMemoryUsage<T>(during operation: () throws -> T) -> (result: T?, memoryDelta: Int64) {
        let memoryBefore = getCurrentMemoryUsage()
        
        do {
            let result = try operation()
            let memoryAfter = getCurrentMemoryUsage()
            return (result, memoryAfter - memoryBefore)
        } catch {
            let memoryAfter = getCurrentMemoryUsage()
            return (nil, memoryAfter - memoryBefore)
        }
    }
}

// MARK: - Test Data Generators

struct TestDataGenerator {
    
    static func generateRandomImages(count: Int, size: CGSize = CGSize(width: 100, height: 100)) -> [UIImage] {
        return (0..<count).map { _ in
            let colors: [UIColor] = [.red, .green, .blue, .yellow, .purple, .orange]
            let randomColor = colors.randomElement() ?? .red
            return TestImageFactory.createSolidColorImage(color: randomColor, size: size)
        }
    }
    
    static func generateTestModelInfos() -> [RealMLModelManager.MLModelInfo] {
        return [
            RealMLModelManager.MLModelInfo(
                id: "test_model_1",
                name: "Test Model 1",
                description: "Test model for unit testing",
                downloadURL: URL(string: "https://example.com/test1.mlmodel")!,
                fileSize: 1024,
                modelType: .enhancement,
                requiredRAM: 64,
                processingTime: "1-2 seconds"
            ),
            RealMLModelManager.MLModelInfo(
                id: "test_model_2",
                name: "Test Model 2",
                description: "Another test model",
                downloadURL: URL(string: "https://example.com/test2.mlmodel")!,
                fileSize: 2048,
                modelType: .superResolution,
                requiredRAM: 128,
                processingTime: "2-3 seconds"
            )
        ]
    }
}

// MARK: - Error Helpers

struct TestErrorHelper {
    
    static func createTestError(domain: String = "TestDomain", code: Int = 1, description: String = "Test error") -> NSError {
        return NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: description])
    }
    
    static func createNetworkError() -> NSError {
        return NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: [
            NSLocalizedDescriptionKey: "No internet connection"
        ])
    }
    
    static func createMemoryError() -> NSError {
        return NSError(domain: "MemoryErrorDomain", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Insufficient memory"
        ])
    }
}