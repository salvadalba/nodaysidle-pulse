// HistoryRecorderTests.swift
// Pulse — integration tests for HistoryRecorder

import Testing
import Foundation
import SwiftData
@testable import Pulse

struct HistoryRecorderTests {
    @Test func batchWriteAndQuery() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MetricSample.self, DashboardLayout.self, AlertThreshold.self,
            configurations: config
        )
        let recorder = HistoryRecorder(container: container)
        let now = Date()
        var records: [MetricSampleRecord] = []
        for i in 0..<50 {
            records.append(MetricSampleRecord(timestamp: now.addingTimeInterval(Double(i)), metricType: .cpu, value: Double(i)))
        }
        await recorder.record(records)
        await recorder.flush()
        let range = DateInterval(start: now, end: now.addingTimeInterval(100))
        let points = try await recorder.query(metricType: .cpu, range: range)
        #expect(points.count == 50)
    }

    @Test func queryReturnsFilteredByTypeAndRange() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MetricSample.self, DashboardLayout.self, AlertThreshold.self,
            configurations: config
        )
        let recorder = HistoryRecorder(container: container)
        let base = Date()
        await recorder.record([
            MetricSampleRecord(timestamp: base, metricType: .cpu, value: 1),
            MetricSampleRecord(timestamp: base.addingTimeInterval(1), metricType: .memory, value: 2)
        ])
        await recorder.flush()
        let range = DateInterval(start: base.addingTimeInterval(-1), end: base.addingTimeInterval(10))
        let cpuPoints = try await recorder.query(metricType: .cpu, range: range)
        let memPoints = try await recorder.query(metricType: .memory, range: range)
        #expect(cpuPoints.count == 1)
        #expect(memPoints.count == 1)
    }

    @Test func pruneRemovesOldRecords() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MetricSample.self, DashboardLayout.self, AlertThreshold.self,
            configurations: config
        )
        let recorder = HistoryRecorder(container: container)
        let old = Date().addingTimeInterval(-100_000)
        let recent = Date()
        await recorder.record([
            MetricSampleRecord(timestamp: old, metricType: .cpu, value: 0),
            MetricSampleRecord(timestamp: recent, metricType: .cpu, value: 1)
        ])
        await recorder.flush()
        let cutoff = Date().addingTimeInterval(-50_000)
        await recorder.prune(olderThan: cutoff)
        let range = DateInterval(start: Date.distantPast, end: Date.distantFuture)
        let points = try await recorder.query(metricType: .cpu, range: range)
        #expect(points.count == 1)
        #expect(points[0].value == 1)
    }
}
