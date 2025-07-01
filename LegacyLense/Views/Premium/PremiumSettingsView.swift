//
//  PremiumSettingsView.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI

struct PremiumSettingsView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var deviceCapabilityManager: DeviceCapabilityManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var animateGradient = false
    @State private var processingQuality: ProcessingQuality = .high
    @State private var enableOnDeviceProcessing = true
    @State private var enableCloudFallback = true
    @State private var autoSaveToPhotos = true
    @State private var enableHapticFeedback = true
    @State private var preserveMetadata = true
    @State private var watermarkEnabled = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    
    enum ProcessingQuality: String, CaseIterable {
        case standard = "Standard"
        case high = "High"
        case maximum = "Maximum"
        
        var description: String {
            switch self {
            case .standard: return "Faster processing, good quality"
            case .high: return "Balanced speed and quality"
            case .maximum: return "Best quality, slower processing"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Premium background
                premiumBackground
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Account section
                        accountSection
                        
                        // Processing settings
                        processingSection
                        
                        // Advanced settings
                        advancedSection
                        
                        // Device info
                        deviceInfoSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Settings")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            startGradientAnimation()
            loadSettings()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            LegalDocumentView(document: .privacyPolicy)
        }
        .sheet(isPresented: $showingTermsOfService) {
            LegalDocumentView(document: .termsOfService)
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
    
    private var accountSection: some View {
        PremiumSettingsSection(title: "Account", icon: "person.circle") {
            VStack(spacing: 16) {
                // Subscription status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Subscription Status")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text(subscriptionStatusText)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    subscriptionBadge
                }
                
                Divider()
                    .background(.white.opacity(0.1))
                
                // Processing credits
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Processing Credits")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("Remaining: \(subscriptionManager.remainingProcessingCredits)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    if subscriptionManager.subscriptionStatus == .notSubscribed {
                        Button("Get More") {
                            // Open subscription view
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.purple)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
    
    private var processingSection: some View {
        PremiumSettingsSection(title: "Processing", icon: "gearshape.2") {
            VStack(spacing: 16) {
                // Quality setting
                VStack(alignment: .leading, spacing: 8) {
                    Text("Processing Quality")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    Picker("Quality", selection: $processingQuality) {
                        ForEach(ProcessingQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Text(processingQuality.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Divider()
                    .background(.white.opacity(0.1))
                
                // Processing options
                PremiumToggleRow(
                    title: "On-Device Processing",
                    subtitle: "Use device AI when available",
                    isOn: $enableOnDeviceProcessing
                )
                
                PremiumToggleRow(
                    title: "Cloud Fallback",
                    subtitle: "Use cloud processing when needed",
                    isOn: $enableCloudFallback
                )
            }
        }
    }
    
    private var advancedSection: some View {
        PremiumSettingsSection(title: "Advanced", icon: "slider.horizontal.3") {
            VStack(spacing: 16) {
                PremiumToggleRow(
                    title: "Auto-Save to Photos",
                    subtitle: "Automatically save processed photos",
                    isOn: $autoSaveToPhotos
                )
                
                PremiumToggleRow(
                    title: "Haptic Feedback",
                    subtitle: "Vibration feedback for interactions",
                    isOn: $enableHapticFeedback
                )
                
                PremiumToggleRow(
                    title: "Preserve Metadata",
                    subtitle: "Keep original photo information",
                    isOn: $preserveMetadata
                )
                
                if subscriptionManager.subscriptionStatus == .notSubscribed {
                    PremiumToggleRow(
                        title: "Watermark",
                        subtitle: "Add LegacyLense watermark",
                        isOn: $watermarkEnabled
                    )
                }
                
                Divider()
                    .background(.white.opacity(0.2))
                
                VStack(spacing: 12) {
                    Button("Privacy Policy") {
                        showingPrivacyPolicy = true
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 16))
                    
                    Button("Terms of Service") {
                        showingTermsOfService = true
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 16))
                }
            }
        }
    }
    
    private var deviceInfoSection: some View {
        PremiumSettingsSection(title: "Device Information", icon: "iphone") {
            VStack(spacing: 12) {
                InfoRow(
                    title: "Device Model",
                    value: deviceCapabilityManager.deviceModel
                )
                
                InfoRow(
                    title: "Processor",
                    value: deviceCapabilityManager.processorChip
                )
                
                InfoRow(
                    title: "Neural Engine",
                    value: deviceCapabilityManager.hasNeuralEngine ? "Available" : "Not Available"
                )
                
                InfoRow(
                    title: "On-Device AI",
                    value: deviceCapabilityManager.isCapableOfOnDeviceProcessing ? "Supported" : "Not Supported"
                )
            }
        }
    }
    
    private var subscriptionStatusText: String {
        switch subscriptionManager.subscriptionStatus {
        case .pro: return "Pro Subscriber"
        case .basic: return "Basic Subscriber"
        case .expired: return "Subscription Expired"
        case .processing: return "Processing Payment"
        default: return "Free User"
        }
    }
    
    private var subscriptionBadge: some View {
        Text(subscriptionManager.subscriptionStatus == .pro ? "PRO" : 
             subscriptionManager.subscriptionStatus == .basic ? "BASIC" : "FREE")
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(subscriptionBadgeColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private var subscriptionBadgeColor: Color {
        switch subscriptionManager.subscriptionStatus {
        case .pro: return .purple
        case .basic: return .blue
        default: return .gray
        }
    }
    
    private func startGradientAnimation() {
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            animateGradient = true
        }
    }
    
    private func loadSettings() {
        // Load settings from UserDefaults
        processingQuality = ProcessingQuality(rawValue: UserDefaults.standard.string(forKey: "processing_quality") ?? "high") ?? .high
        enableOnDeviceProcessing = UserDefaults.standard.bool(forKey: "enable_on_device")
        enableCloudFallback = UserDefaults.standard.bool(forKey: "enable_cloud_fallback")
        autoSaveToPhotos = UserDefaults.standard.bool(forKey: "auto_save_photos")
        enableHapticFeedback = UserDefaults.standard.bool(forKey: "haptic_feedback")
        preserveMetadata = UserDefaults.standard.bool(forKey: "preserve_metadata")
        watermarkEnabled = UserDefaults.standard.bool(forKey: "watermark_enabled")
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(processingQuality.rawValue, forKey: "processing_quality")
        UserDefaults.standard.set(enableOnDeviceProcessing, forKey: "enable_on_device")
        UserDefaults.standard.set(enableCloudFallback, forKey: "enable_cloud_fallback")
        UserDefaults.standard.set(autoSaveToPhotos, forKey: "auto_save_photos")
        UserDefaults.standard.set(enableHapticFeedback, forKey: "haptic_feedback")
        UserDefaults.standard.set(preserveMetadata, forKey: "preserve_metadata")
        UserDefaults.standard.set(watermarkEnabled, forKey: "watermark_enabled")
    }
}

// MARK: - Supporting Views

struct PremiumSettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.purple)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            content
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
}

struct PremiumToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(.purple)
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    PremiumSettingsView()
        .environmentObject(SubscriptionManager())
        .environmentObject(DeviceCapabilityManager())
}