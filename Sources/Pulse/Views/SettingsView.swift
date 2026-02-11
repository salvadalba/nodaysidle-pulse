// SettingsView.swift
// Pulse — macOS system monitor

import SwiftUI
import SwiftData

public struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AlertThreshold.metricTypeRaw) private var thresholds: [AlertThreshold]
    @AppStorage("pulse.pollInterval") private var pollInterval: Double = 1.0
    @AppStorage("pulse.historyRetentionDays") private var historyRetentionDays: Int = 30
    @AppStorage("pulse.cloudKitSync") private var cloudKitSync: Bool = false

    public init() {}

    public var body: some View {
        Form {
            GroupBox("Alert Thresholds") {
                ForEach(thresholds, id: \.id) { t in
                    HStack {
                        Text(t.metricType.rawValue.capitalized)
                        Spacer()
                        TextField("Value", value: Binding(
                            get: { t.value },
                            set: { t.value = $0 }
                        ), format: .number)
                        .frame(width: 50)
                        Toggle("", isOn: Binding(
                            get: { t.enabled },
                            set: { t.enabled = $0 }
                        ))
                    }
                }
            }
            GroupBox("Polling") {
                Picker("Interval", selection: $pollInterval) {
                    Text("0.5 Hz").tag(0.5)
                    Text("1 Hz").tag(1.0)
                    Text("2 Hz").tag(2.0)
                }
            }
            GroupBox("History") {
                Picker("Retention", selection: $historyRetentionDays) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
            }
            GroupBox("Sync") {
                Toggle("CloudKit Sync", isOn: $cloudKitSync)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 320)
    }
}
