// DashboardRootView.swift
// Pulse — macOS system monitor

import SwiftUI
import SwiftData

public struct DashboardRootView: View {
    let viewModel: DashboardViewModel
    @State private var windowReady = false

    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        DashboardView(viewModel: viewModel)
            .background(WindowAccessor { window in
                guard !windowReady else { return }
                window.minSize = NSSize(width: 400, height: 300)
                window.titlebarAppearsTransparent = false
                windowReady = true
            })
    }
}
