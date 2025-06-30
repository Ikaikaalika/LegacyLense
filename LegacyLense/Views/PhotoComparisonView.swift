//
//  PhotoComparisonView.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI

struct PhotoComparisonView: View {
    let originalImage: UIImage
    let restoredImage: UIImage
    @Binding var sliderValue: Double
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background (restored image)
                Image(uiImage: restoredImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipped()
                
                // Overlay (original image) - masked by slider position
                Image(uiImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipped()
                    .mask(
                        Rectangle()
                            .offset(x: -geometry.size.width * CGFloat(1 - sliderValue))
                    )
                
                // Slider line
                Rectangle()
                    .frame(width: 3)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 0)
                    .position(
                        x: geometry.size.width * CGFloat(sliderValue),
                        y: geometry.size.height / 2
                    )
                
                // Slider handle
                sliderHandle
                    .position(
                        x: geometry.size.width * CGFloat(sliderValue),
                        y: geometry.size.height / 2
                    )
                
                // Labels
                imageLabels(geometry: geometry)
            }
            .clipped()
            .cornerRadius(12)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let newValue = value.location.x / geometry.size.width
                        sliderValue = max(0, min(1, Double(newValue)))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .aspectRatio(originalImage.size.width / originalImage.size.height, contentMode: .fit)
    }
    
    private var sliderHandle: some View {
        Circle()
            .frame(width: 40, height: 40)
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
            )
            .scaleEffect(isDragging ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isDragging)
    }
    
    private func imageLabels(geometry: GeometryProxy) -> some View {
        VStack {
            HStack {
                // Original label
                Text("Original")
                    .font(.caption)
                    
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .opacity(sliderValue < 0.8 ? 1 : 0)
                
                Spacer()
                
                // Restored label
                Text("Restored")
                    .font(.caption)
                    
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .opacity(sliderValue > 0.2 ? 1 : 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Spacer()
            
            // Slider value indicator
            HStack {
                Spacer()
                
                Text("\(Int(sliderValue * 100))% Restored")
                    .font(.caption2)
                    
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)
                    .opacity(isDragging ? 1 : 0)
                
                Spacer()
            }
            .padding(.bottom, 16)
        }
        .animation(.easeInOut(duration: 0.2), value: sliderValue)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
    }
}

#Preview {
    PhotoComparisonView(
        originalImage: UIImage(systemName: "photo")!,
        restoredImage: UIImage(systemName: "photo.fill")!,
        sliderValue: .constant(0.5)
    )
    .frame(height: 300)
    .padding()
}