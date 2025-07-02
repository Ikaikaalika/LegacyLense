//
//  ColorTheme.swift
//  LegacyLense
//
//  Created by Tyler Gee on 7/2/25.
//

import SwiftUI

extension Color {
    // MARK: - Primary Green Colors
    static let primaryGreen = Color("PrimaryGreen")
    static let lightGreen = Color("LightGreen")
    static let darkGreen = Color("DarkGreen")
    static let accentGreen = Color("AccentGreen")
    
    // MARK: - Background Colors
    static let backgroundPrimary = Color("BackgroundPrimary")
    static let backgroundSecondary = Color("BackgroundSecondary")
    static let backgroundTertiary = Color("BackgroundTertiary")
    
    // MARK: - Text Colors
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textOnGreen = Color("TextOnGreen")
    
    // MARK: - Surface Colors
    static let surfacePrimary = Color("SurfacePrimary")
    static let surfaceSecondary = Color("SurfaceSecondary")
    
    // MARK: - Static Color Definitions (for when assets aren't available)
    static let fallbackPrimaryGreen = Color.adaptiveGreen
    static let fallbackLightGreen = Color.adaptiveSurface
    static let fallbackDarkGreen = Color(red: 0.2, green: 0.5, blue: 0.2)
    
    // MARK: - Adaptive Colors for Light/Dark Mode
    static let adaptiveBackground: Color = {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.05, green: 0.1, blue: 0.05, alpha: 1.0) // Very dark green
            default:
                return UIColor(red: 0.95, green: 0.98, blue: 0.95, alpha: 1.0) // Very light green
            }
        })
    }()
    
    static let adaptiveText: Color = {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.9, green: 0.95, blue: 0.9, alpha: 1.0) // Light green text
            default:
                return UIColor(red: 0.1, green: 0.2, blue: 0.1, alpha: 1.0) // Dark green text
            }
        })
    }()
    
    static let adaptiveSurface: Color = {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.1, green: 0.15, blue: 0.1, alpha: 1.0) // Dark green surface
            default:
                return UIColor(red: 0.98, green: 1.0, blue: 0.98, alpha: 1.0) // White-green surface
            }
        })
    }()
    
    static let adaptiveGreen: Color = {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0) // Bright green for dark mode
            default:
                return UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0) // Medium green for light mode
            }
        })
    }()
    
    // MARK: - Button Colors
    static let buttonPrimary: Color = adaptiveGreen
    static let buttonSecondary: Color = {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.2, green: 0.3, blue: 0.2, alpha: 1.0)
            default:
                return UIColor(red: 0.85, green: 0.95, blue: 0.85, alpha: 1.0)
            }
        })
    }()
    
    // MARK: - Gradient Colors
    static func backgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        switch colorScheme {
        case .dark:
            return LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.05),
                    Color(red: 0.1, green: 0.15, blue: 0.1),
                    Color(red: 0.08, green: 0.12, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .light:
            return LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.98, blue: 0.95),
                    Color(red: 0.92, green: 0.96, blue: 0.92),
                    Color(red: 0.94, green: 0.97, blue: 0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        @unknown default:
            return LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.98, blue: 0.95),
                    Color(red: 0.92, green: 0.96, blue: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    static func buttonGradient(for colorScheme: ColorScheme) -> LinearGradient {
        switch colorScheme {
        case .dark:
            return LinearGradient(
                colors: [
                    Color.adaptiveGreen,
                    Color.adaptiveGreen
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .light:
            return LinearGradient(
                colors: [
                    Color.adaptiveGreen,
                    Color(red: 0.2, green: 0.6, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        @unknown default:
            return LinearGradient(
                colors: [
                    Color.adaptiveGreen,
                    Color(red: 0.2, green: 0.6, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Theme Environment
struct ThemeEnvironment {
    let colorScheme: ColorScheme
    
    var primaryBackground: Color {
        Color.backgroundGradient(for: colorScheme).stops.first?.color ?? Color.adaptiveBackground
    }
    
    var primaryText: Color {
        Color.adaptiveText
    }
    
    var primarySurface: Color {
        Color.adaptiveSurface
    }
    
    var accentColor: Color {
        Color.adaptiveGreen
    }
}

// MARK: - View Modifier for Consistent Theming
struct GreenThemeModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(Color.backgroundGradient(for: colorScheme))
            .foregroundColor(Color.adaptiveText)
    }
}

extension View {
    func greenTheme() -> some View {
        modifier(GreenThemeModifier())
    }
}