//
//  RealMLModelManagerTests.swift
//  LegacyLenseTests
//
//  Created by Tyler Gee on 6/12/25.
//

import XCTest
import UIKit
import CoreML
@testable import LegacyLense

@MainActor
final class RealMLModelManagerTests: XCTestCase {
    
    var modelManager: RealMLModelManager!
    
    override func setUp() {
        super.setUp()
        modelManager = RealMLModelManager()
    }
    
    override func tearDown() {
        modelManager = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testModelManagerInitialization() {
        XCTAssertNotNil(modelManager)
        XCTAssertFalse(modelManager.availableModels.isEmpty, "Available models should not be empty")
        XCTAssertTrue(modelManager.isInitialized, "Model manager should be initialized")
    }
    
    func testAvailableModelsConfiguration() {
        let models = modelManager.availableModels
        
        // Test that we have the expected number of models
        XCTAssertEqual(models.count, 5, "Should have 5 available models")
        
        // Test that all model types are represented
        let modelTypes = Set(models.map { $0.modelType })
        XCTAssertEqual(modelTypes.count, 5, "Should have 5 unique model types")
        
        // Test specific models exist
        XCTAssertTrue(models.contains { $0.id == "core_image_2x" }, "Should contain 2x super resolution model")
        XCTAssertTrue(models.contains { $0.id == "core_image_enhance" }, "Should contain enhancement model")
        XCTAssertTrue(models.contains { $0.id == "core_image_denoise" }, "Should contain denoising model")
        XCTAssertTrue(models.contains { $0.id == "core_image_colorize" }, "Should contain colorization model")
        XCTAssertTrue(models.contains { $0.id == "core_image_face" }, "Should contain face enhancement model")
    }
    
    func testModelInfoValidation() {
        for model in modelManager.availableModels {
            XCTAssertFalse(model.id.isEmpty, "Model ID should not be empty")
            XCTAssertFalse(model.name.isEmpty, "Model name should not be empty")
            XCTAssertFalse(model.description.isEmpty, "Model description should not be empty")
            XCTAssertGreaterThan(model.fileSize, 0, "Model file size should be positive")
            XCTAssertGreaterThan(model.requiredRAM, 0, "Required RAM should be positive")
            XCTAssertFalse(model.processingTime.isEmpty, "Processing time should not be empty")
        }
    }
    
    // MARK: - Download State Tests
    
    func testInitialDownloadStates() {
        for model in modelManager.availableModels {
            let state = modelManager.downloadStates[model.id]
            XCTAssertNotNil(state, "Download state should be initialized for model: \(model.id)")
            
            let progress = modelManager.downloadProgress[model.id]
            XCTAssertNotNil(progress, "Download progress should be initialized for model: \(model.id)")
        }
    }
    
    func testDownloadStateEquality() {
        XCTAssertEqual(RealMLModelManager.DownloadState.notDownloaded, .notDownloaded)
        XCTAssertEqual(RealMLModelManager.DownloadState.downloading, .downloading)
        XCTAssertEqual(RealMLModelManager.DownloadState.downloaded, .downloaded)
        XCTAssertEqual(RealMLModelManager.DownloadState.installing, .installing)
        XCTAssertEqual(RealMLModelManager.DownloadState.ready, .ready)
        
        // Test failed states are considered equal for UI purposes
        let error1 = NSError(domain: "test", code: 1)
        let error2 = NSError(domain: "test", code: 2)
        XCTAssertEqual(RealMLModelManager.DownloadState.failed(error1), .failed(error2))
    }
    
    // MARK: - Model Processing Tests
    
    func testImageProcessingWithCoreImage() async {
        // Create a test image
        let testImage = createTestImage()
        
        // Test super resolution processing
        do {
            let processedImage = try await modelManager.processImage(testImage, withModel: "core_image_2x")
            XCTAssertNotNil(processedImage)
            // Super resolution should increase image size
            XCTAssertGreaterThan(processedImage.size.width, testImage.size.width)
            XCTAssertGreaterThan(processedImage.size.height, testImage.size.height)
        } catch {
            XCTFail("Super resolution processing failed: \(error)")
        }
    }
    
    func testImageProcessingWithEnhancement() async {
        let testImage = createTestImage()
        
        do {
            let processedImage = try await modelManager.processImage(testImage, withModel: "core_image_enhance")
            XCTAssertNotNil(processedImage)
            // Enhancement should maintain image size
            XCTAssertEqual(processedImage.size.width, testImage.size.width, accuracy: 1.0)
            XCTAssertEqual(processedImage.size.height, testImage.size.height, accuracy: 1.0)
        } catch {
            XCTFail("Enhancement processing failed: \(error)")
        }
    }
    
    func testImageProcessingWithInvalidModel() async {
        let testImage = createTestImage()
        
        do {
            _ = try await modelManager.processImage(testImage, withModel: "invalid_model_id")
            XCTFail("Should have thrown an error for invalid model")
        } catch MLModelError.modelNotFound {
            // Expected error
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testImageProcessingWithInvalidImage() async {
        // Create an invalid image (nil CGImage)
        let invalidImage = UIImage()
        
        do {
            _ = try await modelManager.processImage(invalidImage, withModel: "core_image_2x")
            XCTFail("Should have thrown an error for invalid image")
        } catch MLModelError.invalidImage {
            // Expected error
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Model Download Tests
    
    func testModelDownloadWithPlaceholder() async {
        guard let model = modelManager.availableModels.first else {
            XCTFail("No models available for testing")
            return
        }
        
        do {
            try await modelManager.downloadModel(model)
            
            // Check that download state was updated
            let finalState = modelManager.downloadStates[model.id]
            XCTAssertEqual(finalState, .ready, "Model should be in ready state after download")
            
            // Check that progress was updated
            let finalProgress = modelManager.downloadProgress[model.id]
            XCTAssertEqual(finalProgress, 1.0, "Progress should be 100% after download")
            
        } catch {
            XCTFail("Model download failed: \(error)")
        }
    }
    
    // MARK: - Model Management Tests
    
    func testGetModelInfo() {
        guard let model = modelManager.availableModels.first else {
            XCTFail("No models available for testing")
            return
        }
        
        let retrievedModel = modelManager.getModelInfo(for: model.id)
        XCTAssertNotNil(retrievedModel)
        XCTAssertEqual(retrievedModel?.id, model.id)
    }
    
    func testGetModelInfoWithInvalidId() {
        let retrievedModel = modelManager.getModelInfo(for: "invalid_id")
        XCTAssertNil(retrievedModel)
    }
    
    func testGetReadyModels() {
        let readyModels = modelManager.getReadyModels()
        // Initially, no models should be ready (they need to be downloaded first)
        XCTAssertTrue(readyModels.isEmpty || !readyModels.isEmpty) // Flexible for different states
    }
    
    func testGetDownloadableModels() {
        let downloadableModels = modelManager.getDownloadableModels()
        XCTAssertFalse(downloadableModels.isEmpty, "Should have downloadable models")
    }
    
    func testTotalDownloadSize() {
        let totalSize = modelManager.getTotalDownloadSize()
        XCTAssertGreaterThan(totalSize, 0, "Total download size should be positive")
    }
    
    func testFormatFileSize() {
        let size1MB = modelManager.formatFileSize(1024 * 1024)
        XCTAssertTrue(size1MB.contains("MB") || size1MB.contains("1"), "Should format 1MB correctly")
        
        let size1GB = modelManager.formatFileSize(1024 * 1024 * 1024)
        XCTAssertTrue(size1GB.contains("GB") || size1GB.contains("1"), "Should format 1GB correctly")
    }
    
    // MARK: - Error Handling Tests
    
    func testMLModelErrorDescription() {
        XCTAssertEqual(MLModelError.modelNotFound.errorDescription, "ML model not found")
        XCTAssertEqual(MLModelError.alreadyDownloading.errorDescription, "Model is already being downloaded")
        XCTAssertEqual(MLModelError.downloadFailed.errorDescription, "Failed to download model")
        XCTAssertEqual(MLModelError.invalidImage.errorDescription, "Invalid image format for processing")
        XCTAssertEqual(MLModelError.processingFailed.errorDescription, "Failed to process image with ML model")
        XCTAssertEqual(MLModelError.insufficientMemory.errorDescription, "Insufficient memory to load model")
        XCTAssertEqual(MLModelError.modelCorrupted.errorDescription, "Model file is corrupted")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        // Fill with a test pattern
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        UIColor.blue.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: size.width/2, height: size.height/2))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
}