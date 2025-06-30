//
//  SubscriptionView.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        PremiumSubscriptionView()
    }
}

struct LegacySubscriptionView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProduct: Product?
    @State private var showingRestoreAlert = false
    @State private var restoreMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Current Status
                    currentStatusView
                    
                    // Subscription Plans
                    if !subscriptionProducts.isEmpty {
                        subscriptionPlansSection
                    }
                    
                    // Credits
                    if !creditProducts.isEmpty {
                        creditsSection
                    }
                    
                    // Features Comparison
                    featuresComparisonSection
                    
                    // Restore Purchases
                    restoreSection
                }
                .padding()
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    
                }
            }
            .alert("Restore Purchases", isPresented: $showingRestoreAlert) {
                Button("OK") { }
            } message: {
                Text(restoreMessage)
            }
        }
        .task {
            if subscriptionManager.products.isEmpty {
                await subscriptionManager.loadProducts()
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundColor(.yellow)
            
            Text("Unlock Premium Features")
                .font(.title2)
                
            
            Text("Restore unlimited family photos with the power of AI")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var currentStatusView: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Current Plan", systemImage: statusIcon)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(statusText)
                        .font(.caption)
                        
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusBackgroundColor)
                        .foregroundColor(statusForegroundColor)
                        .cornerRadius(12)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    statusInfoRow("Processing Credits", value: "\(subscriptionManager.remainingProcessingCredits)")
                    
                    if let expiration = subscriptionManager.subscriptionExpiration {
                        statusInfoRow("Expires", value: DateFormatter.shortDate.string(from: expiration))
                    }
                    
                    statusInfoRow("Daily Limit", value: getDailyLimitText())
                    statusInfoRow("Cloud Processing", value: getCloudProcessingText())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var subscriptionPlansSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Subscription Plans")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(subscriptionProducts, id: \.id) { product in
                    subscriptionPlanCard(product)
                }
            }
        }
    }
    
    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Processing Credits")
                .font(.headline)
                .padding(.horizontal)
            
            Text("One-time purchases for individual photo restorations")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(creditProducts, id: \.id) { product in
                    creditCard(product)
                }
            }
        }
    }
    
    private var featuresComparisonSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Text("Features Comparison")
                    .font(.headline)
                    .padding(.bottom, 8)
                
                VStack(spacing: 12) {
                    featureComparisonRow("Photo Processing", free: "3 per day", basic: "50 per day", pro: "Unlimited")
                    featureComparisonRow("Cloud Processing", free: "❌", basic: "✅", pro: "✅ Priority")
                    featureComparisonRow("On-Device Processing", free: "✅", basic: "✅", pro: "✅")
                    featureComparisonRow("Batch Processing", free: "❌", basic: "❌", pro: "✅")
                    featureComparisonRow("Export Formats", free: "JPEG", basic: "JPEG, PNG", pro: "All Formats")
                    featureComparisonRow("Maximum Resolution", free: "2K", basic: "4K", pro: "8K")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var restoreSection: some View {
        VStack(spacing: 12) {
            Button("Restore Purchases") {
                Task {
                    do {
                        try await subscriptionManager.restorePurchases()
                        restoreMessage = "Purchases restored successfully"
                        showingRestoreAlert = true
                    } catch {
                        restoreMessage = "Failed to restore purchases: \(error.localizedDescription)"
                        showingRestoreAlert = true
                    }
                }
            }
            .buttonStyle(.bordered)
            
            Text("Previous purchases will be restored to your account")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private func subscriptionPlanCard(_ product: Product) -> some View {
        let isRecommended = product.id.contains("pro_yearly")
        let isCurrentPlan = isCurrentSubscription(product)
        
        return VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(getSubscriptionTitle(product))
                            .font(.headline)
                            
                        
                        if isRecommended {
                            Text("POPULAR")
                                .font(.caption2)
                                
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(subscriptionManager.formatPrice(for: product))
                        .font(.title2)
                        
                        .foregroundColor(.accentColor)
                    
                    if product.id.contains("yearly") {
                        Text("Save 50% with annual billing")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                if isCurrentPlan {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        Text("Current")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                } else {
                    Button("Subscribe") {
                        purchaseProduct(product)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(subscriptionManager.isLoading)
                }
            }
            
            // Benefits
            VStack(alignment: .leading, spacing: 6) {
                ForEach(subscriptionManager.getSubscriptionBenefits(for: product.id), id: \.self) { benefit in
                    HStack {
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(benefit)
                            .font(.subheadline)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRecommended ? Color.orange : Color.secondary.opacity(0.3), lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isRecommended ? Color.orange.opacity(0.05) : Color.clear)
                )
        )
    }
    
    private func creditCard(_ product: Product) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(getCreditTitle(product))
                    .font(.subheadline)
                    
                
                Text(subscriptionManager.formatPrice(for: product))
                    .font(.headline)
                    
                    .foregroundColor(.accentColor)
            }
            
            Spacer()
            
            Button("Purchase") {
                purchaseProduct(product)
            }
            .buttonStyle(.bordered)
            .disabled(subscriptionManager.isLoading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func featureComparisonRow(_ feature: String, free: String, basic: String, pro: String) -> some View {
        HStack {
            Text(feature)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 4) {
                Text("Free")
                    .font(.caption2)
                    
                    .foregroundColor(.secondary)
                Text(free)
                    .font(.caption)
            }
            .frame(width: 60)
            
            VStack(spacing: 4) {
                Text("Basic")
                    .font(.caption2)
                    
                    .foregroundColor(.blue)
                Text(basic)
                    .font(.caption)
            }
            .frame(width: 60)
            
            VStack(spacing: 4) {
                Text("Pro")
                    .font(.caption2)
                    
                    .foregroundColor(.purple)
                Text(pro)
                    .font(.caption)
            }
            .frame(width: 60)
        }
    }
    
    private func statusInfoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                
        }
    }
    
    // MARK: - Computed Properties
    
    private var subscriptionProducts: [Product] {
        subscriptionManager.getSubscriptionProducts()
    }
    
    private var creditProducts: [Product] {
        subscriptionManager.getCreditProducts()
    }
    
    private var statusIcon: String {
        switch subscriptionManager.subscriptionStatus {
        case .pro: return "crown.fill"
        case .basic: return "star.fill"
        case .expired: return "exclamationmark.triangle.fill"
        case .processing: return "clock.fill"
        default: return "person.crop.circle"
        }
    }
    
    private var statusText: String {
        switch subscriptionManager.subscriptionStatus {
        case .pro: return "Pro"
        case .basic: return "Basic"
        case .expired: return "Expired"
        case .processing: return "Processing"
        default: return "Free"
        }
    }
    
    private var statusBackgroundColor: Color {
        switch subscriptionManager.subscriptionStatus {
        case .pro: return .purple
        case .basic: return .blue
        case .expired: return .orange
        case .processing: return .yellow
        default: return Color.secondary.opacity(0.2)
        }
    }
    
    private var statusForegroundColor: Color {
        switch subscriptionManager.subscriptionStatus {
        case .pro, .basic: return .white
        case .expired, .processing: return .black
        default: return .primary
        }
    }
    
    // MARK: - Helper Methods
    
    private func getDailyLimitText() -> String {
        let limits = subscriptionManager.getProcessingLimits()
        return limits.dailyLimit.map { "\($0)" } ?? "Unlimited"
    }
    
    private func getCloudProcessingText() -> String {
        let limits = subscriptionManager.getProcessingLimits()
        if !limits.cloudProcessing {
            return "Not available"
        } else if limits.priorityQueue {
            return "Priority access"
        } else {
            return "Standard access"
        }
    }
    
    private func isCurrentSubscription(_ product: Product) -> Bool {
        return subscriptionManager.activeSubscription?.id == product.id
    }
    
    private func getSubscriptionTitle(_ product: Product) -> String {
        if product.id.contains("basic") {
            return "Basic Plan"
        } else if product.id.contains("pro") {
            return product.id.contains("yearly") ? "Pro Plan (Annual)" : "Pro Plan (Monthly)"
        }
        return product.displayName
    }
    
    private func getCreditTitle(_ product: Product) -> String {
        if product.id.contains("credits_10") {
            return "10 Processing Credits"
        } else if product.id.contains("credits_50") {
            return "50 Processing Credits"
        } else if product.id.contains("credits_100") {
            return "100 Processing Credits"
        }
        return product.displayName
    }
    
    private func purchaseProduct(_ product: Product) {
        Task {
            do {
                try await subscriptionManager.purchase(product)
            } catch {
                // Error is already handled in SubscriptionManager
            }
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

#Preview {
    SubscriptionView()
        .environmentObject(SubscriptionManager())
}