//
//  DeviceCapabilityManager.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import Foundation
import UIKit
import Combine

@MainActor
class DeviceCapabilityManager: ObservableObject {
    @Published var deviceModel: String = ""
    @Published var processorChip: String = ""
    @Published var isCapableOfOnDeviceProcessing: Bool = false
    @Published var hasNeuralEngine: Bool = false
    @Published var totalRAM: UInt64 = 0
    @Published var recommendedProcessingMethod: ProcessingMethod = .cloud
    @Published var deviceTier: DeviceTier = .basic
    
    enum ProcessingMethod: String, CaseIterable {
        case auto = "Auto"
        case onDevice = "On-Device"
        case cloud = "Cloud"
    }
    
    enum DeviceTier: String {
        case basic = "Basic"
        case capable = "Capable"
        case advanced = "Advanced"
    }
    
    init() {
        detectDeviceCapabilities()
    }
    
    private func detectDeviceCapabilities() {
        deviceModel = getDeviceModel()
        processorChip = getProcessorChip()
        totalRAM = getTotalRAM()
        hasNeuralEngine = checkNeuralEngineAvailability()
        isCapableOfOnDeviceProcessing = determineOnDeviceCapability()
        deviceTier = determineDeviceTier()
        recommendedProcessingMethod = determineRecommendedMethod()
    }
    
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
            }
        }
        
        return modelCode ?? "Unknown"
    }
    
    private func getProcessorChip() -> String {
        let model = deviceModel
        
        // iPhone models with their chips
        let chipMapping: [String: String] = [
            // A18 Pro (iPhone 16 Pro/Pro Max)
            "iPhone17,1": "A18 Pro", "iPhone17,2": "A18 Pro",
            // A18 (iPhone 16/16 Plus)
            "iPhone17,3": "A18", "iPhone17,4": "A18",
            // A17 Pro (iPhone 15 Pro/Pro Max)
            "iPhone16,1": "A17 Pro", "iPhone16,2": "A17 Pro",
            // A16 Bionic (iPhone 15/15 Plus, iPhone 14 Pro/Pro Max)
            "iPhone15,4": "A16", "iPhone15,5": "A16",
            "iPhone15,2": "A16", "iPhone15,3": "A16",
            // A15 Bionic (iPhone 14/14 Plus, iPhone 13 series)
            "iPhone14,7": "A15", "iPhone14,8": "A15",
            "iPhone14,4": "A15", "iPhone14,5": "A15", "iPhone14,2": "A15", "iPhone14,3": "A15",
            // A14 Bionic (iPhone 12 series)
            "iPhone13,1": "A14", "iPhone13,2": "A14", "iPhone13,3": "A14", "iPhone13,4": "A14",
            // A13 Bionic (iPhone 11 series)
            "iPhone12,1": "A13", "iPhone12,3": "A13", "iPhone12,5": "A13",
            // A12 Bionic (iPhone XS/XR series)
            "iPhone11,2": "A12", "iPhone11,4": "A12", "iPhone11,6": "A12", "iPhone11,8": "A12",
            // A11 Bionic (iPhone X/8 series)
            "iPhone10,1": "A11", "iPhone10,2": "A11", "iPhone10,3": "A11", "iPhone10,4": "A11", "iPhone10,5": "A11", "iPhone10,6": "A11"
        ]
        
        return chipMapping[model] ?? "Unknown"
    }
    
    private func getTotalRAM() -> UInt64 {
        let model = deviceModel
        
        // RAM mapping for iPhone models (in GB, converted to bytes)
        let ramMapping: [String: UInt64] = [
            // iPhone 16 series (8GB)
            "iPhone17,1": 8, "iPhone17,2": 8, "iPhone17,3": 8, "iPhone17,4": 8,
            // iPhone 15 Pro (8GB), iPhone 15 (6GB)
            "iPhone16,1": 8, "iPhone16,2": 8, "iPhone15,4": 6, "iPhone15,5": 6,
            // iPhone 14 Pro (6GB), iPhone 14 (6GB)
            "iPhone15,2": 6, "iPhone15,3": 6, "iPhone14,7": 6, "iPhone14,8": 6,
            // iPhone 13 series (6GB Pro, 4GB regular)
            "iPhone14,2": 6, "iPhone14,3": 6, "iPhone14,4": 4, "iPhone14,5": 4,
            // iPhone 12 series (6GB Pro, 4GB regular)
            "iPhone13,2": 6, "iPhone13,3": 6, "iPhone13,1": 4, "iPhone13,4": 4,
            // iPhone 11 series (4GB)
            "iPhone12,1": 4, "iPhone12,3": 4, "iPhone12,5": 4,
            // iPhone XS/XR series (4GB XS, 3GB XR)
            "iPhone11,2": 4, "iPhone11,4": 4, "iPhone11,6": 4, "iPhone11,8": 3,
            // iPhone X/8 series (3GB)
            "iPhone10,1": 2, "iPhone10,2": 2, "iPhone10,3": 3, "iPhone10,4": 2, "iPhone10,5": 2, "iPhone10,6": 3
        ]
        
        let ramGB = ramMapping[model] ?? 2
        return ramGB * 1024 * 1024 * 1024 // Convert GB to bytes
    }
    
    private func checkNeuralEngineAvailability() -> Bool {
        // Neural Engine available on A11 and later
        let neuralEngineChips = ["A11", "A12", "A13", "A14", "A15", "A16", "A17", "A18"]
        return neuralEngineChips.contains { processorChip.contains($0) }
    }
    
    private func determineOnDeviceCapability() -> Bool {
        // Require A14+ chip and at least 4GB RAM for on-device processing
        let capableChips = ["A14", "A15", "A16", "A17", "A18"]
        let hasCapableChip = capableChips.contains { processorChip.contains($0) }
        let hasEnoughRAM = totalRAM >= (4 * 1024 * 1024 * 1024) // 4GB
        
        return hasCapableChip && hasEnoughRAM && hasNeuralEngine
    }
    
    private func determineDeviceTier() -> DeviceTier {
        if processorChip.contains("A17") || processorChip.contains("A18") {
            return .advanced
        } else if processorChip.contains("A14") || processorChip.contains("A15") || processorChip.contains("A16") {
            return .capable
        } else {
            return .basic
        }
    }
    
    private func determineRecommendedMethod() -> ProcessingMethod {
        return isCapableOfOnDeviceProcessing ? .onDevice : .cloud
    }
    
    func getDeviceInfoSummary() -> String {
        let ramGB = totalRAM / (1024 * 1024 * 1024)
        return """
        Device: \(deviceModel)
        Processor: \(processorChip)
        RAM: \(ramGB)GB
        Neural Engine: \(hasNeuralEngine ? "Yes" : "No")
        On-Device Capable: \(isCapableOfOnDeviceProcessing ? "Yes" : "No")
        Device Tier: \(deviceTier.rawValue)
        Recommended: \(recommendedProcessingMethod.rawValue)
        """
    }
    
    func refreshCapabilities() {
        detectDeviceCapabilities()
    }
}