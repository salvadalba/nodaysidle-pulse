// MetricSnapshot.swift
// Pulse — macOS system monitor

import Foundation

// MARK: - Metric Snapshot

public struct MetricSnapshot: Sendable {
    public let cpu: CPUMetric
    public let memory: MemoryMetric
    public let gpu: GPUMetric
    public let disks: [DiskMetric]
    public let network: [NetworkMetric]
    public let timestamp: Date

    public init(cpu: CPUMetric, memory: MemoryMetric, gpu: GPUMetric, disks: [DiskMetric], network: [NetworkMetric], timestamp: Date) {
        self.cpu = cpu
        self.memory = memory
        self.gpu = gpu
        self.disks = disks
        self.network = network
        self.timestamp = timestamp
    }
}

// MARK: - Alert Event

/// Sendable snapshot of a threshold breach for notifications (no reference to SwiftData @Model).
public struct AlertEvent: Sendable {
    public let metricType: MetricType
    public let thresholdValue: Double
    public let comparisonOp: ComparisonOperator
    public let currentValue: Double
    public let timestamp: Date

    public init(metricType: MetricType, thresholdValue: Double, comparisonOp: ComparisonOperator, currentValue: Double, timestamp: Date) {
        self.metricType = metricType
        self.thresholdValue = thresholdValue
        self.comparisonOp = comparisonOp
        self.currentValue = currentValue
        self.timestamp = timestamp
    }
}
