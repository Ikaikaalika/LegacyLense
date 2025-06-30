//
//  LegacyLenseApp.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI
import StoreKit

@main
struct LegacyLenseApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var deviceCapabilityManager = DeviceCapabilityManager()
    @StateObject private var photoRestorationViewModel = PhotoRestorationViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(subscriptionManager)
                .environmentObject(deviceCapabilityManager)
                .environmentObject(photoRestorationViewModel)
                .task {
                    await subscriptionManager.loadProducts()
                    await subscriptionManager.checkSubscriptionStatus()
                }
        }
    }
}
