//
//  PremiumUIComponents.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI
import UIKit

// MARK: - Premium Action Button
struct PremiumActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: color.opacity(0.4), radius: 12, y: 6)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Premium Secondary Button
struct PremiumSecondaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(_ title: String, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Premium Photo Comparison View
struct PremiumPhotoComparisonView: View {
    let originalImage: UIImage
    let restoredImage: UIImage
    @Binding var sliderValue: Double
    
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background original image
                Image(uiImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipped()
                
                // Overlay restored image with mask
                Image(uiImage: restoredImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipped()
                    .mask(
                        Rectangle()
                            .frame(width: geometry.size.width * CGFloat(sliderValue))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )
                
                // Slider line with premium styling
                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 3)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: geometry.size.width * CGFloat(sliderValue) - geometry.size.width * 0.5)
                
                // Slider handle
                Circle()
                    .fill(.white)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(.gray.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 4)
                    .offset(x: geometry.size.width * CGFloat(sliderValue) - geometry.size.width * 0.5)
                
                // Labels
                HStack {
                    VStack {
                        Text("BEFORE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(sliderValue < 0.9 ? 1 : 0)
                    
                    Spacer()
                    
                    VStack {
                        Text("AFTER")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .opacity(sliderValue > 0.1 ? 1 : 0)
                }
                .padding(12)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newValue = Double(value.location.x / geometry.size.width)
                        sliderValue = max(0, min(1, newValue))
                    }
            )
        }
    }
}

// MARK: - Premium Processing Status View
struct PremiumProcessingStatusView: View {
    let stage: String
    let progress: Double
    
    @State private var animateProgress = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Animated processing icon
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .trim(from: 0, to: animateProgress ? 1 : 0)
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: animateProgress)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(stage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("\(Int(progress * 100))% complete")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
            
            // Premium progress bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.1))
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: CGFloat(progress) * 200, height: 6)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
            .frame(maxWidth: 200)
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
        .onAppear {
            animateProgress = true
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var animateGradient = false
    
    private let pages = [
        OnboardingPage(
            title: "Restore Your Memories",
            subtitle: "Transform old, damaged photos into crystal-clear memories with AI",
            icon: "photo.artframe",
            color: .purple
        ),
        OnboardingPage(
            title: "Intelligent Processing",
            subtitle: "Our AI detects and repairs scratches, enhances colors, and improves quality",
            icon: "brain.head.profile",
            color: .blue
        ),
        OnboardingPage(
            title: "Before & After",
            subtitle: "See the transformation with our interactive comparison slider",
            icon: "slider.horizontal.below.rectangle",
            color: .green
        )
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Premium background
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.2, green: 0.1, blue: 0.3),
                        Color(red: 0.1, green: 0.15, blue: 0.25)
                    ],
                    startPoint: animateGradient ? .topLeading : .bottomTrailing,
                    endPoint: animateGradient ? .bottomTrailing : .topLeading
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: animateGradient)
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Page content
                    OnboardingPageView(page: pages[currentPage])
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentPage)
                    
                    Spacer()
                    
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? .white : .white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentPage ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    
                    // Navigation buttons
                    HStack {
                        if currentPage > 0 {
                            Button("Back") {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Button(currentPage == pages.count - 1 ? "Get Started" : "Next") {
                            if currentPage == pages.count - 1 {
                                UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                                dismiss()
                            } else {
                                withAnimation {
                                    currentPage += 1
                                }
                            }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon with glow effect
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [page.color.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)
                
                Image(systemName: page.icon)
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, page.color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: page.color.opacity(0.5), radius: 20)
            }
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, page.color.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.horizontal, 32)
        }
    }
}