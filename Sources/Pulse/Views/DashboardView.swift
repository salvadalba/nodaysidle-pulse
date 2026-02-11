// DashboardView.swift
// Pulse — macOS system monitor

import SwiftUI
import SwiftData

extension MetricType: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.rawValue, importing: { MetricType(rawValue: $0) ?? .cpu })
    }
}

public struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel
    @Namespace private var namespace
    @Environment(\.modelContext) private var modelContext

    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if let expandedId = viewModel.expandedCardId,
               let card = viewModel.cards.first(where: { $0.metricType == expandedId }) {
                DetailView(viewModel: card, namespace: namespace) {
                    viewModel.toggleExpand(expandedId)
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                    ForEach(viewModel.cards, id: \.metricType) { card in
                        MetricCardView(
                            viewModel: card,
                            namespace: namespace,
                            isExpanded: false,
                            showAlertBadge: viewModel.alertBreachedTypes.contains(card.metricType),
                            showErrorBadge: viewModel.collectorFailureTypes.contains(card.metricType),
                            onTap: { viewModel.toggleExpand(card.metricType) }
                        )
                        .draggable(card.metricType)
                        .dropDestination(for: MetricType.self) { items, _ in
                            guard let item = items.first, let from = viewModel.cards.firstIndex(where: { $0.metricType == item }),
                                  let to = viewModel.cards.firstIndex(where: { $0.metricType == card.metricType }) else { return false }
                            viewModel.moveCard(from: IndexSet(integer: from), to: to > from ? to + 1 : to)
                            return true
                        }
                    }
                }
                .padding()
            }
        }
        .animation(.default, value: viewModel.expandedCardId)
    }
}
