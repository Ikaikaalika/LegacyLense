//
//  PremiumSubscriptionView.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI
import StoreKit

struct PremiumSubscriptionView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProduct: Product?
    @State private var animateGradient = false
    @State private var showingFeatures = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Premium background
                premiumBackground
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        premiumHeader
                        
                        // Feature highlights
                        featureHighlights
                        
                        // Subscription options
                        if !subscriptionManager.products.isEmpty {
                            subscriptionOptions
                        }
                        
                        // Features list
                        if showingFeatures {
                            fullFeaturesList
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.2))
                }
            }
            .safeAreaInset(edge: .bottom) {
                legalLinksFooter
            }
        }
        .onAppear {
            startGradientAnimation()
            Task {
                await subscriptionManager.loadProducts()
            }
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
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.98, blue: 0.95),
                    Color(red: 0.90, green: 0.95, blue: 0.90),
                    Color(red: 0.93, green: 0.97, blue: 0.93)
                ],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: animateGradient)
            
            // Sparkle effects
            ForEach(0..<20, id: \.self) { index in
                SparkleView()
                    .position(
                        x: CGFloat.random(in: 50...350),
                        y: CGFloat.random(in: 100...800)
                    )
            }
        }
    }
    
    private var premiumHeader: some View {
        VStack(spacing: 20) {
            // Premium crown icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.yellow.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .yellow.opacity(0.5), radius: 15)
            }
            
            VStack(spacing: 12) {
                Text("Unlock Premium Features")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .yellow.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                
                Text("Transform unlimited photos with AI-powered restoration")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.3).opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var featureHighlights: some View {
        HStack(spacing: 16) {
            FeatureHighlightCard(
                icon: "infinity",
                title: "Unlimited",
                subtitle: "Photos",
                color: Color(red: 0.3, green: 0.7, blue: 0.3)
            )
            
            FeatureHighlightCard(
                icon: "sparkles",
                title: "AI-Powered",
                subtitle: "Enhancement",
                color: Color(red: 0.4, green: 0.8, blue: 0.4)
            )
            
            FeatureHighlightCard(
                icon: "paintbrush.pointed",
                title: "Professional",
                subtitle: "Quality",
                color: Color(red: 0.4, green: 0.7, blue: 0.4)
            )
        }
    }
    
    private var subscriptionOptions: some View {
        VStack(spacing: 16) {
            Text("Choose Your Plan")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.2))
                .padding(.bottom, 8)
            
            ForEach(subscriptionManager.getSubscriptionProducts(), id: \.id) { product in
                SubscriptionOptionCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    subscriptionManager: subscriptionManager
                ) {
                    Task {
                        do {
                            try await subscriptionManager.purchase(product)
                            dismiss()
                        } catch {
                            // Handle error
                        }
                    }
                }
            }
            
            // Show all features button
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showingFeatures.toggle()
                }
            }) {
                HStack {
                    Text(showingFeatures ? "Hide Features" : "See All Features")
                        .font(.system(size: 16, weight: .medium))
                    Image(systemName: showingFeatures ? "chevron.up" : "chevron.down")
                }
                .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.3).opacity(0.8))
                .padding(.vertical, 12)
            }
        }
    }
    
    private var fullFeaturesList: some View {
        VStack(spacing: 16) {
            Text("What's Included")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.2))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVStack(spacing: 12) {
                FeatureRow(icon: "photo.artframe", title: "Unlimited Photo Processing", description: "Process as many photos as you want")
                FeatureRow(icon: "paintbrush.pointed.fill", title: "Advanced AI Restoration", description: "Scratch removal, colorization, and enhancement")
                FeatureRow(icon: "face.smiling", title: "Face Restoration", description: "Restore and enhance faces in old photos")
                FeatureRow(icon: "arrow.up.right.square", title: "Super Resolution", description: "Upscale photos to higher resolution")
                FeatureRow(icon: "palette", title: "Automatic Colorization", description: "Add realistic colors to black & white photos")
                FeatureRow(icon: "icloud.and.arrow.down", title: "Cloud Processing", description: "Process on powerful cloud servers")
                FeatureRow(icon: "square.and.arrow.down", title: "High Quality Export", description: "Save in full resolution with no watermarks")
                FeatureRow(icon: "headphones", title: "Priority Support", description: "Get help when you need it")
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
    
    private var legalLinksFooter: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button("Privacy Policy") {
                    showingPrivacyPolicy = true
                }
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.3).opacity(0.8))
                
                Text("•")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.3).opacity(0.8))
                
                Button("Terms of Service") {
                    showingTermsOfService = true
                }
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.3).opacity(0.8))
                
                Text("•")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.3).opacity(0.8))
                
                Button("Restore Purchases") {
                    Task {
                        try await subscriptionManager.restorePurchases()
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.3).opacity(0.8))
            }
            
            Text("Subscriptions auto-renew unless cancelled 24 hours before the current period ends.")
                .font(.system(size: 10))
                .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.3).opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
    
    private func startGradientAnimation() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            animateGradient = true
        }
    }
}

// MARK: - Supporting Views

struct FeatureHighlightCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.2))
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.3).opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct SubscriptionOptionCard: View {
    let product: Product
    let isSelected: Bool
    let subscriptionManager: SubscriptionManager
    let onTap: () -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        Button(action: {
            if !isProcessing {
                isProcessing = true
                onTap()
            }
        }) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.2))
                        
                        if let subscription = product.subscription {
                            Text("per \(subscription.subscriptionPeriod.localizedDescription)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.3).opacity(0.8))
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(product.displayPrice)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.2))
                        
                        if product.id.contains("yearly") {
                            Text("Save 60%")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.green)
                                .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                
                // Benefits
                if product.id.contains("pro") {
                    VStack(alignment: .leading, spacing: 6) {
                        BenefitRow(text: "Unlimited photo processing")
                        BenefitRow(text: "All AI features included")
                        BenefitRow(text: "Priority cloud processing")
                        BenefitRow(text: "Export without watermarks")
                    }
                } else if product.id.contains("basic") {
                    VStack(alignment: .leading, spacing: 6) {
                        BenefitRow(text: "50 photos per day")
                        BenefitRow(text: "Basic AI enhancement")
                        BenefitRow(text: "Standard processing speed")
                    }
                }
                
                // Subscribe button
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(height: 44)
                } else {
                    HStack {
                        Text("Subscribe")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.2))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.3, green: 0.7, blue: 0.3), Color(red: 0.4, green: 0.8, blue: 0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? 
                            LinearGradient(colors: [Color(red: 0.3, green: 0.7, blue: 0.3), Color(red: 0.4, green: 0.8, blue: 0.4)], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct BenefitRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.green)
            
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.3).opacity(0.8))
            
            Spacer()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.3, green: 0.7, blue: 0.3).opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 0.3))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.2))
                
                Text(description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.3).opacity(0.8))
            }
            
            Spacer()
        }
    }
}

struct SparkleView: View {
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: CGFloat.random(in: 8...16)))
            .foregroundColor(.white.opacity(opacity))
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: Double.random(in: 2...4))
                    .repeatForever(autoreverses: true)
                ) {
                    opacity = Double.random(in: 0.3...0.8)
                    scale = CGFloat.random(in: 0.8...1.2)
                }
            }
    }
}

#Preview {
    PremiumSubscriptionView()
        .environmentObject(SubscriptionManager())
}