//
//  MLModelManagerView.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI

struct MLModelManagerView: View {
    @StateObject private var modelManager = RealMLModelManager()
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var animateGradient = false
    @State private var selectedModel: RealMLModelManager.MLModelInfo?
    @State private var showingModelDetails = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Premium background
                premiumBackground
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Storage info
                        storageInfoSection
                        
                        // Available models
                        if !modelManager.availableModels.isEmpty {
                            modelsSection
                        }
                        
                        // Quick actions
                        quickActionsSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("AI Models")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.adaptiveText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color.adaptiveText)
                }
            }
            .sheet(isPresented: $showingModelDetails) {
                if let model = selectedModel {
                    ModelDetailView(model: model, modelManager: modelManager)
                }
            }
            .alert("Delete Model", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let model = selectedModel {
                        try? modelManager.deleteModel(model.id)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this model? You'll need to download it again to use AI features.")
            }
        }
        .onAppear {
            startGradientAnimation()
        }
    }
    
    // MARK: - UI Components
    
    private var premiumBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.1, blue: 0.2),
                Color(red: 0.2, green: 0.1, blue: 0.3),
                Color(red: 0.15, green: 0.1, blue: 0.25)
            ],
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: animateGradient)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.adaptiveGreen.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .adaptiveGreen.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .adaptiveGreen.opacity(0.5), radius: 15)
            }
            
            VStack(spacing: 8) {
                Text("AI Model Manager")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .adaptiveGreen.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Download AI models for advanced photo processing")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.adaptiveText.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var storageInfoSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "internaldrive")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.cyan)
                
                Text("Storage Information")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.adaptiveText)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                StorageInfoRow(
                    title: "Downloaded Models",
                    value: "\(modelManager.getReadyModels().count)"
                )
                
                StorageInfoRow(
                    title: "Total Download Size",
                    value: modelManager.formatFileSize(modelManager.getTotalDownloadSize())
                )
                
                StorageInfoRow(
                    title: "Available Space",
                    value: getAvailableStorageSpace()
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "square.stack.3d.down.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.adaptiveGreen)
                
                Text("Available Models")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.adaptiveText)
                
                Spacer()
            }
            
            LazyVStack(spacing: 12) {
                ForEach(modelManager.availableModels, id: \.id) { model in
                    ModelCard(
                        model: model,
                        downloadState: modelManager.downloadStates[model.id] ?? .notDownloaded,
                        downloadProgress: modelManager.downloadProgress[model.id] ?? 0.0,
                        onDownload: {
                            Task {
                                do {
                                    try await modelManager.downloadModel(model)
                                } catch {
                                    // Handle error
                                }
                            }
                        },
                        onDetails: {
                            selectedModel = model
                            showingModelDetails = true
                        },
                        onDelete: {
                            selectedModel = model
                            showingDeleteAlert = true
                        }
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                downloadAllModels()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Download All Models")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(Color.adaptiveText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.adaptiveGreen, .adaptiveGreen],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(modelManager.getDownloadableModels().isEmpty)
            
            if !modelManager.getReadyModels().isEmpty {
                Button(action: {
                    deleteAllModels()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("Delete All Models")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(Color.adaptiveText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func startGradientAnimation() {
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            animateGradient = true
        }
    }
    
    private func downloadAllModels() {
        Task {
            for model in modelManager.getDownloadableModels() {
                do {
                    try await modelManager.downloadModel(model)
                } catch {
                    // Continue with next model
                }
            }
        }
    }
    
    private func deleteAllModels() {
        for model in modelManager.getReadyModels() {
            try? modelManager.deleteModel(model.id)
        }
    }
    
    private func getAvailableStorageSpace() -> String {
        if let resourceValues = try? FileManager.default.url(forUbiquityContainerIdentifier: nil)?.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
           let capacity = resourceValues.volumeAvailableCapacity {
            return modelManager.formatFileSize(Int64(capacity))
        }
        return "Unknown"
    }
}

// MARK: - Supporting Views

struct ModelCard: View {
    let model: RealMLModelManager.MLModelInfo
    let downloadState: RealMLModelManager.DownloadState
    let downloadProgress: Double
    let onDownload: () -> Void
    let onDetails: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.adaptiveText)
                    
                    Text(model.description)
                        .font(.system(size: 12))
                        .foregroundColor(Color.adaptiveText.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
                
                modelTypeIcon
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Size: \(formatFileSize(model.fileSize))")
                        .font(.system(size: 10))
                        .foregroundColor(Color.adaptiveText.opacity(0.6))
                    
                    Text("Time: \(model.processingTime)")
                        .font(.system(size: 10))
                        .foregroundColor(Color.adaptiveText.opacity(0.6))
                }
                
                Spacer()
                
                actionButton
            }
            
            if case .downloading = downloadState {
                ProgressView(value: downloadProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .adaptiveGreen))
                    .background(.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
        .onTapGesture {
            onDetails()
        }
    }
    
    private var modelTypeIcon: some View {
        let (icon, color) = modelTypeIconInfo
        return Image(systemName: icon)
            .font(.system(size: 20))
            .foregroundColor(color)
    }
    
    private var modelTypeIconInfo: (String, Color) {
        switch model.modelType {
        case .superResolution:
            return ("arrow.up.right.square", .adaptiveGreen)
        case .colorization:
            return ("paintpalette", .orange)
        case .faceRestoration:
            return ("face.smiling", .adaptiveGreen)
        case .noiseReduction:
            return ("waveform", .adaptiveGreen)
        case .enhancement:
            return ("sparkles", .yellow)
        }
    }
    
    private var actionButton: some View {
        Group {
            switch downloadState {
            case .notDownloaded:
                Button("Download", action: onDownload)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.adaptiveGreen)
                    .foregroundColor(Color.adaptiveText)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
            case .downloading:
                Button("Cancel") { /* Cancel download */ }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.orange)
                    .foregroundColor(Color.adaptiveText)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
            case .ready:
                Menu {
                    Button("View Details", action: onDetails)
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                        .foregroundColor(Color.adaptiveText)
                }
                
            case .failed:
                Button("Retry", action: onDownload)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.red)
                    .foregroundColor(Color.adaptiveText)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
            case .downloaded:
                Button("Install", action: onDownload)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.adaptiveGreen)
                    .foregroundColor(Color.adaptiveText)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
            case .installing:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            }
        }
    }
    
    private var borderColor: Color {
        switch downloadState {
        case .ready:
            return .adaptiveGreen.opacity(0.3)
        case .downloading:
            return .adaptiveGreen.opacity(0.3)
        case .failed:
            return .red.opacity(0.3)
        default:
            return .white.opacity(0.1)
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct StorageInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(Color.adaptiveText.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.adaptiveText)
        }
    }
}

struct ModelDetailView: View {
    let model: RealMLModelManager.MLModelInfo
    let modelManager: RealMLModelManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Model info
                    VStack(alignment: .leading, spacing: 16) {
                        Text(model.name)
                            .font(.title2.bold())
                        
                        Text(model.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            DetailRow(title: "Type", value: model.modelType.description)
                            DetailRow(title: "File Size", value: modelManager.formatFileSize(model.fileSize))
                            DetailRow(title: "Required RAM", value: "\(model.requiredRAM) MB")
                            DetailRow(title: "Processing Time", value: model.processingTime)
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("Model Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    MLModelManagerView()
        .environmentObject(SubscriptionManager())
}