//
//  OnboardingView.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var subscriptionManager = SubscriptionManager()
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var showingPermissionRequest = false
    @State private var hasCompletedOnboarding = false
    
    private let pages = [
        OnboardingPage(
            title: "Restore Your Memories",
            subtitle: "Transform old, damaged photos into crystal-clear memories",
            imageName: "photo.artframe",
            description: "Our AI-powered technology brings life back to your precious photos"
        ),
        OnboardingPage(
            title: "Advanced AI Processing",
            subtitle: "Professional-grade photo restoration at your fingertips",
            imageName: "brain.head.profile",
            description: "Remove scratches, enhance colors, and improve clarity with cutting-edge AI"
        ),
        OnboardingPage(
            title: "Multiple Processing Options",
            subtitle: "Choose between on-device privacy or cloud-powered quality",
            imageName: "icloud.and.arrow.up",
            description: "Process photos locally for privacy or use our cloud service for maximum quality"
        ),
        OnboardingPage(
            title: "Premium Features",
            subtitle: "Unlock unlimited processing and advanced tools",
            imageName: "crown.fill",
            description: "Batch processing, priority support, and access to the latest AI models"
        )
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.adaptiveGreen : Color.gray.opacity(0.4))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentPage ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.bottom, 30)
                
                // Navigation buttons
                VStack(spacing: 16) {
                    if currentPage == pages.count - 1 {
                        // Final page - Trial and subscription options
                        VStack(spacing: 12) {
                            if !subscriptionManager.hasStartedTrial() {
                                Button(action: {
                                    subscriptionManager.startFreeTrial()
                                    requestPermissionsAndComplete()
                                }) {
                                    HStack {
                                        Image(systemName: "gift.fill")
                                        Text("Start 7-Day Free Trial")
                                    }
                                    .font(.headline)
                                    .foregroundColor(Color.adaptiveText)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.adaptiveGreen, Color.adaptiveGreen]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                }
                            }
                            
                            Button(action: {
                                requestPermissionsAndComplete()
                            }) {
                                Text(subscriptionManager.hasStartedTrial() ? "Continue" : "Continue with Free Version")
                                    .font(.subheadline)
                                    .foregroundColor(Color.adaptiveGreen)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.adaptiveGreen, lineWidth: 1)
                                    )
                            }
                        }
                    } else {
                        // Navigation buttons for other pages
                        HStack {
                            Button("Skip") {
                                requestPermissionsAndComplete()
                            }
                            .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Button("Next") {
                                withAnimation {
                                    currentPage += 1
                                }
                            }
                            .font(.headline)
                            .foregroundColor(Color.adaptiveText)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.adaptiveGreen)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
            .onAppear {
                Task {
                    await subscriptionManager.loadProducts()
                }
            }
        }
        .interactiveDismissDisabled(true)
        .sheet(isPresented: $showingPermissionRequest) {
            PermissionRequestView(showingPermissionRequest: $showingPermissionRequest) {
                completeOnboarding()
            }
        }
    }
    
    private func requestPermissionsAndComplete() {
        showingPermissionRequest = true
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
        hasCompletedOnboarding = true
        dismiss()
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon
            Image(systemName: page.imageName)
                .font(.system(size: 80))
                .foregroundColor(Color.adaptiveGreen)
                .padding(.bottom, 20)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
    let description: String
}

struct PermissionRequestView: View {
    @Binding var showingPermissionRequest: Bool
    let onComplete: () -> Void
    @State private var photoPermissionStatus: PhotoPermissionStatus = .notDetermined
    
    enum PhotoPermissionStatus {
        case notDetermined
        case denied
        case granted
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 80))
                    .foregroundColor(Color.adaptiveGreen)
                
                VStack(spacing: 16) {
                    Text("Photo Access Required")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("LegacyLense needs access to your photo library to restore and enhance your images")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(Color.adaptiveGreen)
                        Text("Photos are processed securely on your device")
                            .font(.subheadline)
                    }
                    
                    HStack(spacing: 16) {
                        Image(systemName: "icloud.slash.fill")
                            .foregroundColor(Color.adaptiveGreen)
                        Text("No photos are uploaded without your permission")
                            .font(.subheadline)
                    }
                    
                    HStack(spacing: 16) {
                        Image(systemName: "trash.slash.fill")
                            .foregroundColor(.red)
                        Text("Original photos are never deleted or modified")
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: {
                        requestPhotoPermission()
                    }) {
                        Text("Grant Photo Access")
                            .font(.headline)
                            .foregroundColor(Color.adaptiveText)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.adaptiveGreen)
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        onComplete()
                    }) {
                        Text("Continue Without Photos")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
            .navigationTitle("Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Skip") { onComplete() })
        }
    }
    
    private func requestPhotoPermission() {
        // In a real implementation, this would request photo library permission
        // For now, we'll simulate it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            photoPermissionStatus = .granted
            onComplete()
        }
    }
}

#Preview {
    OnboardingView()
}