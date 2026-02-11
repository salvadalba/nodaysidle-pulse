// HistoryRecorder.swift
// Pulse — macOS system monitor

import Foundation
import SwiftData
import os

private let historyLogger = Logger(subsystem: "com.pulse.app", category: "History")

/// Sendable point for chart display (no SwiftData reference).
public struct HistoricalPoint: Sendable {
    public let timestamp: Date
    public let value: Double
    public init(timestamp: Date, value: Double) { self.timestamp = timestamp; self.value = value }
}

/// Sendable DTO for recording (MetricSample is @Model and not Sendable).
public struct MetricSampleRecord: Sendable {
    public let timestamp: Date
    public let metricType: MetricType
    public let value: Double
    public let metadata: [String: String]
    public init(timestamp: Date, metricType: MetricType, value: Double, metadata: [String: String] = [:]) {
        self.timestamp = timestamp
        self.metricType = metricType
        self.value = value
        self.metadata = metadata
    }
}

public actor HistoryRecorder {
    private let container: ModelContainer
    private let context: ModelContext
    private var buffer: [MetricSampleRecord] = []
    private var lastCommit = Date()
    private let batchInterval: TimeInterval = 5.0
    private let batchSize = 50
    private let signpost = OSSignposter(logger: Logger(subsystem: "com.pulse.app", category: "History"))

    public init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
    }

    public func record(_ records: [MetricSampleRecord]) async {
        buffer.append(contentsOf: records)
        if buffer.count >= batchSize || Date().timeIntervalSince(lastCommit) >= batchInterval {
            await flush()
        }
    }

    public func flush() async {
        guard !buffer.isEmpty else { return }
        let toWrite = buffer
        buffer.removeAll()
        lastCommit = Date()
        let id = signpost.beginInterval("batchWrite")
        defer { signpost.endInterval("batchWrite", id) }
        for r in toWrite {
            let sample = MetricSample(timestamp: r.timestamp, metricType: r.metricType, value: r.value, metadata: r.metadata)
            context.insert(sample)
        }
        do {
            try context.save()
            historyLogger.debug("Wrote \(toWrite.count) samples")
        } catch {
            historyLogger.error("History save failed: \(error.localizedDescription)")
        }
    }

    /// Returns historical points as Sendable value type for use on MainActor.
    public func query(metricType: MetricType, range: DateInterval) async throws -> [HistoricalPoint] {
        let predicate = #Predicate<MetricSample> { sample in
            sample.metricType == metricType.rawValue &&
            sample.timestamp >= range.start &&
            sample.timestamp <= range.end
        }
        var desc = FetchDescriptor<MetricSample>(predicate: predicate)
        desc.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
        let samples = try context.fetch(desc)
        return samples.map { HistoricalPoint(timestamp: $0.timestamp, value: $0.value) }
    }

    public func prune(olderThan date: Date) async {
        let predicate = #Predicate<MetricSample> { $0.timestamp < date }
        do {
            try context.delete(model: MetricSample.self, where: predicate)
            try context.save()
            historyLogger.info("Pruned samples older than \(date)")
        } catch {
            historyLogger.error("Prune failed: \(error.localizedDescription)")
        }
    }
}
