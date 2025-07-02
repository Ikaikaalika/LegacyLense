//
//  LegalDocumentView.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI

struct LegalDocumentView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss
    
    enum LegalDocument: String, CaseIterable {
        case privacyPolicy = "Privacy Policy"
        case termsOfService = "Terms of Service"
        
        var fileName: String {
            switch self {
            case .privacyPolicy:
                return "PrivacyPolicy"
            case .termsOfService:
                return "TermsOfService"
            }
        }
        
        var title: String {
            return self.rawValue
        }
    }
    
    @State private var documentContent: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if let errorMessage = errorMessage {
                    errorView(errorMessage)
                } else {
                    contentView
                }
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadDocument()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading \(document.title)...")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Unable to Load Document")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                loadDocument()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(attributedContent)
                    .font(.system(size: 14, weight: .regular))
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
        }
    }
    
    private var attributedContent: AttributedString {
        var attributedString = AttributedString(documentContent)
        
        // Apply basic styling for markdown-like formatting
        // Style headers (lines starting with #)
        let lines = documentContent.components(separatedBy: .newlines)
        
        for line in lines {
            if line.hasPrefix("# ") {
                // Main header
                if let range = attributedString.range(of: line) {
                    attributedString[range].font = .system(size: 24, weight: .bold)
                    attributedString[range].foregroundColor = .primary
                }
            } else if line.hasPrefix("## ") {
                // Section header
                if let range = attributedString.range(of: line) {
                    attributedString[range].font = .system(size: 20, weight: .semibold)
                    attributedString[range].foregroundColor = .primary
                }
            } else if line.hasPrefix("### ") {
                // Subsection header
                if let range = attributedString.range(of: line) {
                    attributedString[range].font = .system(size: 18, weight: .medium)
                    attributedString[range].foregroundColor = .primary
                }
            } else if line.hasPrefix("**") && line.hasSuffix("**") && line.count > 4 {
                // Bold text
                if let range = attributedString.range(of: line) {
                    attributedString[range].font = .system(size: 14, weight: .semibold)
                }
            }
        }
        
        return attributedString
    }
    
    private func loadDocument() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let content = try await loadDocumentContent()
                await MainActor.run {
                    self.documentContent = content
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadDocumentContent() async throws -> String {
        // First try to load from bundle
        if let bundlePath = Bundle.main.path(forResource: document.fileName, ofType: "md"),
           let content = try? String(contentsOfFile: bundlePath) {
            return content
        }
        
        // If not found in bundle, return fallback content
        return getFallbackContent()
    }
    
    private func getFallbackContent() -> String {
        switch document {
        case .privacyPolicy:
            return """
            # Privacy Policy for LegacyLense
            
            **Effective Date:** January 1, 2025
            
            ## Information We Collect
            
            We collect information you provide directly to us, such as when you:
            - Upload photos for processing
            - Create an account
            - Contact our support team
            - Purchase subscriptions
            
            ## How We Use Your Information
            
            We use your information to:
            - Process and enhance your photos
            - Provide customer support
            - Improve our services
            - Process payments
            
            ## Data Security
            
            We implement appropriate security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.
            
            ## Your Rights
            
            You have the right to:
            - Access your personal information
            - Correct inaccurate information
            - Delete your personal information
            - Opt-out of certain data collection
            
            ## Contact Us
            
            If you have questions about this Privacy Policy, please contact us at privacy@legacylense.app.
            """
            
        case .termsOfService:
            return """
            # Terms of Service for LegacyLense
            
            **Effective Date:** January 1, 2025
            
            ## Agreement to Terms
            
            By using LegacyLense, you agree to these Terms of Service.
            
            ## Description of Service
            
            LegacyLense provides AI-powered photo restoration and enhancement services.
            
            ## User Responsibilities
            
            You are responsible for:
            - Maintaining account security
            - Using the service lawfully
            - Respecting intellectual property rights
            
            ## Subscription Terms
            
            - Subscriptions renew automatically
            - Cancellations must be made through the App Store
            - Refunds are subject to Apple's policies
            
            ## Limitations of Liability
            
            Our liability is limited to the maximum extent permitted by law.
            
            ## Contact Us
            
            For questions about these Terms, contact us at legal@legacylense.app.
            """
        }
    }
}

// MARK: - Preview

#Preview {
    LegalDocumentView(document: .privacyPolicy)
}