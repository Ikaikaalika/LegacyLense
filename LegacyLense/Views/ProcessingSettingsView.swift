//
//  ProcessingSettingsView.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI

struct ProcessingSettingsView: View {
    @EnvironmentObject var viewModel: PhotoRestorationViewModel
    @EnvironmentObject var deviceCapabilityManager: DeviceCapabilityManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        PremiumSettingsView()
    }
}

struct LegacyProcessingSettingsView: View {
    @EnvironmentObject var viewModel: PhotoRestorationViewModel
    @EnvironmentObject var deviceCapabilityManager: DeviceCapabilityManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Device Information
                    deviceInfoSection
                    
                    // Processing Method
                    processingMethodSection
                    
                    // Processing Stages
                    processingStagesSection
                    
                    // Advanced Settings
                    advancedSettingsSection
                }
                .padding()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.saveSettings()
                        dismiss()
                    }
                    
                }
            }
        }
    }
    
    private var deviceInfoSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Device Information", systemImage: "iphone")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    infoRow("Device", value: deviceCapabilityManager.deviceModel)
                    infoRow("Processor", value: deviceCapabilityManager.processorChip)
                    infoRow("RAM", value: "\(deviceCapabilityManager.totalRAM / (1024 * 1024 * 1024))GB")
                    infoRow("Neural Engine", value: deviceCapabilityManager.hasNeuralEngine ? "Yes" : "No")
                    infoRow("On-Device Capable", value: deviceCapabilityManager.isCapableOfOnDeviceProcessing ? "Yes" : "No")
                    infoRow("Device Tier", value: deviceCapabilityManager.deviceTier.rawValue)
                }
                
                if deviceCapabilityManager.isCapableOfOnDeviceProcessing {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.adaptiveGreen)
                        Text("Your device supports on-device AI processing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                } else {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text("Your device will use cloud processing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var processingMethodSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Processing Method", systemImage: "cpu")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Divider()
                
                VStack(spacing: 8) {
                    ForEach([
                        HybridPhotoRestorationService.ProcessingMethod.auto,
                        .onDevice,
                        .cloud,
                        .hybrid
                    ], id: \.self) { method in
                        processingMethodRow(method)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var processingStagesSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Processing Stages", systemImage: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Reset") {
                        viewModel.resetStages()
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
                
                Divider()
                
                VStack(spacing: 12) {
                    ForEach(PhotoRestorationModel.RestorationModelType.allCases, id: \.self) { stage in
                        processingStageRow(stage)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var advancedSettingsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Advanced", systemImage: "gearshape")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Divider()
                
                VStack(spacing: 16) {
                    Button(action: {
                        viewModel.showingModelDownload = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Manage AI Models")
                            Spacer()
                            Text(getModelStatus())
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                    
                    Button(action: {
                        deviceCapabilityManager.refreshCapabilities()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Device Capabilities")
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                
        }
    }
    
    private func processingMethodRow(_ method: HybridPhotoRestorationService.ProcessingMethod) -> some View {
        Button(action: {
            viewModel.processingMethod = method
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(method.displayName)
                        .font(.subheadline)
                        
                    
                    Text(getMethodDescription(method))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if viewModel.processingMethod == method {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
    
    private func processingStageRow(_ stage: PhotoRestorationModel.RestorationModelType) -> some View {
        Button(action: {
            viewModel.toggleProcessingStage(stage)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stage.displayName)
                        .font(.subheadline)
                        
                    
                    Text(getStageDescription(stage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { viewModel.enabledStages.contains(stage) },
                    set: { _ in viewModel.toggleProcessingStage(stage) }
                ))
                .labelsHidden()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
    
    private func getMethodDescription(_ method: HybridPhotoRestorationService.ProcessingMethod) -> String {
        switch method {
        case .auto:
            return "Automatically chooses the best processing method based on your device capabilities and network availability"
        case .onDevice:
            return "Process photos locally on your device using AI models. Requires model downloads and compatible hardware"
        case .cloud:
            return "Process photos using cloud-based AI servers. Requires internet connection"
        case .hybrid:
            return "Combines on-device and cloud processing for optimal results"
        }
    }
    
    private func getStageDescription(_ stage: PhotoRestorationModel.RestorationModelType) -> String {
        switch stage {
        case .scratchRemoval:
            return "Removes scratches, dust, and other physical damage from photos"
        case .colorization:
            return "Adds natural colors to black and white photos"
        case .faceRestoration:
            return "Enhances and restores facial features in photos"
        case .superResolution:
            return "Increases image resolution and sharpness"
        }
    }
    
    private func getModelStatus() -> String {
        guard let capabilities = viewModel.getProcessingCapabilities() else {
            return "Unknown"
        }
        
        let available = capabilities.availableOnDeviceModels.count
        let total = PhotoRestorationModel.RestorationModelType.allCases.count
        
        return "\(available) of \(total) models"
    }
}

#Preview {
    ProcessingSettingsView()
        .environmentObject(PhotoRestorationViewModel())
        .environmentObject(DeviceCapabilityManager())
}