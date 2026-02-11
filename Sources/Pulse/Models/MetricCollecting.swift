// MetricCollecting.swift
// Pulse — macOS system monitor

import Foundation

// MARK: - Metric Collecting Protocol

/// Protocol for actor-based metric collectors. Each collector returns a Sendable metric type.
public protocol MetricCollecting: Actor {
    associatedtype Metric: Sendable
    func currentUsage() async throws -> Metric
}
