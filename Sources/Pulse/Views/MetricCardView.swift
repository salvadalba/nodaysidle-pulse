// MetricCardView.swift
// Pulse — macOS system monitor

import SwiftUI

public struct MetricCardView: View {
    let viewModel: CardViewModel
    let namespace: Namespace.ID
    let isExpanded: Bool
    let showAlertBadge: Bool
    let showErrorBadge: Bool
    var onTap: () -> Void

    private var iconName: String {
        switch viewModel.metricType {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .gpu: return "square.stack.3d.up"
        case .disk: return "internaldrive"
        case .network: return "network"
        }
    }

    private var color: Color {
        switch viewModel.metricType {
        case .cpu: return .blue
        case .memory: return .purple
        case .gpu: return .orange
        case .disk: return .green
        case .network: return .cyan
        }
    }

    public init(viewModel: CardViewModel, namespace: Namespace.ID, isExpanded: Bool, showAlertBadge: Bool, showErrorBadge: Bool, onTap: @escaping () -> Void) {
        self.viewModel = viewModel
        self.namespace = namespace
        self.isExpanded = isExpanded
        self.showAlertBadge = showAlertBadge
        self.showErrorBadge = showErrorBadge
        self.onTap = onTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(color)
                Text(viewModel.metricType.rawValue.capitalized)
                    .font(.headline)
                Spacer()
                if showAlertBadge {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                if showErrorBadge {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            Text(viewModel.formattedValue)
                .font(.title2.monospacedDigit())
            SparklineChartView(dataPoints: viewModel.sparklineBuffer, color: color)
                .frame(height: 44)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .matchedGeometryEffect(id: viewModel.metricType, in: namespace)
        .onTapGesture { onTap() }
    }
}
