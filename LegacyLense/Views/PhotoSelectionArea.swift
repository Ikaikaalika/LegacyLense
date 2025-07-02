//
//  PhotoSelectionArea.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI
import PhotosUI

struct PhotoSelectionArea: View {
    let onPhotoSelected: (UIImage) -> Void
    let onCameraSelected: () -> Void
    let onLibrarySelected: () -> Void
    
    @State private var isDragOver = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Drop zone
            dropZoneView
            
            // Or divider
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.secondary.opacity(0.3))
                
                Text("or")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.secondary.opacity(0.3))
            }
            
            // Action buttons
            actionButtons
            
            // Tips
            tipsView
        }
        .padding()
    }
    
    private var dropZoneView: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                isDragOver ? Color.accentColor : Color.secondary.opacity(0.3),
                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDragOver ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
            )
            .frame(height: 200)
            .overlay {
                VStack(spacing: 16) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(isDragOver ? .accentColor : .secondary)
                    
                    VStack(spacing: 4) {
                        Text("Drop your photo here")
                            .font(.headline)
                            .foregroundColor(isDragOver ? .accentColor : .primary)
                        
                        Text("Drag and drop an old family photo to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .onDrop(of: [.image], isTargeted: $isDragOver) { providers in
                handleDrop(providers)
            }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Photo library button
            Button(action: onLibrarySelected) {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 24))
                    Text("Photo Library")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.accentColor.opacity(0.1))
                .foregroundColor(.accentColor)
                .cornerRadius(12)
            }
            
            // Camera button
            Button(action: onCameraSelected) {
                VStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.system(size: 24))
                    Text("Camera")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.secondary.opacity(0.1))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
        }
    }
    
    private var tipsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.orange)
                Text("Tips for best results:")
                    .font(.subheadline)
                    
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                tipRow(icon: "checkmark.circle", text: "Use high-resolution scans or photos")
                tipRow(icon: "checkmark.circle", text: "Ensure good lighting and focus")
                tipRow(icon: "checkmark.circle", text: "JPEG, PNG, and HEIC formats supported")
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color.adaptiveGreen)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { image, error in
                DispatchQueue.main.async {
                    if let uiImage = image as? UIImage {
                        onPhotoSelected(uiImage)
                    }
                }
            }
            return true
        }
        
        return false
    }
}

#Preview {
    PhotoSelectionArea(
        onPhotoSelected: { _ in },
        onCameraSelected: { },
        onLibrarySelected: { }
    )
    .padding()
}