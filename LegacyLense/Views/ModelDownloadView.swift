//
//  ModelDownloadView.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI

struct ModelDownloadView: View {
    @EnvironmentObject var deviceCapabilityManager: DeviceCapabilityManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var modelDownloader = ModelDownloader()
    
    @State private var showingDeleteAlert = false
    @State private var modelToDelete: PhotoRestorationModel.RestorationModelType?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Device Compatibility
                    compatibilitySection
                    
                    // Models List
                    modelsSection
                    
                    // Storage Info
                    storageSection
                    
                    // Bulk Actions
                    bulkActionsSection
                }
                .padding()
            }
            .navigationTitle("AI Models")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    
                }
            }
            .alert("Delete Model", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let model = modelToDelete {
                        deleteModel(model)
                    }
                }
            } message: {
                if let model = modelToDelete {
                    Text("Are you sure you want to delete the \(model.displayName) model? You can download it again later.")
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            Text("AI Model Management")
                .font(.title2)
                
            
            Text("Download AI models to enable on-device photo restoration. Models are large files and require WiFi.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var compatibilitySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Device Compatibility", systemImage: "checkmark.shield")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Divider()
                
                if deviceCapabilityManager.isCapableOfOnDeviceProcessing {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your device supports on-device AI processing")
                                .font(.subheadline)
                                
                            Text("iPhone with A14 chip or newer, 4GB+ RAM")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Limited on-device processing support")
                                .font(.subheadline)
                                
                            Text("Some models may not run optimally on this device")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var modelsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Available Models", systemImage: "square.stack.3d.down.right")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Divider()
                
                VStack(spacing: 16) {
                    ForEach(PhotoRestorationModel.RestorationModelType.allCases, id: \.self) { modelType in
                        modelRow(modelType)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var storageSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Storage Usage", systemImage: "internaldrive")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Divider()
                
                let (completed, total, totalSizeMB) = modelDownloader.getDownloadInfo()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Downloaded Models")
                        Spacer()
                        Text("\(completed) of \(total)")
                            
                    }
                    
                    HStack {
                        Text("Storage Used")
                        Spacer()
                        Text("\(String(format: "%.1f", totalSizeMB)) MB")
                            
                    }
                    
                    // Progress bar
                    ProgressView(value: Double(completed), total: Double(total))
                        .progressViewStyle(LinearProgressViewStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var bulkActionsSection: some View {
        VStack(spacing: 12) {
            // Download All button
            Button(action: {
                Task {
                    try? await modelDownloader.downloadAllModels()
                }
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Download All Models")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(modelDownloader.getAvailableModels().count == PhotoRestorationModel.RestorationModelType.allCases.count)
            
            // Delete All button
            Button(action: {
                try? modelDownloader.deleteAllModels()
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete All Models")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(12)
            }
            .disabled(modelDownloader.getAvailableModels().isEmpty)
        }
    }
    
    private func modelRow(_ modelType: PhotoRestorationModel.RestorationModelType) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(modelType.displayName)
                        .font(.subheadline)
                        
                    
                    Text(getModelDescription(modelType))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                modelActionButton(modelType)
            }
            
            // Download progress
            if let progress = modelDownloader.downloadProgress[modelType],
               modelDownloader.downloadStates[modelType] == .downloading {
                VStack(spacing: 4) {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    HStack {
                        Text("Downloading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func modelActionButton(_ modelType: PhotoRestorationModel.RestorationModelType) -> some View {
        Group {
            switch modelDownloader.downloadStates[modelType] {
            case .completed:
                Button(action: {
                    modelToDelete = modelType
                    showingDeleteAlert = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Downloaded")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderless)
                
            case .downloading:
                Button(action: {
                    modelDownloader.cancelDownload(for: modelType)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.circle")
                        Text("Cancel")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderless)
                
            case .failed:
                Button(action: {
                    Task {
                        try? await modelDownloader.downloadModel(for: modelType)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Retry")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderless)
                
            default:
                Button(action: {
                    Task {
                        try? await modelDownloader.downloadModel(for: modelType)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Download")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderless)
            }
        }
    }
    
    private func getModelDescription(_ modelType: PhotoRestorationModel.RestorationModelType) -> String {
        switch modelType {
        case .scratchRemoval:
            return "Removes scratches, dust, and damage • ~50MB"
        case .colorization:
            return "Adds natural colors to B&W photos • ~120MB"
        case .faceRestoration:
            return "Enhances facial features and details • ~80MB"
        case .superResolution:
            return "Increases resolution and sharpness • ~200MB"
        }
    }
    
    private func deleteModel(_ modelType: PhotoRestorationModel.RestorationModelType) {
        do {
            try modelDownloader.deleteModel(for: modelType)
        } catch {
            // Handle error - could show an alert
        }
    }
}

#Preview {
    ModelDownloadView()
        .environmentObject(DeviceCapabilityManager())
}