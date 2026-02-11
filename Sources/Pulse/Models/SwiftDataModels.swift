// SwiftDataModels.swift
// Pulse — macOS system monitor

import Foundation
import SwiftData

// MARK: - Metric Sample

@Model
public final class MetricSample {
    public var id: UUID
    public var timestamp: Date
    public var metricType: String  // MetricType.rawValue
    public var value: Double
    public var metadata: [String: String]

    public init(id: UUID = UUID(), timestamp: Date, metricType: MetricType, value: Double, metadata: [String: String] = [:]) {
        self.id = id
        self.timestamp = timestamp
        self.metricType = metricType.rawValue
        self.value = value
        self.metadata = metadata
    }

    public var metricTypeEnum: MetricType {
        get { MetricType(rawValue: metricType) ?? .cpu }
        set { metricType = newValue.rawValue }
    }
}

// MARK: - Dashboard Layout

@Model
public final class DashboardLayout {
    public var id: UUID
    /// Stored as MetricType.rawValue for SwiftData compatibility.
    public var cardOrderRaw: [String]
    public var expandedCardIdRaw: String?

    public init(id: UUID = UUID(), cardOrder: [MetricType], expandedCardId: MetricType? = nil) {
        self.id = id
        self.cardOrderRaw = cardOrder.map(\.rawValue)
        self.expandedCardIdRaw = expandedCardId?.rawValue
    }

    public var cardOrder: [MetricType] {
        get { cardOrderRaw.compactMap { MetricType(rawValue: $0) } }
        set { cardOrderRaw = newValue.map(\.rawValue) }
    }

    public var expandedCardId: MetricType? {
        get { expandedCardIdRaw.flatMap { MetricType(rawValue: $0) } }
        set { expandedCardIdRaw = newValue?.rawValue }
    }
}

// MARK: - Alert Threshold

@Model
public final class AlertThreshold {
    public var id: UUID
    public var metricTypeRaw: String  // MetricType.rawValue
    public var opRaw: String          // ComparisonOperator.rawValue
    public var value: Double
    public var enabled: Bool

    public init(id: UUID = UUID(), metricType: MetricType, op: ComparisonOperator, value: Double, enabled: Bool = true) {
        self.id = id
        self.metricTypeRaw = metricType.rawValue
        self.opRaw = op.rawValue
        self.value = value
        self.enabled = enabled
    }

    public var metricType: MetricType {
        get { MetricType(rawValue: metricTypeRaw) ?? .cpu }
        set { metricTypeRaw = newValue.rawValue }
    }

    public var op: ComparisonOperator {
        get { ComparisonOperator(rawValue: opRaw) ?? .greaterThan }
        set { opRaw = newValue.rawValue }
    }
}
