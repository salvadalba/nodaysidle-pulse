// CardViewModel.swift
// Pulse — macOS system monitor

import Foundation
import SwiftUI

@MainActor
@Observable
public final class CardViewModel {
    public let metricType: MetricType
    public var currentValue: Double = 0
    public var sparklineBuffer: [Double] = []
    public var historicalData: [HistoricalPoint] = []
    public var isLoadingHistory = false
    public var hasData = false

    private let bufferSize = 60
    private let historyRecorder: HistoryRecorder?
    private let formatter: (Double) -> String

    public var formattedValue: String { formatter(currentValue) }

    public init(metricType: MetricType, historyRecorder: HistoryRecorder?) {
        self.metricType = metricType
        self.historyRecorder = historyRecorder
        self.formatter = Self.formatter(for: metricType)
    }

    public func update(from snapshot: MetricSnapshot) {
        let value: Double
        switch metricType {
        case .cpu: value = snapshot.cpu.aggregate
        case .memory: value = snapshot.memory.total > 0 ? Double(snapshot.memory.used) / Double(snapshot.memory.total) * 100 : 0
        case .gpu: value = snapshot.gpu.utilization
        case .disk:
            let d = snapshot.disks.first { $0.mountPoint == "/" } ?? snapshot.disks.first
            value = d.map { $0.totalBytes > 0 ? Double($0.usedBytes) / Double($0.totalBytes) * 100 : 0 } ?? 0
        case .network: value = snapshot.network.reduce(0) { $0 + $1.bytesInPerSec + $1.bytesOutPerSec }
        }
        currentValue = value
        hasData = true
        if sparklineBuffer.count >= bufferSize { sparklineBuffer.removeFirst() }
        sparklineBuffer.append(value)
    }

    public func loadHistory(range: DateInterval) async {
        guard let historyRecorder else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        do {
            historicalData = try await historyRecorder.query(metricType: metricType, range: range)
        } catch {
            historicalData = []
        }
    }

    private static func formatter(for type: MetricType) -> (Double) -> String {
        switch type {
        case .cpu, .memory, .gpu, .disk:
            return { String(format: "%.1f%%", $0) }
        case .network:
            return { v in
                if v >= 1_000_000 { return String(format: "%.1f MB/s", v / 1_000_000) }
                if v >= 1_000 { return String(format: "%.1f KB/s", v / 1_000) }
                return String(format: "%.0f B/s", v)
            }
        }
    }
}
