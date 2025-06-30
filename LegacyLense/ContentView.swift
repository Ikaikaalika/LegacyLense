//
//  ContentView.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        CompatibilityContentView()
    }
}

#Preview {
    ContentView()
        .environmentObject(PhotoRestorationViewModel())
        .environmentObject(SubscriptionManager())
        .environmentObject(DeviceCapabilityManager())
}
