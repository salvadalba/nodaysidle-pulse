// AlertEvaluator.swift
// Pulse — macOS system monitor

import Foundation
import os

private let alertLogger = Logger(subsystem: "com.pulse.app", category: "Alerts")

/// Sendable representation of a threshold for evaluation (no SwiftData dependency).
public struct AlertThresholdSpec: Sendable {
    public let metricType: MetricType
    public let op: ComparisonOperator
    public let value: Double
    public let enabled: Bool
    public init(metricType: MetricType, op: ComparisonOperator, value: Double, enabled: Bool) {
        self.metricType = metricType
        self.op = op
        self.value = value
        self.enabled = enabled
    }
}

public struct AlertEvaluator: Sendable {
    public init() {}

    public func evaluate(_ snapshot: MetricSnapshot, thresholds: [AlertThresholdSpec]) -> [AlertEvent] {
        var events: [AlertEvent] = []
        for spec in thresholds where spec.enabled {
            let current: Double
            switch spec.metricType {
            case .cpu: current = snapshot.cpu.aggregate
            case .memory: current = Double(snapshot.memory.used) / Double(max(1, snapshot.memory.total)) * 100
            case .gpu: current = snapshot.gpu.utilization
            case .disk:
                let d = snapshot.disks.first { $0.mountPoint == "/" } ?? snapshot.disks.first
                guard let disk = d else { continue }
                current = disk.totalBytes > 0 ? Double(disk.usedBytes) / Double(disk.totalBytes) * 100 : 0
            case .network:
                let total = snapshot.network.reduce(0.0) { $0 + $1.bytesInPerSec + $1.bytesOutPerSec }
                current = total
            }
            let breached: Bool
            switch spec.op {
            case .greaterThan: breached = current > spec.value
            case .lessThan: breached = current < spec.value
            }
            if breached {
                events.append(AlertEvent(
                    metricType: spec.metricType,
                    thresholdValue: spec.value,
                    comparisonOp: spec.op,
                    currentValue: current,
                    timestamp: snapshot.timestamp
                ))
            }
        }
        return events
    }
}
