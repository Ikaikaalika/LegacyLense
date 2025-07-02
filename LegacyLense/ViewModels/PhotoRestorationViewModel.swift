//
//  PhotoRestorationViewModel.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import Foundation
import UIKit
import SwiftUI
import PhotosUI
import Combine

@MainActor
class PhotoRestorationViewModel: ObservableObject {
    @Published var selectedPhoto: UIImage?
    @Published var originalPhoto: UIImage?
    @Published var restoredPhoto: UIImage?
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var processingStage = "Ready"
    @Published var errorMessage: String?
    @Published var showingPhotoPicker = false
    @Published var showingSettings = false
    @Published var showingModelDownload = false
    @Published var showingSubscription = false
    @Published var comparisonSliderValue: Double = 0.5
    @Published var enabledStages: Set<PhotoRestorationModel.RestorationModelType> = Set(PhotoRestorationModel.RestorationModelType.allCases)
    @Published var processingMethod: HybridPhotoRestorationService.ProcessingMethod = .auto
    
    private var hybridRestorationService: HybridPhotoRestorationService?
    private var subscriptionManager: SubscriptionManager?
    private var cancellables = Set<AnyCancellable>()
    
    func setupDependencies(hybridService: HybridPhotoRestorationService, subscription: SubscriptionManager) {
        self.hybridRestorationService = hybridService
        self.subscriptionManager = subscription
        
        // Subscribe to processing updates
        hybridService.$isProcessing
            .receive(on: DispatchQueue.main)
            .assign(to: \.isProcessing, on: self)
            .store(in: &cancellables)
        
        hybridService.$progress
            .receive(on: DispatchQueue.main)
            .assign(to: \.processingProgress, on: self)
            .store(in: &cancellables)
        
        hybridService.$currentStage
            .receive(on: DispatchQueue.main)
            .assign(to: \.processingStage, on: self)
            .store(in: &cancellables)
    }
    
    // Legacy photo selection for iOS 15 compatibility
    func selectPhoto(from data: Data?) {
        guard let data = data,
              let image = UIImage(data: data) else {
            errorMessage = "Failed to load photo"
            return
        }
        
        selectedPhoto = image
        originalPhoto = image
        restoredPhoto = nil
        errorMessage = nil
    }
    
    func selectPhotoFromLibrary(_ image: UIImage) {
        selectedPhoto = image
        originalPhoto = image
        restoredPhoto = nil
        errorMessage = nil
    }
    
    func restorePhoto() {
        guard let image = selectedPhoto else {
            errorMessage = "Please select a photo first"
            return
        }
        
        guard let hybridService = hybridRestorationService else {
            errorMessage = "Restoration service not available"
            return
        }
        
        guard let subscription = subscriptionManager else {
            errorMessage = "Subscription service not available"
            return
        }
        
        guard subscription.canProcessPhoto() else {
            errorMessage = "Processing limit reached. Please upgrade or purchase credits."
            showingSubscription = true
            return
        }
        
        Task {
            do {
                errorMessage = nil
                
                let restored = try await hybridService.restorePhoto(
                    image,
                    method: processingMethod,
                    enabledStages: enabledStages,
                    subscriptionManager: subscription
                )
                
                await MainActor.run {
                    self.restoredPhoto = restored
                    subscription.processPhoto() // Deduct credit if needed
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func saveRestoredPhoto() {
        guard let restoredImage = restoredPhoto else {
            errorMessage = "No restored photo to save"
            return
        }
        
        UIImageWriteToSavedPhotosAlbum(restoredImage, self, #selector(imageSaved(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func imageSaved(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            errorMessage = "Failed to save photo: \(error.localizedDescription)"
        } else {
            // Photo saved successfully - could show a success message
        }
    }
    
    func clearPhotos() {
        selectedPhoto = nil
        originalPhoto = nil
        restoredPhoto = nil
        errorMessage = nil
        processingProgress = 0.0
        processingStage = "Ready"
    }
    
    func cancelProcessing() {
        hybridRestorationService?.cancelProcessing()
    }
    
    func toggleProcessingStage(_ stage: PhotoRestorationModel.RestorationModelType) {
        if enabledStages.contains(stage) {
            enabledStages.remove(stage)
        } else {
            enabledStages.insert(stage)
        }
    }
    
    func resetStages() {
        enabledStages = Set(PhotoRestorationModel.RestorationModelType.allCases)
    }
    
    func getProcessingCapabilities() -> ProcessingCapabilities? {
        return hybridRestorationService?.getProcessingCapabilities()
    }
    
    func getSubscriptionStatus() -> SubscriptionManager.SubscriptionStatus {
        return subscriptionManager?.subscriptionStatus ?? .notSubscribed
    }
    
    func getRemainingCredits() -> Int {
        return subscriptionManager?.remainingProcessingCredits ?? 0
    }
    
    func getProcessingLimits() -> ProcessingLimits? {
        return subscriptionManager?.getProcessingLimits()
    }
    
    // MARK: - Settings Management
    
    func saveSettings() {
        UserDefaults.standard.set(processingMethod.rawValue, forKey: "processing_method")
        
        let stageNames = enabledStages.map { $0.rawValue }
        UserDefaults.standard.set(stageNames, forKey: "enabled_stages")
    }
    
    func loadSettings() {
        if let methodRaw = UserDefaults.standard.string(forKey: "processing_method"),
           let method = HybridPhotoRestorationService.ProcessingMethod(rawValue: methodRaw) {
            processingMethod = method
        }
        
        if let stageNames = UserDefaults.standard.array(forKey: "enabled_stages") as? [String] {
            let stages = stageNames.compactMap { PhotoRestorationModel.RestorationModelType(rawValue: $0) }
            enabledStages = Set(stages)
        }
    }
    
    // MARK: - Batch Processing (Pro feature)
    
    func processBatch(_ images: [UIImage]) async {
        guard let subscription = subscriptionManager,
              subscription.subscriptionStatus == .pro else {
            errorMessage = "Batch processing requires Pro subscription"
            return
        }
        
        guard let hybridService = hybridRestorationService else {
            errorMessage = "Restoration service not available"
            return
        }
        
        let totalImages = images.count
        var processedImages: [UIImage] = []
        
        for (index, image) in images.enumerated() {
            do {
                processingStage = "Processing image \(index + 1) of \(totalImages)"
                
                let restored = try await hybridService.restorePhoto(
                    image,
                    method: processingMethod,
                    enabledStages: enabledStages,
                    subscriptionManager: subscription
                )
                
                processedImages.append(restored)
                processingProgress = Double(index + 1) / Double(totalImages)
                
            } catch {
                errorMessage = "Failed to process image \(index + 1): \(error.localizedDescription)"
                return
            }
        }
        
        // Save batch results or present them to user
        processingStage = "Batch processing completed"
    }
    
    // MARK: - Export Options (Pro feature)
    
    func exportPhoto(format: ExportFormat) -> Data? {
        guard let image = restoredPhoto ?? selectedPhoto else { return nil }
        
        switch format {
        case .jpeg(let quality):
            return image.jpegData(compressionQuality: quality)
        case .png:
            return image.pngData()
        case .heic:
            // HEIC export would require additional implementation
            return image.jpegData(compressionQuality: 0.8)
        }
    }
}

// MARK: - Extensions

extension HybridPhotoRestorationService.ProcessingMethod {
    var rawValue: String {
        switch self {
        case .auto: return "auto"
        case .onDevice: return "on_device"
        case .cloud: return "cloud"
        case .hybrid: return "hybrid"
        }
    }
    
    init?(rawValue: String) {
        switch rawValue {
        case "auto": self = .auto
        case "on_device": self = .onDevice
        case "cloud": self = .cloud
        case "hybrid": self = .hybrid
        default: return nil
        }
    }
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .onDevice: return "On-Device"
        case .cloud: return "Cloud"
        case .hybrid: return "Hybrid"
        }
    }
}

enum ExportFormat {
    case jpeg(quality: CGFloat)
    case png
    case heic
    
    var displayName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        }
    }
}
