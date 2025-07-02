//
//  BatchProcessingView.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI

struct BatchProcessingView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var loadedImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var processedImages: [UIImage] = []
    @State private var isProcessing = false
    @State private var currentProgress: Double = 0.0
    @State private var currentImageIndex = 0
    @State private var animateGradient = false
    @State private var showingResults = false
    
    private let maxBatchSize = 20
    
    var body: some View {
        NavigationView {
            ZStack {
                // Premium background
                premiumBackground
                
                if showingResults {
                    resultsView
                } else {
                    mainContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Batch Processing")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.adaptiveText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(showingResults ? "Done" : "Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.adaptiveText)
                }
            }
        }
        .onAppear {
            startGradientAnimation()
        }
    }
    
    // MARK: - UI Components
    
    private var premiumBackground: some View {
        Color.adaptiveBackground
            .ignoresSafeArea()
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection
                
                // Photo selection
                if loadedImages.isEmpty {
                    photoSelectionSection
                } else {
                    selectedPhotosSection
                }
                
                // Processing controls
                if !loadedImages.isEmpty && !isProcessing {
                    processingControlsSection
                }
                
                // Processing status
                if isProcessing {
                    processingStatusSection
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.adaptiveGreen.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                Image(systemName: "photo.stack")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color.adaptiveGreen.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.adaptiveGreen.opacity(0.5), radius: 15)
            }
            
            VStack(spacing: 8) {
                Text("Batch Processing")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color.adaptiveGreen.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Process up to \(maxBatchSize) photos at once")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.adaptiveText.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var photoSelectionSection: some View {
        VStack(spacing: 20) {
            Button(action: {
                showingImagePicker = true
            }) {
                VStack(spacing: 16) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(Color.adaptiveGreen)
                    
                    Text("Select Photos")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.adaptiveText)
                    
                    Text("Tap to add photos for batch processing")
                        .font(.system(size: 14))
                        .foregroundColor(Color.adaptiveText.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .sheet(isPresented: $showingImagePicker) {
                LegacyImagePicker { image in
                    if let image = image, loadedImages.count < maxBatchSize {
                        loadedImages.append(image)
                    }
                    showingImagePicker = false
                }
            }
            
            // Premium features info
            premiumFeaturesInfo
        }
    }
    
    private var selectedPhotosSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("\(loadedImages.count) Photos Selected")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.adaptiveText)
                
                Spacer()
                
                Button("Add More") {
                    if loadedImages.count < maxBatchSize {
                        showingImagePicker = true
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.adaptiveGreen)
                .foregroundColor(Color.adaptiveText)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Photo grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Array(loadedImages.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
    
    private var processingControlsSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                startBatchProcessing()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Process All Photos")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(Color.adaptiveText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.adaptiveGreen, Color.adaptiveGreen],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.adaptiveGreen.opacity(0.3), radius: 10, y: 5)
            }
            
            Text("Estimated time: \(estimatedProcessingTime)")
                .font(.system(size: 14))
                .foregroundColor(Color.adaptiveText.opacity(0.7))
        }
    }
    
    private var processingStatusSection: some View {
        VStack(spacing: 20) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: currentProgress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.adaptiveGreen, Color.adaptiveGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: currentProgress)
                
                VStack(spacing: 4) {
                    Text("\(Int(currentProgress * 100))%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.adaptiveText)
                    
                    Text("\(currentImageIndex)/\(loadedImages.count)")
                        .font(.system(size: 14))
                        .foregroundColor(Color.adaptiveText.opacity(0.7))
                }
            }
            
            VStack(spacing: 8) {
                Text("Processing Photos...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.adaptiveText)
                
                Text("Please keep the app open")
                    .font(.system(size: 14))
                    .foregroundColor(Color.adaptiveText.opacity(0.7))
            }
            
            Button("Cancel") {
                cancelProcessing()
            }
            .font(.system(size: 16, weight: .medium))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .foregroundColor(Color.adaptiveText)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success header
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Color.adaptiveGreen)
                    
                    Text("Processing Complete!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.adaptiveText)
                    
                    Text("Successfully processed \(processedImages.count) photos")
                        .font(.system(size: 16))
                        .foregroundColor(Color.adaptiveText.opacity(0.8))
                }
                
                // Results grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 16) {
                    ForEach(Array(processedImages.enumerated()), id: \.offset) { index, image in
                        VStack(spacing: 8) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                            
                            Button("Save") {
                                saveImage(image)
                            }
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.adaptiveGreen)
                            .foregroundColor(Color.adaptiveText)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                )
                
                // Save all button
                Button("Save All Photos") {
                    saveAllImages()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.adaptiveText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.adaptiveGreen, Color.adaptiveGreen],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    private var premiumFeaturesInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                Text("Premium Features")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.adaptiveText)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                FeatureBullet(text: "Process up to \(maxBatchSize) photos at once")
                FeatureBullet(text: "Automatic quality enhancement")
                FeatureBullet(text: "Background processing")
                FeatureBullet(text: "High-resolution output")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var estimatedProcessingTime: String {
        let timePerPhoto = 3 // seconds
        let totalTime = loadedImages.count * timePerPhoto
        
        if totalTime < 60 {
            return "\(totalTime) seconds"
        } else {
            let minutes = totalTime / 60
            let seconds = totalTime % 60
            return "\(minutes)m \(seconds)s"
        }
    }
    
    // MARK: - Functions
    
    private func startGradientAnimation() {
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            animateGradient = true
        }
    }
    
    
    private func startBatchProcessing() {
        guard subscriptionManager.subscriptionStatus == .pro else {
            // Show upgrade prompt
            return
        }
        
        isProcessing = true
        currentProgress = 0.0
        currentImageIndex = 0
        processedImages.removeAll()
        
        Task {
            for (index, image) in loadedImages.enumerated() {
                await MainActor.run {
                    currentImageIndex = index + 1
                    currentProgress = Double(index) / Double(loadedImages.count)
                }
                
                // Simulate processing (replace with actual photo processing)
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                // Add processed image (in real app, this would be the enhanced image)
                await MainActor.run {
                    processedImages.append(image) // Replace with actual processed image
                }
            }
            
            await MainActor.run {
                currentProgress = 1.0
                isProcessing = false
                showingResults = true
            }
        }
    }
    
    private func cancelProcessing() {
        isProcessing = false
        currentProgress = 0.0
        currentImageIndex = 0
    }
    
    private func saveImage(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
    
    private func saveAllImages() {
        for image in processedImages {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
}


struct FeatureBullet: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(Color.adaptiveGreen)
                .padding(.top, 2)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color.adaptiveText.opacity(0.8))
            
            Spacer()
        }
    }
}

#Preview {
    BatchProcessingView()
        .environmentObject(SubscriptionManager())
}