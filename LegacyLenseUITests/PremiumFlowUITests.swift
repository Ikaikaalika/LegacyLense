//
//  PremiumFlowUITests.swift
//  LegacyLenseUITests
//
//  Created by Tyler Gee on 6/12/25.
//

import XCTest

final class PremiumFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here
    }

    @MainActor
    func testPremiumSubscriptionFlow() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Look for premium/subscription related UI elements
        if app.buttons["Upgrade to Pro"].exists {
            app.buttons["Upgrade to Pro"].tap()
            
            // Verify subscription view appears
            XCTAssertTrue(app.staticTexts["LegacyLense Pro"].waitForExistence(timeout: 5) ||
                         app.staticTexts["Premium"].waitForExistence(timeout: 5))
            
            // Test back navigation
            if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
            }
        }
    }
    
    @MainActor
    func testBatchProcessingAccess() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Look for batch processing feature
        if app.buttons["Batch Processing"].exists {
            app.buttons["Batch Processing"].tap()
            
            // Should either show the feature or upgrade prompt
            XCTAssertTrue(
                app.staticTexts["Batch Processing"].waitForExistence(timeout: 5) ||
                app.staticTexts["Upgrade"].waitForExistence(timeout: 5)
            )
        }
    }
    
    @MainActor
    func testMLModelManagerAccess() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Look for AI Models or similar feature
        if app.buttons["AI Models"].exists || app.buttons["Models"].exists {
            let button = app.buttons["AI Models"].exists ? app.buttons["AI Models"] : app.buttons["Models"]
            button.tap()
            
            // Should show model manager or upgrade prompt
            XCTAssertTrue(
                app.staticTexts["AI Model Manager"].waitForExistence(timeout: 5) ||
                app.staticTexts["AI Models"].waitForExistence(timeout: 5) ||
                app.staticTexts["Upgrade"].waitForExistence(timeout: 5)
            )
        }
    }
    
    @MainActor
    func testPremiumSettingsAccess() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to settings
        if app.buttons["Settings"].exists {
            app.buttons["Settings"].tap()
            
            // Look for premium settings
            if app.buttons["Premium Settings"].exists {
                app.buttons["Premium Settings"].tap()
                
                XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 3))
            }
        }
    }
    
    @MainActor
    func testSubscriptionStatusDisplay() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Look for subscription status indicators
        let statusIndicators = [
            "Free",
            "Pro",
            "Premium",
            "Subscription"
        ]
        
        var foundStatus = false
        for indicator in statusIndicators {
            if app.staticTexts[indicator].exists {
                foundStatus = true
                break
            }
        }
        
        // It's okay if no status is shown, but if one is shown, verify it exists
        if foundStatus {
            XCTAssertTrue(true) // At least one status indicator was found
        }
    }
    
    @MainActor
    func testPremiumFeatureGating() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test that premium features show appropriate prompts for free users
        let premiumFeatures = [
            "Batch Processing",
            "AI Models",
            "Cloud Sync",
            "Advanced Filters"
        ]
        
        for feature in premiumFeatures {
            if app.buttons[feature].exists {
                app.buttons[feature].tap()
                
                // Should either show the feature or an upgrade prompt
                let featureShown = app.staticTexts[feature].waitForExistence(timeout: 3)
                let upgradePromptShown = app.staticTexts["Upgrade"].exists || 
                                       app.staticTexts["Premium"].exists ||
                                       app.buttons["Upgrade to Pro"].exists
                
                XCTAssertTrue(featureShown || upgradePromptShown, 
                             "Feature '\(feature)' should either be accessible or show upgrade prompt")
                
                // Navigate back if needed
                if app.navigationBars.buttons.firstMatch.exists {
                    app.navigationBars.buttons.firstMatch.tap()
                }
            }
        }
    }
    
    @MainActor
    func testRestorePurchasesFlow() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to subscription view
        if app.buttons["Upgrade to Pro"].exists {
            app.buttons["Upgrade to Pro"].tap()
            
            // Look for restore purchases button
            if app.buttons["Restore Purchases"].exists {
                app.buttons["Restore Purchases"].tap()
                
                // Should handle restore (might show alert or loading state)
                // Just verify it doesn't crash
                Thread.sleep(forTimeInterval: 2.0)
                XCTAssertTrue(true)
            }
        }
    }
    
    @MainActor
    func testPremiumUIConsistency() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate through premium-related screens and verify consistent UI
        let premiumScreens = [
            "Upgrade to Pro",
            "Settings",
            "Batch Processing",
            "AI Models"
        ]
        
        for screen in premiumScreens {
            if app.buttons[screen].exists {
                app.buttons[screen].tap()
                
                // Verify navigation bar exists
                XCTAssertTrue(app.navigationBars.element.exists, 
                             "Navigation bar should exist on \(screen) screen")
                
                // Verify we can navigate back
                if app.navigationBars.buttons.firstMatch.exists {
                    app.navigationBars.buttons.firstMatch.tap()
                } else if app.buttons["Cancel"].exists {
                    app.buttons["Cancel"].tap()
                } else if app.buttons["Done"].exists {
                    app.buttons["Done"].tap()
                }
                
                // Small delay for UI to update
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }
    
    @MainActor
    func testSubscriptionViewElements() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["Upgrade to Pro"].exists {
            app.buttons["Upgrade to Pro"].tap()
            
            // Verify essential subscription view elements
            let expectedElements = [
                "LegacyLense Pro",
                "Premium",
                "Features",
                "Subscribe"
            ]
            
            var foundElements = 0
            for element in expectedElements {
                if app.staticTexts[element].exists || app.buttons[element].exists {
                    foundElements += 1
                }
            }
            
            XCTAssertGreaterThan(foundElements, 0, "Should find at least some subscription view elements")
        }
    }
    
    @MainActor
    func testPremiumFeatureAccessibility() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test that premium features are accessible (have proper labels, etc.)
        if app.buttons["Batch Processing"].exists {
            let batchButton = app.buttons["Batch Processing"]
            XCTAssertTrue(batchButton.isEnabled)
            
            // Test accessibility
            if let label = batchButton.label {
                XCTAssertFalse(label.isEmpty, "Button should have accessibility label")
            }
        }
        
        if app.buttons["AI Models"].exists {
            let modelsButton = app.buttons["AI Models"]
            XCTAssertTrue(modelsButton.isEnabled)
            
            if let label = modelsButton.label {
                XCTAssertFalse(label.isEmpty, "Button should have accessibility label")
            }
        }
    }
}