//
//  PremiumUIComponents.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI

// MARK: - Premium Action Button
struct PremiumActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.4), lineWidth: 1)
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.adaptiveText)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3), value: color)
    }
}

// MARK: - Premium Secondary Button
struct PremiumSecondaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(Color.adaptiveText)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Premium Photo Comparison View
struct PremiumPhotoComparisonView: View {
    let originalImage: UIImage
    let restoredImage: UIImage
    @Binding var sliderValue: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Restored image (background)
                Image(uiImage: restoredImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Original image (masked)
                Image(uiImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .mask(
                        Rectangle()
                            .frame(width: geometry.size.width * sliderValue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )
                
                // Divider line
                Rectangle()
                    .fill(.white)
                    .frame(width: 2)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .position(x: geometry.size.width * sliderValue, y: geometry.size.height / 2)
                
                // Slider handle
                Circle()
                    .fill(.white)
                    .frame(width: 32, height: 32)
                    .shadow(color: .black.opacity(0.2), radius: 4)
                    .overlay(
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                    )
                    .position(x: geometry.size.width * sliderValue, y: geometry.size.height / 2)
                
                // Labels
                HStack {
                    VStack {
                        Text("Original")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                    
                    Spacer()
                    
                    VStack {
                        Text("Enhanced")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 12)
                }
                .padding(.top, 12)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newValue = value.location.x / geometry.size.width
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
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress indicator
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.adaptiveGreen, Color.adaptiveGreen.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.adaptiveGreen)
                    .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 3) * 0.1)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: UUID())
            }
            
            VStack(spacing: 4) {
                Text(stage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.adaptiveText)
                    .multilineTextAlignment(.center)
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.adaptiveText.opacity(0.8))
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
}


// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            PremiumActionButton(
                icon: "camera.fill",
                title: "Camera",
                color: Color.adaptiveGreen,
                colorScheme: .light
            ) {
                print("Camera tapped")
            }
            
            PremiumActionButton(
                icon: "photo.on.rectangle",
                title: "Library",
                color: Color.adaptiveGreen.opacity(0.8),
                colorScheme: .light
            ) {
                print("Library tapped")
            }
        }
        
        HStack(spacing: 12) {
            PremiumSecondaryButton(title: "New Photo", icon: "plus.circle") {
                print("New photo tapped")
            }
            
            PremiumSecondaryButton(title: "Save", icon: "square.and.arrow.down") {
                print("Save tapped")
            }
        }
        
        PremiumProcessingStatusView(
            stage: "Enhancing photo quality",
            progress: 0.7
        )
    }
    .padding()
    .background(Color.adaptiveBackground)
}