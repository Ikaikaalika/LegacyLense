//
//  CompatibilityContentView.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI
import PhotosUI

struct CompatibilityContentView: View {
    @EnvironmentObject var viewModel: PhotoRestorationViewModel
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var deviceCapabilityManager: DeviceCapabilityManager
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showingImagePicker = false
    @State private var showingCameraPicker = false
    @State private var selectedTab = 0
    @State private var showingOnboarding = false
    @State private var animateGradient = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Premium background
                premiumBackground
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Premium header
                        premiumHeaderView
                        
                        // Main content with glass morphism
                        if viewModel.selectedPhoto != nil {
                            premiumPhotoView
                        } else {
                            premiumPhotoSelectionArea
                        }
                        
                        // Processing controls
                        if viewModel.selectedPhoto != nil {
                            premiumProcessingControls
                        }
                        
                        // AI Models section
                        aiModelsSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    premiumSettingsButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    premiumSubscriptionButton
                }
            }
            .sheet(isPresented: $viewModel.showingSettings) {
                ProcessingSettingsView()
            }
            .sheet(isPresented: $viewModel.showingModelDownload) {
                ModelDownloadView()
            }
            .sheet(isPresented: $viewModel.showingSubscription) {
                SubscriptionView()
            }
            .sheet(isPresented: $showingOnboarding) {
                OnboardingView()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .onAppear {
            setupDependencies()
            viewModel.loadSettings()
            startGradientAnimation()
            checkFirstLaunch()
        }
    }
    
    // MARK: - Premium UI Components
    
    private var premiumBackground: some View {
        ZStack {
            // Adaptive gradient background for light/dark mode
            Color.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: animateGradient)
            
            // Subtle texture overlay that adapts to color scheme
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(colorScheme == .dark ? 0.2 : 0.1)
                .ignoresSafeArea()
        }
    }
    
    private var premiumHeaderView: some View {
        VStack(spacing: 16) {
            // Premium logo with adaptive glow effect
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.adaptiveGreen.opacity(colorScheme == .dark ? 0.4 : 0.3), 
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: colorScheme == .dark ?
                                [Color(red: 0.9, green: 1.0, blue: 0.9), Color(red: 0.6, green: 0.9, blue: 0.6)] :
                                [Color.adaptiveGreen, Color(red: 0.2, green: 0.5, blue: 0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.adaptiveGreen.opacity(0.5), radius: 10)
            }
            
            VStack(spacing: 8) {
                Text("LegacyLense")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: colorScheme == .dark ? 
                                [Color(red: 0.8, green: 0.95, blue: 0.8), Color(red: 0.6, green: 0.9, blue: 0.6)] :
                                [Color.adaptiveText, Color.adaptiveGreen],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Make Your Photos Look Better")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.adaptiveText.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
    }
    
    private var premiumPhotoSelectionArea: some View {
        VStack(spacing: 24) {
            // Glass morphism container
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
                
                VStack(spacing: 20) {
                    Text("Choose a Photo to Improve")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color.adaptiveText)
                    
                    HStack(spacing: 16) {
                        // Camera button
                        PremiumActionButton(
                            icon: "camera.fill",
                            title: "Camera",
                            color: Color.adaptiveGreen,
                            colorScheme: colorScheme
                        ) {
                            showingCameraPicker = true
                        }
                        
                        // Library button
                        PremiumActionButton(
                            icon: "photo.on.rectangle",
                            title: "Library",
                            color: Color.adaptiveGreen.opacity(0.8),
                            colorScheme: colorScheme
                        ) {
                            showingImagePicker = true
                        }
                    }
                }
                .padding(32)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
        }
        .sheet(isPresented: $showingImagePicker) {
            LegacyImagePicker { image in
                if let image = image {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        viewModel.selectPhotoFromLibrary(image)
                    }
                }
                showingImagePicker = false
            }
        }
        .sheet(isPresented: $showingCameraPicker) {
            CameraPicker { image in
                if let image = image {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        viewModel.selectPhotoFromLibrary(image)
                    }
                }
                showingCameraPicker = false
            }
        }
    }
    
    private var premiumPhotoView: some View {
        VStack(spacing: 20) {
            // Premium photo container with glass morphism
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                
                VStack(spacing: 16) {
                    if let restoredPhoto = viewModel.restoredPhoto {
                        PremiumPhotoComparisonView(
                            originalImage: viewModel.originalPhoto!,
                            restoredImage: restoredPhoto,
                            sliderValue: $viewModel.comparisonSliderValue
                        )
                        .aspectRatio(1.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        Image(uiImage: viewModel.selectedPhoto!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    // Processing status with premium styling
                    if viewModel.isProcessing {
                        PremiumProcessingStatusView(
                            stage: viewModel.processingStage,
                            progress: viewModel.processingProgress
                        )
                    }
                }
                .padding(20)
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var premiumProcessingControls: some View {
        VStack(spacing: 20) {
            if !viewModel.isProcessing {
                // Premium restore button
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        viewModel.restorePhoto()
                    }
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.adaptiveText)
                        }
                        
                        Text("Improve Photo")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color.adaptiveText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: canProcessPhoto ? [Color.adaptiveGreen, Color.adaptiveGreen] : [.gray.opacity(0.3), .gray.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: canProcessPhoto ? Color.adaptiveGreen.opacity(0.3) : .clear, radius: 10, y: 5)
                }
                .disabled(!canProcessPhoto)
                .scaleEffect(canProcessPhoto ? 1.0 : 0.95)
                .animation(.spring(response: 0.3), value: canProcessPhoto)
                
                // Premium action buttons
                HStack(spacing: 12) {
                    PremiumSecondaryButton("New Photo", icon: "plus.circle") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            viewModel.clearPhotos()
                        }
                    }
                    
                    if viewModel.restoredPhoto != nil {
                        PremiumSecondaryButton("Save", icon: "square.and.arrow.down") {
                            viewModel.saveRestoredPhoto()
                        }
                    }
                }
            } else {
                // Premium cancel button
                PremiumSecondaryButton("Cancel Processing", icon: "xmark.circle") {
                    viewModel.cancelProcessing()
                }
            }
            
            // Premium usage info
            premiumUsageInfoView
        }
        .padding(.horizontal, 4)
    }
    
    private var premiumSettingsButton: some View {
        Button(action: {
            viewModel.showingSettings = true
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.adaptiveText)
            }
        }
    }
    
    private var premiumSubscriptionButton: some View {
        Button(action: {
            viewModel.showingSubscription = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: subscriptionIcon)
                    .font(.system(size: 12, weight: .semibold))
                Text(subscriptionText)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(subscriptionBackgroundGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(Color.adaptiveText)
            .shadow(color: subscriptionShadowColor, radius: 8, y: 2)
        }
    }
    
    private var premiumUsageInfoView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(usageText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.adaptiveText)
                    
                    Text(getUsageSubtext())
                        .font(.system(size: 12))
                        .foregroundColor(Color.adaptiveText.opacity(0.7))
                }
                
                Spacer()
                
                if subscriptionManager.subscriptionStatus == .notSubscribed {
                    Button("Upgrade") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            viewModel.showingSubscription = true
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.5, green: 0.8, blue: 0.4), Color.adaptiveGreen],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(Color.adaptiveText)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(16)
        }
    }
    
    private var aiModelsSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
                
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.adaptiveGreen.opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color.adaptiveGreen)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Photo Enhancement Options")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.adaptiveText)
                            
                            Text("All enhancement options are ready to use")
                                .font(.system(size: 14))
                                .foregroundColor(Color.adaptiveText.opacity(0.7))
                        }
                        
                        Spacer()
                    }
                    
                    // Simple feature list
                    VStack(alignment: .leading, spacing: 8) {
                        SimpleFeatureRow(icon: "checkmark.circle.fill", title: "Quick Fix - Makes photos look better", color: Color.adaptiveGreen)
                        SimpleFeatureRow(icon: "checkmark.circle.fill", title: "Better Quality - Improves colors", color: Color.adaptiveGreen)
                        SimpleFeatureRow(icon: "checkmark.circle.fill", title: "Best Quality - Professional results", color: Color.adaptiveGreen)
                        SimpleFeatureRow(icon: "checkmark.circle.fill", title: "Old Photo Repair - Fixes damaged photos", color: Color.adaptiveGreen)
                        SimpleFeatureRow(icon: "checkmark.circle.fill", title: "Add Color - Makes B&W photos colorful", color: Color.adaptiveGreen)
                    }
                }
                .padding(16)
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Computed Properties
    
    private var canProcessPhoto: Bool {
        subscriptionManager.canProcessPhoto()
    }
    
    private var subscriptionIcon: String {
        switch subscriptionManager.subscriptionStatus {
        case .pro: return "crown.fill"
        case .basic: return "star.fill"
        case .freeTrial: return "gift.fill"
        default: return "person.crop.circle"
        }
    }
    
    private var subscriptionText: String {
        switch subscriptionManager.subscriptionStatus {
        case .pro: return "Pro"
        case .basic: return "Basic"
        case .freeTrial: 
            let days = subscriptionManager.remainingTrialDays()
            return "Trial (\(days)d)"
        default: return "Free"
        }
    }
    
    private var subscriptionBackgroundGradient: LinearGradient {
        switch subscriptionManager.subscriptionStatus {
        case .pro: return LinearGradient(colors: [Color.adaptiveGreen, Color.adaptiveGreen], startPoint: .leading, endPoint: .trailing)
        case .basic: return LinearGradient(colors: [Color.adaptiveGreen, Color(red: 0.5, green: 0.9, blue: 0.5)], startPoint: .leading, endPoint: .trailing)
        case .freeTrial: return LinearGradient(colors: [Color.adaptiveGreen, .yellow], startPoint: .leading, endPoint: .trailing)
        default: return LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private var subscriptionShadowColor: Color {
        switch subscriptionManager.subscriptionStatus {
        case .pro: return Color.adaptiveGreen.opacity(0.3)
        case .basic: return Color.adaptiveGreen.opacity(0.3)
        case .freeTrial: return Color.adaptiveGreen.opacity(0.3)
        default: return .clear
        }
    }
    
    private var usageText: String {
        switch subscriptionManager.subscriptionStatus {
        case .pro: return "Unlimited processing"
        case .basic: return "50 photos per day"
        case .freeTrial: return "25 photos per day"
        default: return "\(viewModel.getRemainingCredits()) credits remaining"
        }
    }
    
    private func getUsageSubtext() -> String {
        switch subscriptionManager.subscriptionStatus {
        case .pro: return "Premium member"
        case .basic: return "Basic member"
        case .freeTrial: return "Free trial active"
        default: return "Free tier"
        }
    }
    
    private func setupDependencies() {
        let cloudService = CloudRestorationService()
        let photoModel = PhotoRestorationModel()
        let hybridService = HybridPhotoRestorationService(
            deviceCapabilityManager: deviceCapabilityManager,
            photoRestorationModel: photoModel,
            cloudRestorationService: cloudService
        )
        
        viewModel.setupDependencies(
            hybridService: hybridService,
            subscription: subscriptionManager
        )
    }
    
    private func startGradientAnimation() {
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            animateGradient = true
        }
    }
    
    private func checkFirstLaunch() {
        if !UserDefaults.standard.bool(forKey: "has_completed_onboarding") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingOnboarding = true
            }
        }
    }
}

// MARK: - Simple Feature Row for Seniors
struct SimpleFeatureRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(Color.adaptiveText)
            
            Spacer()
        }
    }
}

// MARK: - AI Feature Row (kept for compatibility)
struct AIFeatureRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
                .frame(width: 12)
            
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(Color.adaptiveText.opacity(0.8))
            
            Spacer()
        }
    }
}

// MARK: - Legacy Image Picker for iOS 15
struct LegacyImagePicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: LegacyImagePicker
        
        init(_ parent: LegacyImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            parent.onImageSelected(image)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onImageSelected(nil)
        }
    }
}

// MARK: - Camera Picker
struct CameraPicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.cameraCaptureMode = .photo
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        
        init(_ parent: CameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            parent.onImageSelected(image)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onImageSelected(nil)
        }
    }
}

// MARK: - Processing Status View
struct ProcessingStatusView: View {
    let stage: String
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Text(stage)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    CompatibilityContentView()
        .environmentObject(PhotoRestorationViewModel())
        .environmentObject(SubscriptionManager())
        .environmentObject(DeviceCapabilityManager())
}