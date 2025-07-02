//
//  HybridPhotoRestorationService.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import Foundation
import UIKit
import Network
import Combine

@MainActor
class HybridPhotoRestorationService: ObservableObject {
    @Published var isProcessing = false
    @Published var processingMethod: ProcessingMethod = .auto
    @Published var currentStage = ""
    @Published var progress: Double = 0.0
    @Published var isNetworkAvailable = true
    
    private let deviceCapabilityManager: DeviceCapabilityManager
    private let photoRestorationModel: PhotoRestorationModel
    private let cloudRestorationService: CloudRestorationService
    private let networkMonitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    enum ProcessingMethod {
        case auto
        case onDevice
        case cloud
        case hybrid
    }
    
    enum ProcessingDecision {
        case useOnDevice(reason: String)
        case useCloud(reason: String)
        case useHybrid(onDeviceStages: Set<PhotoRestorationModel.RestorationModelType>, cloudStages: Set<PhotoRestorationModel.RestorationModelType>)
    }
    
    init(deviceCapabilityManager: DeviceCapabilityManager, 
         photoRestorationModel: PhotoRestorationModel,
         cloudRestorationService: CloudRestorationService) {
        self.deviceCapabilityManager = deviceCapabilityManager
        self.photoRestorationModel = photoRestorationModel
        self.cloudRestorationService = cloudRestorationService
        self.networkMonitor = NWPathMonitor()
        
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isNetworkAvailable = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    func restorePhoto(_ image: UIImage, 
                     method: ProcessingMethod = .auto,
                     enabledStages: Set<PhotoRestorationModel.RestorationModelType> = Set(PhotoRestorationModel.RestorationModelType.allCases),
                     subscriptionManager: SubscriptionManager) async throws -> UIImage {
        
        guard !isProcessing else {
            throw HybridProcessingError.alreadyProcessing
        }
        
        isProcessing = true
        progress = 0.0
        processingMethod = method
        
        defer {
            isProcessing = false
            currentStage = "Completed"
        }
        
        do {
            let decision = await makeProcessingDecision(method: method, enabledStages: enabledStages, subscriptionManager: subscriptionManager)
            
            switch decision {
            case .useOnDevice(let reason):
                currentStage = "Processing on device: \(reason)"
                return try await processOnDevice(image, enabledStages: enabledStages)
                
            case .useCloud(let reason):
                currentStage = "Processing in cloud: \(reason)"
                return try await processInCloud(image, enabledStages: enabledStages, subscriptionManager: subscriptionManager)
                
            case .useHybrid(let onDeviceStages, let cloudStages):
                currentStage = "Using hybrid processing"
                return try await processHybrid(image, onDeviceStages: onDeviceStages, cloudStages: cloudStages, subscriptionManager: subscriptionManager)
            }
            
        } catch {
            // Attempt fallback if primary method fails
            if method == .auto {
                return try await attemptFallback(image, enabledStages: enabledStages, originalError: error, subscriptionManager: subscriptionManager)
            } else {
                throw error
            }
        }
    }
    
    private func makeProcessingDecision(method: ProcessingMethod, 
                                       enabledStages: Set<PhotoRestorationModel.RestorationModelType>,
                                       subscriptionManager: SubscriptionManager) async -> ProcessingDecision {
        
        switch method {
        case .auto:
            return await makeAutoDecision(enabledStages: enabledStages, subscriptionManager: subscriptionManager)
            
        case .onDevice:
            if deviceCapabilityManager.isCapableOfOnDeviceProcessing && photoRestorationModel.areAllModelsAvailable() {
                return .useOnDevice(reason: "User preference")
            } else if subscriptionManager.hasCloudProcessingAccess() && isNetworkAvailable {
                return .useCloud(reason: "Device not capable, using cloud with subscription")
            } else {
                return .useOnDevice(reason: "Limited on-device processing (free tier)")
            }
            
        case .cloud:
            if subscriptionManager.hasCloudProcessingAccess() && isNetworkAvailable {
                return .useCloud(reason: "User preference with subscription")
            } else if !subscriptionManager.hasCloudProcessingAccess() {
                return .useOnDevice(reason: "Cloud processing requires subscription")
            } else {
                return .useOnDevice(reason: "Network unavailable, fallback to on-device")
            }
            
        case .hybrid:
            return await makeHybridDecision(enabledStages: enabledStages, subscriptionManager: subscriptionManager)
        }
    }
    
    private func makeAutoDecision(enabledStages: Set<PhotoRestorationModel.RestorationModelType>, subscriptionManager: SubscriptionManager) async -> ProcessingDecision {
        let isDeviceCapable = deviceCapabilityManager.isCapableOfOnDeviceProcessing
        let modelsAvailable = photoRestorationModel.areAllModelsAvailable()
        let networkAvailable = isNetworkAvailable
        
        // Priority: On-device if capable and models available
        if isDeviceCapable && modelsAvailable {
            return .useOnDevice(reason: "Device capable with all models available")
        }
        
        // Fallback to cloud if network available
        if networkAvailable {
            return .useCloud(reason: "Using cloud processing")
        }
        
        // Use partial on-device processing if some models available
        if isDeviceCapable {
            let availableModels = photoRestorationModel.getAvailableModels()
            let availableStages = Set(availableModels).intersection(enabledStages)
            
            if !availableStages.isEmpty {
                return .useOnDevice(reason: "Partial processing with available models")
            }
        }
        
        // Last resort - throw error
        return .useCloud(reason: "No processing options available")
    }
    
    private func makeHybridDecision(enabledStages: Set<PhotoRestorationModel.RestorationModelType>, subscriptionManager: SubscriptionManager) async -> ProcessingDecision {
        let availableModels = Set(photoRestorationModel.getAvailableModels())
        let onDeviceStages = availableModels.intersection(enabledStages)
        let cloudStages = enabledStages.subtracting(onDeviceStages)
        
        return .useHybrid(onDeviceStages: onDeviceStages, cloudStages: cloudStages)
    }
    
    private func processOnDevice(_ image: UIImage, 
                                enabledStages: Set<PhotoRestorationModel.RestorationModelType>) async throws -> UIImage {
        currentStage = "Processing on device"
        
        // Monitor progress from PhotoRestorationModel
        let progressTask = Task {
            while isProcessing {
                let (stage, progress) = photoRestorationModel.getProcessingProgress()
                await MainActor.run {
                    self.currentStage = "On-device: \(stage)"
                    self.progress = progress
                }
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        
        defer {
            progressTask.cancel()
        }
        
        return try await photoRestorationModel.restorePhoto(image, enabledStages: enabledStages)
    }
    
    private func processInCloud(_ image: UIImage, 
                               enabledStages: Set<PhotoRestorationModel.RestorationModelType>,
                               subscriptionManager: SubscriptionManager) async throws -> UIImage {
        currentStage = "Processing in cloud"
        
        guard isNetworkAvailable else {
            throw HybridProcessingError.networkUnavailable
        }
        
        // Monitor progress from CloudRestorationService
        let progressTask = Task {
            while isProcessing {
                await MainActor.run {
                    self.currentStage = "Cloud: \(cloudRestorationService.currentStage)"
                    self.progress = cloudRestorationService.progress
                }
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        
        defer {
            progressTask.cancel()
        }
        
        return try await cloudRestorationService.restorePhoto(image, enabledStages: enabledStages, subscriptionManager: subscriptionManager)
    }
    
    private func processHybrid(_ image: UIImage,
                              onDeviceStages: Set<PhotoRestorationModel.RestorationModelType>,
                              cloudStages: Set<PhotoRestorationModel.RestorationModelType>,
                              subscriptionManager: SubscriptionManager) async throws -> UIImage {
        
        var processedImage = image
        let totalStages = onDeviceStages.count + cloudStages.count
        var completedStages = 0
        
        // Process on-device stages first
        if !onDeviceStages.isEmpty {
            currentStage = "Hybrid: On-device processing"
            processedImage = try await photoRestorationModel.restorePhoto(processedImage, enabledStages: onDeviceStages)
            completedStages += onDeviceStages.count
            progress = Double(completedStages) / Double(totalStages)
        }
        
        // Process cloud stages
        if !cloudStages.isEmpty {
            guard isNetworkAvailable else {
                throw HybridProcessingError.networkUnavailable
            }
            
            currentStage = "Hybrid: Cloud processing"
            processedImage = try await cloudRestorationService.restorePhoto(processedImage, enabledStages: cloudStages, subscriptionManager: subscriptionManager)
            completedStages += cloudStages.count
            progress = Double(completedStages) / Double(totalStages)
        }
        
        return processedImage
    }
    
    private func attemptFallback(_ image: UIImage,
                                enabledStages: Set<PhotoRestorationModel.RestorationModelType>,
                                originalError: Error,
                                subscriptionManager: SubscriptionManager) async throws -> UIImage {
        
        currentStage = "Attempting fallback processing"
        
        // Try on-device first if not already attempted
        if deviceCapabilityManager.isCapableOfOnDeviceProcessing {
            let availableModels = Set(photoRestorationModel.getAvailableModels())
            let availableStages = availableModels.intersection(enabledStages)
            
            if !availableStages.isEmpty {
                do {
                    currentStage = "Fallback: On-device processing"
                    return try await photoRestorationModel.restorePhoto(image, enabledStages: availableStages)
                } catch {
                    // Continue to next fallback
                }
            }
        }
        
        // Try cloud fallback
        if isNetworkAvailable {
            do {
                currentStage = "Fallback: Cloud processing"
                return try await cloudRestorationService.restorePhoto(image, enabledStages: enabledStages, subscriptionManager: subscriptionManager)
            } catch {
                // Continue to next fallback
            }
        }
        
        // All fallbacks failed, throw original error
        throw originalError
    }
    
    func cancelProcessing() {
        photoRestorationModel.cancelProcessing()
        cloudRestorationService.cancelProcessing()
        isProcessing = false
        currentStage = "Cancelled"
        progress = 0.0
    }
    
    func getProcessingCapabilities() -> ProcessingCapabilities {
        let availableModels = photoRestorationModel.getAvailableModels()
        let missingModels = photoRestorationModel.getMissingModels()
        
        return ProcessingCapabilities(
            isDeviceCapable: deviceCapabilityManager.isCapableOfOnDeviceProcessing,
            isNetworkAvailable: isNetworkAvailable,
            availableOnDeviceModels: availableModels,
            missingOnDeviceModels: missingModels,
            recommendedMethod: determineRecommendedMethod()
        )
    }
    
    private func determineRecommendedMethod() -> ProcessingMethod {
        if deviceCapabilityManager.isCapableOfOnDeviceProcessing && photoRestorationModel.areAllModelsAvailable() {
            return .onDevice
        } else if isNetworkAvailable {
            return .cloud
        } else {
            return .hybrid
        }
    }
    
    deinit {
        networkMonitor.cancel()
    }
}

struct ProcessingCapabilities {
    let isDeviceCapable: Bool
    let isNetworkAvailable: Bool
    let availableOnDeviceModels: [PhotoRestorationModel.RestorationModelType]
    let missingOnDeviceModels: [PhotoRestorationModel.RestorationModelType]
    let recommendedMethod: HybridPhotoRestorationService.ProcessingMethod
}

enum HybridProcessingError: LocalizedError {
    case alreadyProcessing
    case networkUnavailable
    case noProcessingMethodAvailable
    case deviceNotCapable
    case modelsNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .alreadyProcessing:
            return "Processing is already in progress"
        case .networkUnavailable:
            return "Network connection is required but unavailable"
        case .noProcessingMethodAvailable:
            return "No processing method is currently available"
        case .deviceNotCapable:
            return "Device is not capable of on-device processing"
        case .modelsNotAvailable:
            return "Required AI models are not available"
        }
    }
}