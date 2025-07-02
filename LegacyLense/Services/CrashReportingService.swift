//
//  CrashReportingService.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import Foundation
import UIKit
import OSLog

@MainActor
class CrashReportingService: ObservableObject {
    
    static let shared = CrashReportingService()
    
    @Published var isEnabled = true
    @Published var userId: String?
    @Published var sessionId: String
    
    private let logger = Logger(subsystem: "com.legacylense.app", category: "CrashReporting")
    private var isInitialized = false
    
    // Configuration
    struct Configuration {
        let enableCrashReporting: Bool
        let enablePerformanceMonitoring: Bool
        let enableUserInteractionTracking: Bool
        let sampleRate: Double
        
        static let `default` = Configuration(
            enableCrashReporting: true,
            enablePerformanceMonitoring: true,
            enableUserInteractionTracking: false, // Privacy-focused
            sampleRate: 1.0
        )
    }
    
    private var configuration = Configuration.default
    
    init() {
        self.sessionId = UUID().uuidString
        loadConfiguration()
    }
    
    // MARK: - Initialization
    
    func initialize(configuration: Configuration = .default) {
        guard !isInitialized else {
            logger.warning("CrashReportingService already initialized")
            return
        }
        
        self.configuration = configuration
        
        if configuration.enableCrashReporting && isEnabled {
            setupCrashReporting()
        }
        
        if configuration.enablePerformanceMonitoring && isEnabled {
            setupPerformanceMonitoring()
        }
        
        isInitialized = true
        logger.info("CrashReportingService initialized successfully")
    }
    
    private func setupCrashReporting() {
        // Set up exception handler
        NSSetUncaughtExceptionHandler { exception in
            Task { @MainActor in
                CrashReportingService.shared.handleException(exception)
            }
        }
        
        // Set up signal handler
        signal(SIGABRT) { signal in
            Task { @MainActor in
                CrashReportingService.shared.handleSignal(signal)
            }
        }
        
        signal(SIGILL) { signal in
            Task { @MainActor in
                CrashReportingService.shared.handleSignal(signal)
            }
        }
        
        signal(SIGSEGV) { signal in
            Task { @MainActor in
                CrashReportingService.shared.handleSignal(signal)
            }
        }
        
        signal(SIGFPE) { signal in
            Task { @MainActor in
                CrashReportingService.shared.handleSignal(signal)
            }
        }
        
        signal(SIGBUS) { signal in
            Task { @MainActor in
                CrashReportingService.shared.handleSignal(signal)
            }
        }
        
        logger.info("Crash reporting handlers configured")
    }
    
    private func setupPerformanceMonitoring() {
        // Monitor app lifecycle events
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.trackEvent("app_became_active")
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.trackEvent("app_entered_background")
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.trackEvent("memory_warning_received")
            }
        }
        
        logger.info("Performance monitoring configured")
    }
    
    // MARK: - Configuration Management
    
    private func loadConfiguration() {
        isEnabled = UserDefaults.standard.object(forKey: "crash_reporting_enabled") as? Bool ?? true
        userId = UserDefaults.standard.string(forKey: "crash_reporting_user_id")
    }
    
    func updateConfiguration(enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "crash_reporting_enabled")
        
        if enabled && !isInitialized {
            initialize()
        }
        
        logger.info("Crash reporting enabled: \(enabled)")
    }
    
    func setUserId(_ userId: String?) {
        self.userId = userId
        UserDefaults.standard.set(userId, forKey: "crash_reporting_user_id")
        logger.info("User ID set for crash reporting")
    }
    
    // MARK: - Crash Handling
    
    private func handleException(_ exception: NSException) {
        guard isEnabled else { return }
        
        let crashReport = CrashReport(
            type: .exception,
            name: exception.name.rawValue,
            reason: exception.reason ?? "Unknown reason",
            callStack: exception.callStackSymbols,
            userInfo: gatherUserInfo(),
            timestamp: Date()
        )
        
        saveCrashReport(crashReport)
        logger.error("Exception caught: \(exception.name.rawValue) - \(exception.reason ?? "Unknown")")
    }
    
    private func handleSignal(_ signal: Int32) {
        guard isEnabled else { return }
        
        let signalName = String(cString: strsignal(signal))
        
        let crashReport = CrashReport(
            type: .signal,
            name: "Signal \(signal)",
            reason: signalName,
            callStack: Thread.callStackSymbols,
            userInfo: gatherUserInfo(),
            timestamp: Date()
        )
        
        saveCrashReport(crashReport)
        logger.error("Signal caught: \(signal) - \(signalName)")
    }
    
    // MARK: - Error Tracking
    
    func trackError(_ error: Error, context: [String: Any] = [:]) {
        guard isEnabled else { return }
        
        let errorReport = ErrorReport(
            error: error,
            context: context,
            userInfo: gatherUserInfo(),
            timestamp: Date()
        )
        
        saveErrorReport(errorReport)
        logger.error("Error tracked: \(error.localizedDescription)")
    }
    
    func trackEvent(_ eventName: String, parameters: [String: Any] = [:]) {
        guard isEnabled else { return }
        
        let event = AnalyticsEvent(
            name: eventName,
            parameters: parameters,
            userInfo: gatherUserInfo(),
            timestamp: Date()
        )
        
        saveAnalyticsEvent(event)
        logger.info("Event tracked: \(eventName)")
    }
    
    // MARK: - Performance Monitoring
    
    func startTransaction(_ name: String) -> PerformanceTransaction {
        return PerformanceTransaction(
            name: name,
            startTime: Date(),
            crashReportingService: self
        )
    }
    
    func measurePerformance<T>(_ name: String, operation: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        trackEvent("performance_measurement", parameters: [
            "operation": name,
            "duration_seconds": duration
        ])
        
        return result
    }
    
    func measureAsyncPerformance<T>(_ name: String, operation: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        trackEvent("performance_measurement", parameters: [
            "operation": name,
            "duration_seconds": duration
        ])
        
        return result
    }
    
    // MARK: - User Info Gathering
    
    private func gatherUserInfo() -> [String: Any] {
        var userInfo: [String: Any] = [:]
        
        // App info
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            userInfo["app_version"] = appVersion
        }
        
        if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            userInfo["build_number"] = buildNumber
        }
        
        // Device info
        userInfo["device_model"] = UIDevice.current.model
        userInfo["system_version"] = UIDevice.current.systemVersion
        userInfo["system_name"] = UIDevice.current.systemName
        
        // Memory info
        let memoryInfo = getMemoryInfo()
        userInfo["memory_used"] = memoryInfo.used
        userInfo["memory_total"] = memoryInfo.total
        
        // User info
        if let userId = userId {
            userInfo["user_id"] = userId
        }
        
        userInfo["session_id"] = sessionId
        
        return userInfo
    }
    
    private func getMemoryInfo() -> (used: Int64, total: Int64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return (used: Int64(info.resident_size), total: Int64(ProcessInfo.processInfo.physicalMemory))
        } else {
            return (used: 0, total: 0)
        }
    }
    
    // MARK: - Data Persistence
    
    private func saveCrashReport(_ report: CrashReport) {
        do {
            let data = try JSONEncoder().encode(report)
            let url = getCrashReportsDirectory().appendingPathComponent("\(report.id).json")
            try data.write(to: url)
            logger.info("Crash report saved: \(report.id)")
        } catch {
            logger.error("Failed to save crash report: \(error.localizedDescription)")
        }
    }
    
    private func saveErrorReport(_ report: ErrorReport) {
        do {
            let data = try JSONEncoder().encode(report)
            let url = getErrorReportsDirectory().appendingPathComponent("\(report.id).json")
            try data.write(to: url)
            logger.debug("Error report saved: \(report.id)")
        } catch {
            logger.error("Failed to save error report: \(error.localizedDescription)")
        }
    }
    
    private func saveAnalyticsEvent(_ event: AnalyticsEvent) {
        do {
            let data = try JSONEncoder().encode(event)
            let url = getAnalyticsDirectory().appendingPathComponent("\(event.id).json")
            try data.write(to: url)
        } catch {
            logger.error("Failed to save analytics event: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Directory Management
    
    private func getCrashReportsDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let crashReportsPath = documentsPath.appendingPathComponent("CrashReports")
        
        try? FileManager.default.createDirectory(at: crashReportsPath, withIntermediateDirectories: true)
        return crashReportsPath
    }
    
    private func getErrorReportsDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let errorReportsPath = documentsPath.appendingPathComponent("ErrorReports")
        
        try? FileManager.default.createDirectory(at: errorReportsPath, withIntermediateDirectories: true)
        return errorReportsPath
    }
    
    private func getAnalyticsDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let analyticsPath = documentsPath.appendingPathComponent("Analytics")
        
        try? FileManager.default.createDirectory(at: analyticsPath, withIntermediateDirectories: true)
        return analyticsPath
    }
    
    // MARK: - Data Export
    
    func exportCrashReports() -> [CrashReport] {
        let directory = getCrashReportsDirectory()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            
            return files.compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let report = try? JSONDecoder().decode(CrashReport.self, from: data) else {
                    return nil
                }
                return report
            }
        } catch {
            logger.error("Failed to export crash reports: \(error.localizedDescription)")
            return []
        }
    }
    
    func clearOldReports(olderThan days: Int = 30) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        [getCrashReportsDirectory(), getErrorReportsDirectory(), getAnalyticsDirectory()].forEach { directory in
            do {
                let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])
                
                for file in files {
                    if let creationDate = try file.resourceValues(forKeys: [.creationDateKey]).creationDate,
                       creationDate < cutoffDate {
                        try FileManager.default.removeItem(at: file)
                    }
                }
            } catch {
                logger.error("Failed to clear old reports: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Data Models

struct CrashReport: Codable {
    let id = UUID()
    let type: CrashType
    let name: String
    let reason: String
    let callStack: [String]
    let userInfo: [String: String]
    let timestamp: Date
    
    enum CrashType: String, Codable {
        case exception
        case signal
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, type, name, reason, callStack, userInfo, timestamp
    }
    
    init(type: CrashType, name: String, reason: String, callStack: [String], userInfo: [String: Any], timestamp: Date) {
        self.type = type
        self.name = name
        self.reason = reason
        self.callStack = callStack
        self.userInfo = userInfo.compactMapValues { String(describing: $0) }
        self.timestamp = timestamp
    }
}

struct ErrorReport: Codable {
    let id: UUID
    let errorDescription: String
    let errorDomain: String
    let errorCode: Int
    let context: [String: String]
    let userInfo: [String: String]
    let timestamp: Date
    
    init(error: Error, context: [String: Any], userInfo: [String: Any], timestamp: Date) {
        self.id = UUID()
        self.errorDescription = error.localizedDescription
        self.errorDomain = (error as NSError).domain
        self.errorCode = (error as NSError).code
        self.context = context.compactMapValues { String(describing: $0) }
        self.userInfo = userInfo.compactMapValues { String(describing: $0) }
        self.timestamp = timestamp
    }
}

struct AnalyticsEvent: Codable {
    let id: UUID
    let name: String
    let parameters: [String: String]
    let userInfo: [String: String]
    let timestamp: Date
    
    init(name: String, parameters: [String: Any], userInfo: [String: Any], timestamp: Date) {
        self.id = UUID()
        self.name = name
        self.parameters = parameters.compactMapValues { String(describing: $0) }
        self.userInfo = userInfo.compactMapValues { String(describing: $0) }
        self.timestamp = timestamp
    }
}

// MARK: - Performance Transaction

class PerformanceTransaction {
    let name: String
    let startTime: Date
    private let crashReportingService: CrashReportingService
    private var isFinished = false
    
    init(name: String, startTime: Date, crashReportingService: CrashReportingService) {
        self.name = name
        self.startTime = startTime
        self.crashReportingService = crashReportingService
    }
    
    func finish() {
        guard !isFinished else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        Task { @MainActor in
            crashReportingService.trackEvent("transaction_finished", parameters: [
                "transaction_name": name,
                "duration_seconds": duration
            ])
        }
        
        isFinished = true
    }
    
    func setData(_ data: [String: Any]) {
        Task { @MainActor in
            crashReportingService.trackEvent("transaction_data", parameters: [
                "transaction_name": name,
                "data": data
            ])
        }
    }
    
    deinit {
        if !isFinished {
            finish()
        }
    }
}