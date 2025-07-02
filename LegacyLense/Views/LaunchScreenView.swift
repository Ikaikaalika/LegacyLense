//
//  LaunchScreenView.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var animateGradient = false
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Adaptive gradient background
            Color.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateGradient)
            
            VStack(spacing: 24) {
                // Adaptive logo with glow effect
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.adaptiveGreen.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)
                        .opacity(logoOpacity)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: colorScheme == .dark ?
                                    [Color(red: 0.9, green: 1.0, blue: 0.9), Color(red: 0.6, green: 0.9, blue: 0.6)] :
                                    [Color.adaptiveGreen, Color(red: 0.2, green: 0.5, blue: 0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.adaptiveGreen.opacity(0.5), radius: 20)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                }
                
                // App name with adaptive styling
                VStack(spacing: 8) {
                    Text("LegacyLense")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: colorScheme == .dark ?
                                    [Color(red: 0.7, green: 0.9, blue: 0.7), Color(red: 0.5, green: 0.8, blue: 0.5)] :
                                    [Color.adaptiveText, Color.adaptiveText],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(textOpacity)
                    
                    Text("AI-Powered Photo Restoration")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.adaptiveText.opacity(0.8))
                        .opacity(textOpacity)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
            
            withAnimation(.spring(response: 1.2, dampingFraction: 0.6).delay(0.3)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            
            withAnimation(.easeInOut(duration: 0.8).delay(0.8)) {
                textOpacity = 1.0
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}