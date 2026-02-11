// DetailView.swift
// Pulse — macOS system monitor

import SwiftUI

public struct DetailView: View {
    let viewModel: CardViewModel
    let namespace: Namespace.ID
    var onDismiss: () -> Void

    @State private var selectedRange: TimeRange = .oneHour

    public init(viewModel: CardViewModel, namespace: Namespace.ID, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.namespace = namespace
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                Text(viewModel.metricType.rawValue.capitalized)
                    .font(.title2)
                Spacer()
            }
            Picker("Range", selection: $selectedRange) {
                ForEach(TimeRange.allCases, id: \.self) { r in Text(r.label(for: r)).tag(r) }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedRange) { _, new in
                Task { await viewModel.loadHistory(range: new.dateInterval) }
            }
            if viewModel.isLoadingHistory {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: 200)
            } else {
                let points = viewModel.historicalData.map(\.value)
                SparklineChartView(dataPoints: points, color: colorFor(viewModel.metricType))
                    .frame(height: 200)
            }
            statsView
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .matchedGeometryEffect(id: viewModel.metricType, in: namespace)
        .onAppear {
            Task { await viewModel.loadHistory(range: selectedRange.dateInterval) }
        }
    }

    private var statsView: some View {
        let data = viewModel.historicalData.map(\.value)
        let minV = data.min() ?? 0
        let maxV = data.max() ?? 0
        let avgV = data.isEmpty ? 0 : data.reduce(0, +) / Double(data.count)
        return HStack(spacing: 24) {
            StatLabel(title: "Min", value: minV)
            StatLabel(title: "Max", value: maxV)
            StatLabel(title: "Avg", value: avgV)
        }
    }

    private func colorFor(_ type: MetricType) -> Color {
        switch type {
        case .cpu: return .blue
        case .memory: return .purple
        case .gpu: return .orange
        case .disk: return .green
        case .network: return .cyan
        }
    }
}

private struct StatLabel: View {
    let title: String
    let value: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(String(format: "%.1f", value)).font(.body.monospacedDigit())
        }
    }
}

public enum TimeRange: CaseIterable {
    case oneHour, sixHours, oneDay, sevenDays, thirtyDays
    public var dateInterval: DateInterval {
        let end = Date()
        let start: Date
        switch self {
        case .oneHour: start = end.addingTimeInterval(-3600)
        case .sixHours: start = end.addingTimeInterval(-6 * 3600)
        case .oneDay: start = end.addingTimeInterval(-86400)
        case .sevenDays: start = end.addingTimeInterval(-7 * 86400)
        case .thirtyDays: start = end.addingTimeInterval(-30 * 86400)
        }
        return DateInterval(start: start, end: end)
    }
    public func label(for r: TimeRange) -> String {
        switch r {
        case .oneHour: return "1h"
        case .sixHours: return "6h"
        case .oneDay: return "24h"
        case .sevenDays: return "7d"
        case .thirtyDays: return "30d"
        }
    }
}
