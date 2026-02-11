// PulseRootView.swift
// Pulse — macOS system monitor

import SwiftUI
import SwiftData

public struct PulseRootView: View {
    let container: ModelContainer
    @Binding var viewModel: DashboardViewModel?

    public init(container: ModelContainer, viewModel: Binding<DashboardViewModel?>) {
        self.container = container
        _viewModel = viewModel
    }

    public var body: some View {
        Group {
            if let viewModel {
                DashboardRootView(viewModel: viewModel)
            } else {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { await createViewModelIfNeeded() }
            }
        }
    }

    private func createViewModelIfNeeded() async {
        guard viewModel == nil else { return }
        let recorder = HistoryRecorder(container: container)
        let days = UserDefaults.standard.integer(forKey: "pulse.historyRetentionDays")
        let retention = (days > 0 ? days : 30)
        await recorder.prune(olderThan: Date().addingTimeInterval(-Double(retention) * 86400))
        let engine = MetricEngine(historyRecorder: recorder)
        let notifier = AlertNotifier()
        let vm = DashboardViewModel(engine: engine, container: container, historyRecorder: recorder, alertNotifier: notifier)
        viewModel = vm
        await vm.start()
    }
}
