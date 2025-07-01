//
//  LegacyLenseUITests.swift
//  LegacyLenseUITests
//
//  Created by Tyler Gee on 6/12/25.
//

import XCTest

final class LegacyLenseUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testAppLaunchAndMainInterface() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Verify main interface elements are present
        XCTAssertTrue(app.buttons["Select Photo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["LegacyLense"].exists)
    }
    
    @MainActor
    func testPhotoSelectionFlow() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test photo selection button exists and is tappable
        let selectPhotoButton = app.buttons["Select Photo"]
        XCTAssertTrue(selectPhotoButton.waitForExistence(timeout: 5))
        XCTAssertTrue(selectPhotoButton.isEnabled)
    }
    
    @MainActor
    func testSubscriptionUIElements() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Look for subscription-related UI elements
        if app.buttons["Upgrade to Pro"].exists {
            XCTAssertTrue(app.buttons["Upgrade to Pro"].isEnabled)
        }
    }
    
    @MainActor
    func testProcessingSettingsAccess() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test that settings can be accessed
        if app.buttons["Settings"].exists {
            app.buttons["Settings"].tap()
            // Verify settings interface appears
            XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 3))
        }
    }
    
    @MainActor
    func testNavigationFlow() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test basic navigation doesn't crash
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            let buttons = tabBar.buttons
            for i in 0..<min(buttons.count, 3) {
                buttons.element(boundBy: i).tap()
                // Small delay to allow UI to update
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    @MainActor
    func testMemoryPerformance() throws {
        let app = XCUIApplication()
        
        measure(metrics: [XCTMemoryMetric()]) {
            app.launch()
            
            // Perform some basic interactions
            if app.buttons["Select Photo"].exists {
                // Simulate user interaction without actually selecting photos
                app.buttons["Select Photo"].tap()
                
                // Wait a moment then dismiss any photo picker
                Thread.sleep(forTimeInterval: 1.0)
                
                // Try to dismiss photo picker if it appeared
                if app.buttons["Cancel"].exists {
                    app.buttons["Cancel"].tap()
                }
            }
            
            app.terminate()
        }
    }
    
    @MainActor
    func testUIResponsiveness() throws {
        let app = XCUIApplication()
        app.launch()
        
        measure(metrics: [XCTCPUMetric()]) {
            // Test UI responsiveness by rapid interactions
            for _ in 0..<10 {
                if app.buttons["Select Photo"].exists {
                    app.buttons["Select Photo"].tap()
                    if app.buttons["Cancel"].exists {
                        app.buttons["Cancel"].tap()
                    }
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
}
