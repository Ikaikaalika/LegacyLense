//
//  StoreKitExtensions.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import Foundation
import StoreKit

extension Product.SubscriptionPeriod.Unit {
    var localizedDescription: String {
        switch self {
        case .day:
            return "day"
        case .week:
            return "week"
        case .month:
            return "month"
        case .year:
            return "year"
        @unknown default:
            return "period"
        }
    }
}

extension Product.SubscriptionPeriod {
    var localizedDescription: String {
        let unitString = unit.localizedDescription
        if value == 1 {
            return unitString
        } else {
            return "\(value) \(unitString)s"
        }
    }
}