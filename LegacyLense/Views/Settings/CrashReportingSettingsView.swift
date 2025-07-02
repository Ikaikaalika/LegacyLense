//
//  CrashReportingSettingsView.swift
//  LegacyLense
//
//  Created by Tyler Gee on 6/12/25.
//

import SwiftUI

struct CrashReportingSettingsView: View {
    @EnvironmentObject var crashReportingService: CrashReportingService
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingDataExport = false
    @State private var exportedReports: [CrashReport] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Enable Crash Reporting", isOn: Binding(
                        get: { crashReportingService.isEnabled },
                        set: { crashReportingService.updateConfiguration(enabled: $0) }
                    ))
                    
                    Text("Help us improve LegacyLense by automatically sending crash reports and performance data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                } header: {
                    Text("Crash Reporting")
                }
                
                if crashReportingService.isEnabled {
                    Section {
                        HStack {
                            Text("Session ID")
                            Spacer()
                            Text(crashReportingService.sessionId.prefix(8) + "...")
                                .foregroundColor(.secondary)
                                .font(.monospaced(.caption)())
                        }
                        
                        if let userId = crashReportingService.userId {
                            HStack {
                                Text("User ID")
                                Spacer()
                                Text(userId.prefix(8) + "...")
                                    .foregroundColor(.secondary)
                                    .font(.monospaced(.caption)())
                            }
                        }
                    } header: {
                        Text("Session Information")
                    }
                    
                    Section {
                        Button("Export Crash Reports") {
                            exportCrashReports()
                        }
                        
                        Button("Clear Old Reports") {
                            clearOldReports()
                        }
                        
                        Button("Test Crash Reporting") {
                            testCrashReporting()
                        }
                        .foregroundColor(.orange)
                    } header: {
                        Text("Data Management")
                    } footer: {
                        Text("Export allows you to review crash data. Old reports (30+ days) can be cleared to save space.")
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy Information")
                            .font(.headline)
                        
                        Text("• Crash reports are stored locally on your device")
                        Text("• No personal information is collected")
                        Text("• Data helps identify and fix app issues")
                        Text("• You can disable this feature at any time")
                        
                        Text("Reports include:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.top, 8)
                        
                        Text("• App version and device information")
                        Text("• Memory usage at time of crash")
                        Text("• Error messages and stack traces")
                        Text("• Session and anonymized user identifiers")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } header: {
                    Text("Privacy")
                }
            }
            .navigationTitle("Crash Reporting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDataExport) {
                CrashReportExportView(reports: exportedReports)
            }
        }
    }
    
    private func exportCrashReports() {
        exportedReports = crashReportingService.exportCrashReports()
        showingDataExport = true
    }
    
    private func clearOldReports() {
        crashReportingService.clearOldReports()
    }
    
    private func testCrashReporting() {
        // Test error tracking (non-fatal)
        let testError = NSError(domain: "TestDomain", code: 999, userInfo: [
            NSLocalizedDescriptionKey: "This is a test error for crash reporting validation"
        ])
        
        crashReportingService.trackError(testError, context: [
            "test_type": "manual_test",
            "user_action": "test_button_pressed"
        ])
        
        // Test event tracking
        crashReportingService.trackEvent("crash_reporting_test", parameters: [
            "test_timestamp": Date().timeIntervalSince1970,
            "test_source": "settings_view"
        ])
    }
}

struct CrashReportExportView: View {
    let reports: [CrashReport]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if reports.isEmpty {
                    Text("No crash reports found")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(reports, id: \.id) { report in
                        CrashReportRow(report: report)
                    }
                }
            }
            .navigationTitle("Crash Reports (\(reports.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                if !reports.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(
                            item: generateReportSummary(),
                            subject: Text("LegacyLense Crash Reports"),
                            message: Text("Crash report data from LegacyLense")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            })
        }
    }
    
    private func generateReportSummary() -> String {
        var summary = "LegacyLense Crash Reports Summary\n"
        summary += "Generated: \(Date().formatted())\n"
        summary += "Total Reports: \(reports.count)\n\n"
        
        for (index, report) in reports.enumerated() {
            summary += "Report \(index + 1):\n"
            summary += "Type: \(report.type.rawValue)\n"
            summary += "Name: \(report.name)\n"
            summary += "Reason: \(report.reason)\n"
            summary += "Timestamp: \(report.timestamp.formatted())\n"
            summary += "App Version: \(report.userInfo["app_version"] ?? "Unknown")\n"
            summary += "Device: \(report.userInfo["device_model"] ?? "Unknown")\n"
            summary += "System: \(report.userInfo["system_name"] ?? "Unknown") \(report.userInfo["system_version"] ?? "Unknown")\n"
            summary += "\n"
        }
        
        return summary
    }
}

struct CrashReportRow: View {
    let report: CrashReport
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.name)
                        .font(.headline)
                    
                    Text(report.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(report.type.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(report.type == .exception ? Color.red.opacity(0.2) : Color.orange.opacity(0.2))
                        .foregroundColor(report.type == .exception ? .red : .orange)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    Button(isExpanded ? "Less" : "More") {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }
                    .font(.caption)
                }
            }
            
            Text(report.reason)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(isExpanded ? nil : 2)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let appVersion = report.userInfo["app_version"] {
                        HStack {
                            Text("App Version:")
                                .fontWeight(.medium)
                            Text("\(appVersion)")
                        }
                        .font(.caption)
                    }
                    
                    if let deviceModel = report.userInfo["device_model"] {
                        HStack {
                            Text("Device:")
                                .fontWeight(.medium)
                            Text("\(deviceModel)")
                        }
                        .font(.caption)
                    }
                    
                    if !report.callStack.isEmpty {
                        Text("Stack Trace (first 3 lines):")
                            .fontWeight(.medium)
                            .font(.caption)
                        
                        ForEach(Array(report.callStack.prefix(3).enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        if report.callStack.count > 3 {
                            Text("... and \(report.callStack.count - 3) more lines")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CrashReportingSettingsView()
        .environmentObject(CrashReportingService.shared)
}