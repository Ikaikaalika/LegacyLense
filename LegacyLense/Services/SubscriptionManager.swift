//
//  SubscriptionManager.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import Foundation
import StoreKit
import Combine

@MainActor
class SubscriptionManager: NSObject, ObservableObject {
    @Published var products: [Product] = []
    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published var activeSubscription: Product?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var remainingProcessingCredits: Int = 0
    @Published var subscriptionExpiration: Date?
    @Published var isInTrialPeriod: Bool = false
    @Published var trialExpirationDate: Date?
    
    private var updateListenerTask: Task<Void, Error>?
    private let productIds = [
        "com.legacylense.basic_monthly",
        "com.legacylense.premium_monthly",
        "com.legacylense.pro_monthly",
        "com.legacylense.pro_yearly",
        "com.legacylense.credits_10",
        "com.legacylense.credits_50",
        "com.legacylense.credits_100"
    ]
    
    enum SubscriptionStatus {
        case notSubscribed
        case freeTrial
        case basic
        case premium  // $7.99 - removes watermark
        case pro
        case expired
        case processing
    }
    
    enum ProductType {
        case subscription
        case credits
        
        static func from(productId: String) -> ProductType {
            if productId.contains("credits") {
                return .credits
            } else {
                return .subscription
            }
        }
    }
    
    override init() {
        super.init()
        updateListenerTask = listenForTransactions()
        loadCachedSubscriptionStatus()
        checkTrialStatus()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let storeProducts = try await Product.products(for: productIds)
            self.products = storeProducts.sorted { product1, product2 in
                // Sort by price ascending
                return product1.price < product2.price
            }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func checkSubscriptionStatus() async {
        isLoading = true
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if transaction.productType == .autoRenewable {
                await handleSubscriptionTransaction(transaction)
            } else if transaction.productType == .consumable {
                await handleCreditsTransaction(transaction)
            }
        }
        
        checkTrialStatus()
        isLoading = false
    }
    
    // MARK: - Free Trial Management
    
    func startFreeTrial() {
        guard !hasStartedTrial() && subscriptionStatus == .notSubscribed else {
            return
        }
        
        let trialDuration: TimeInterval = 7 * 24 * 60 * 60 // 7 days
        let trialEnd = Date().addingTimeInterval(trialDuration)
        
        trialExpirationDate = trialEnd
        isInTrialPeriod = true
        subscriptionStatus = .freeTrial
        
        // Save trial start date
        UserDefaults.standard.set(Date(), forKey: "trial_start_date")
        UserDefaults.standard.set(trialEnd, forKey: "trial_expiration_date")
        UserDefaults.standard.set(true, forKey: "has_started_trial")
        
        saveSubscriptionStatus()
    }
    
    func checkTrialStatus() {
        guard let trialEnd = UserDefaults.standard.object(forKey: "trial_expiration_date") as? Date else {
            isInTrialPeriod = false
            return
        }
        
        trialExpirationDate = trialEnd
        
        if Date() < trialEnd && subscriptionStatus == .freeTrial {
            isInTrialPeriod = true
        } else if Date() >= trialEnd && subscriptionStatus == .freeTrial {
            // Trial expired
            isInTrialPeriod = false
            subscriptionStatus = .expired
            saveSubscriptionStatus()
        }
    }
    
    func hasStartedTrial() -> Bool {
        return UserDefaults.standard.bool(forKey: "has_started_trial")
    }
    
    func remainingTrialDays() -> Int {
        guard let trialEnd = trialExpirationDate, isInTrialPeriod else {
            return 0
        }
        
        let remaining = trialEnd.timeIntervalSinceNow
        return max(0, Int(remaining / (24 * 60 * 60)))
    }
    
    private func handleSubscriptionTransaction(_ transaction: Transaction) async {
        guard let product = products.first(where: { $0.id == transaction.productID }) else {
            return
        }
        
        activeSubscription = product
        subscriptionExpiration = transaction.expirationDate
        
        if let expirationDate = transaction.expirationDate {
            if expirationDate > Date() {
                subscriptionStatus = determineSubscriptionTier(from: product.id)
            } else {
                subscriptionStatus = .expired
                activeSubscription = nil
            }
        } else {
            subscriptionStatus = determineSubscriptionTier(from: product.id)
        }
        
        saveSubscriptionStatus()
    }
    
    private func handleCreditsTransaction(_ transaction: Transaction) async {
        let credits = creditsFromProductId(transaction.productID)
        remainingProcessingCredits += credits
        saveCreditsBalance()
    }
    
    private func determineSubscriptionTier(from productId: String) -> SubscriptionStatus {
        if productId.contains("basic") {
            return .basic
        } else if productId.contains("premium") {
            return .premium
        } else if productId.contains("pro") {
            return .pro
        } else {
            return .notSubscribed
        }
    }
    
    private func creditsFromProductId(_ productId: String) -> Int {
        switch productId {
        case "com.legacylense.credits_10":
            return 10
        case "com.legacylense.credits_50":
            return 50
        case "com.legacylense.credits_100":
            return 100
        default:
            return 0
        }
    }
    
    func purchase(_ product: Product) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    if product.type == .autoRenewable {
                        await handleSubscriptionTransaction(transaction)
                    } else if product.type == .consumable {
                        await handleCreditsTransaction(transaction)
                    }
                    await transaction.finish()
                    
                case .unverified:
                    throw SubscriptionError.transactionNotVerified
                }
                
            case .userCancelled:
                throw SubscriptionError.userCancelled
                
            case .pending:
                subscriptionStatus = .processing
                
            @unknown default:
                throw SubscriptionError.unknownError
            }
            
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
        
        isLoading = false
    }
    
    func restorePurchases() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            throw error
        }
        
        isLoading = false
    }
    
    func cancelSubscription() async throws {
        guard activeSubscription != nil else {
            throw SubscriptionError.noActiveSubscription
        }
        
        // Direct user to App Store subscription management
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            await UIApplication.shared.open(url)
        }
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else {
                    continue
                }
                
                if let self = self {
                    Task { @MainActor in
                        if transaction.productType == .autoRenewable {
                            await self.handleSubscriptionTransaction(transaction)
                        } else if transaction.productType == .consumable {
                            await self.handleCreditsTransaction(transaction)
                        }
                    }
                }
                
                await transaction.finish()
            }
        }
    }
    
    // MARK: - Usage Tracking
    
    func canProcessPhoto() -> Bool {
        switch subscriptionStatus {
        case .basic, .premium, .pro, .freeTrial:
            return true
        case .notSubscribed, .expired:
            return remainingProcessingCredits > 0
        case .processing:
            return false
        }
    }
    
    func processPhoto() {
        switch subscriptionStatus {
        case .basic, .premium, .pro, .freeTrial:
            // Unlimited processing for subscribers and trial users
            break
        case .notSubscribed, .expired:
            if remainingProcessingCredits > 0 {
                remainingProcessingCredits -= 1
                saveCreditsBalance()
            }
        case .processing:
            break
        }
    }
    
    func hasCloudProcessingAccess() -> Bool {
        switch subscriptionStatus {
        case .basic, .premium, .pro, .freeTrial:
            return true
        case .notSubscribed, .expired, .processing:
            return false
        }
    }
    
    // New function to check if watermark should be removed
    func hasWatermarkRemoval() -> Bool {
        switch subscriptionStatus {
        case .premium, .pro:
            return true
        case .notSubscribed, .freeTrial, .basic, .expired, .processing:
            return false
        }
    }
    
    func getProcessingLimits() -> ProcessingLimits {
        switch subscriptionStatus {
        case .freeTrial:
            return ProcessingLimits(
                dailyLimit: 25, // Limited trial
                cloudProcessing: true,
                onDeviceProcessing: true,
                priorityQueue: false,
                maxImageSize: 4096
            )
        case .basic:
            return ProcessingLimits(
                dailyLimit: 50,
                cloudProcessing: true,
                onDeviceProcessing: true,
                priorityQueue: false,
                maxImageSize: 4096
            )
        case .premium:
            return ProcessingLimits(
                dailyLimit: nil, // Unlimited
                cloudProcessing: true,
                onDeviceProcessing: true,
                priorityQueue: false,
                maxImageSize: 4096
            )
        case .pro:
            return ProcessingLimits(
                dailyLimit: nil, // Unlimited
                cloudProcessing: true,
                onDeviceProcessing: true,
                priorityQueue: true,
                maxImageSize: 8192
            )
        case .notSubscribed, .expired:
            return ProcessingLimits(
                dailyLimit: 3,
                cloudProcessing: false,
                onDeviceProcessing: true,
                priorityQueue: false,
                maxImageSize: 2048
            )
        case .processing:
            return ProcessingLimits(
                dailyLimit: 0,
                cloudProcessing: false,
                onDeviceProcessing: false,
                priorityQueue: false,
                maxImageSize: 0
            )
        }
    }
    
    // MARK: - Persistence
    
    private func saveSubscriptionStatus() {
        UserDefaults.standard.set(subscriptionStatus.rawValue, forKey: "subscription_status")
        if let expiration = subscriptionExpiration {
            UserDefaults.standard.set(expiration, forKey: "subscription_expiration")
        }
        if let subscription = activeSubscription {
            UserDefaults.standard.set(subscription.id, forKey: "active_subscription_id")
        }
    }
    
    private func saveCreditsBalance() {
        UserDefaults.standard.set(remainingProcessingCredits, forKey: "processing_credits")
    }
    
    private func loadCachedSubscriptionStatus() {
        if let statusRaw = UserDefaults.standard.object(forKey: "subscription_status") as? String,
           let status = SubscriptionStatus(rawValue: statusRaw) {
            subscriptionStatus = status
        }
        
        subscriptionExpiration = UserDefaults.standard.object(forKey: "subscription_expiration") as? Date
        remainingProcessingCredits = UserDefaults.standard.integer(forKey: "processing_credits")
        
        if UserDefaults.standard.string(forKey: "active_subscription_id") != nil {
            // Will be populated when products are loaded
        }
    }
    
    // MARK: - Product Information
    
    func getSubscriptionProducts() -> [Product] {
        return products.filter { ProductType.from(productId: $0.id) == .subscription }
    }
    
    func getCreditProducts() -> [Product] {
        return products.filter { ProductType.from(productId: $0.id) == .credits }
    }
    
    func formatPrice(for product: Product) -> String {
        return product.displayPrice
    }
    
    func getSubscriptionBenefits(for productId: String) -> [String] {
        switch productId {
        case "com.legacylense.basic_monthly":
            return [
                "50 photos per day",
                "Cloud processing",
                "On-device processing",
                "Standard quality",
                "Watermark included"
            ]
        case "com.legacylense.premium_monthly":
            return [
                "Unlimited photos",
                "Cloud processing",
                "On-device processing",
                "High quality",
                "No watermark"
            ]
        case "com.legacylense.pro_monthly", "com.legacylense.pro_yearly":
            return [
                "Unlimited photos",
                "Priority cloud processing",
                "On-device processing",
                "Maximum quality",
                "No watermark",
                "Batch processing",
                "Export to various formats"
            ]
        default:
            return []
        }
    }
}

// MARK: - Extensions

extension SubscriptionManager.SubscriptionStatus {
    var rawValue: String {
        switch self {
        case .notSubscribed: return "not_subscribed"
        case .freeTrial: return "free_trial"
        case .basic: return "basic"
        case .premium: return "premium"
        case .pro: return "pro"
        case .expired: return "expired"
        case .processing: return "processing"
        }
    }
    
    init?(rawValue: String) {
        switch rawValue {
        case "not_subscribed": self = .notSubscribed
        case "free_trial": self = .freeTrial
        case "basic": self = .basic
        case "premium": self = .premium
        case "pro": self = .pro
        case "expired": self = .expired
        case "processing": self = .processing
        default: return nil
        }
    }
}

struct ProcessingLimits {
    let dailyLimit: Int? // nil means unlimited
    let cloudProcessing: Bool
    let onDeviceProcessing: Bool
    let priorityQueue: Bool
    let maxImageSize: Int // in pixels (width or height)
}

enum SubscriptionError: LocalizedError {
    case transactionNotVerified
    case userCancelled
    case noActiveSubscription
    case unknownError
    case insufficientCredits
    case subscriptionExpired
    
    var errorDescription: String? {
        switch self {
        case .transactionNotVerified:
            return "Transaction could not be verified"
        case .userCancelled:
            return "Purchase was cancelled"
        case .noActiveSubscription:
            return "No active subscription found"
        case .unknownError:
            return "An unknown error occurred"
        case .insufficientCredits:
            return "Insufficient processing credits"
        case .subscriptionExpired:
            return "Subscription has expired"
        }
    }
}