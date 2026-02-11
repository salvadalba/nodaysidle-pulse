// PulseApp.swift
// Pulse — macOS system monitor

import SwiftUI
import SwiftData

@main
struct PulseApp: App {
    @State private var dashboardViewModel: DashboardViewModel?

    @State private var modelContainer: ModelContainer = {
        // Local-only for now; CloudKit can be added for DashboardLayout/AlertThreshold in Settings.
        let config = ModelConfiguration(
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(
                for: MetricSample.self, DashboardLayout.self, AlertThreshold.self,
                configurations: config
            )
            seedDefaultAlertThresholdsIfNeeded(container: container)
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            PulseRootView(container: modelContainer, viewModel: $dashboardViewModel)
                .frame(minWidth: 400, minHeight: 300)
        }
        .modelContainer(modelContainer)
        .windowStyle(.automatic)
        .defaultSize(width: 800, height: 600)

        MenuBarExtra {
            if let vm = dashboardViewModel {
                MenuBarView(viewModel: vm)
            } else {
                Text("Pulse")
                Button("Open Main Window") { NSApplication.shared.activate(ignoringOtherApps: true) }
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        } label: {
            if let vm = dashboardViewModel {
                MenuBarIconView(cards: vm.cards)
            } else {
                Image(systemName: "waveform.path.ecg")
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - Seed Default Alert Thresholds

private func seedDefaultAlertThresholdsIfNeeded(container: ModelContainer) {
    let context = ModelContext(container)
    let desc = FetchDescriptor<AlertThreshold>()
    guard (try? context.fetch(desc).isEmpty) == true else { return }
    let cpu = AlertThreshold(metricType: .cpu, op: .greaterThan, value: 90, enabled: true)
    let disk = AlertThreshold(metricType: .disk, op: .greaterThan, value: 95, enabled: true)
    context.insert(cpu)
    context.insert(disk)
    try? context.save()
}

