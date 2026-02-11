// DashboardViewModel.swift
// Pulse — macOS system monitor

import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
public final class DashboardViewModel {
    public private(set) var cards: [CardViewModel] = []
    public var expandedCardId: MetricType?
    public var alertBreachedTypes: Set<MetricType> = []
    public var collectorFailureTypes: Set<MetricType> = []

    private let engine: MetricEngine
    private let container: ModelContainer
    private let alertEvaluator = AlertEvaluator()
    private let alertNotifier: AlertNotifier
    private var thresholdSpecs: [AlertThresholdSpec] = []
    private var layoutTask: Task<Void, Never>?

    public init(engine: MetricEngine, container: ModelContainer, historyRecorder: HistoryRecorder, alertNotifier: AlertNotifier) {
        self.engine = engine
        self.container = container
        self.alertNotifier = alertNotifier
        let order = loadCardOrder()
        let types = order.isEmpty ? Array(MetricType.allCases) : (order + MetricType.allCases.filter { !order.contains($0) })
        self.cards = types.map { CardViewModel(metricType: $0, historyRecorder: historyRecorder) }
        Task {
            await engine.setOnSnapshot { [weak self] snapshot in
                Task { @MainActor in
                    self?.apply(snapshot)
                }
            }
        }
    }

    public func start() async {
        await refreshThresholdSpecs()
        let interval = UserDefaults.standard.double(forKey: "pulse.pollInterval")
        if interval > 0 { await engine.setTickInterval(interval) }
        await engine.start()
    }

    public func stop() async {
        await engine.stop()
    }

    public func moveCard(from source: IndexSet, to destination: Int) {
        var list = cards
        list.move(fromOffsets: source, toOffset: destination)
        cards = list
        persistCardOrder()
    }

    public func toggleExpand(_ id: MetricType) {
        if expandedCardId == id { expandedCardId = nil } else { expandedCardId = id }
    }

    public func refreshThresholdSpecs() async {
        let context = ModelContext(container)
        let desc = FetchDescriptor<AlertThreshold>()
        guard let all = try? context.fetch(desc) else { return }
        thresholdSpecs = all.map { AlertThresholdSpec(metricType: $0.metricType, op: $0.op, value: $0.value, enabled: $0.enabled) }
    }

    public func updateCollectorFailures() async {
        var failures: Set<MetricType> = []
        for type in MetricType.allCases {
            let n = await engine.consecutiveFailureCount(for: type)
            if n >= 3 { failures.insert(type) }
        }
        collectorFailureTypes = failures
    }

    private func apply(_ snapshot: MetricSnapshot) {
        for card in cards { card.update(from: snapshot) }
        let events = alertEvaluator.evaluate(snapshot, thresholds: thresholdSpecs)
        alertBreachedTypes = Set(events.map(\.metricType))
        if !events.isEmpty { Task { await alertNotifier.notify(events) } }
        Task { await updateCollectorFailures() }
    }

    private func loadCardOrder() -> [MetricType] {
        let context = ModelContext(container)
        var desc = FetchDescriptor<DashboardLayout>()
        desc.fetchLimit = 1
        guard let layout = try? context.fetch(desc).first else { return Array(MetricType.allCases) }
        return layout.cardOrder.isEmpty ? Array(MetricType.allCases) : layout.cardOrder
    }

    private func persistCardOrder() {
        layoutTask?.cancel()
        let order = cards.map(\.metricType)
        layoutTask = Task { @MainActor in
            let context = ModelContext(container)
            var desc = FetchDescriptor<DashboardLayout>()
            desc.fetchLimit = 1
            if let layout = try? context.fetch(desc).first {
                layout.cardOrder = order
            } else {
                let layout = DashboardLayout(cardOrder: order, expandedCardId: nil)
                context.insert(layout)
            }
            try? context.save()
        }
    }
}
