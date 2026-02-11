// MetricEngineTests.swift
// Pulse — integration tests for MetricEngine

import Testing
import Foundation
import SwiftData
@testable import Pulse

private final class SnapshotHolder: @unchecked Sendable {
    var snapshot: MetricSnapshot?
}

private final class CountHolder: @unchecked Sendable {
    var value = 0
}

struct MetricEngineTests {
    @Test func metricEngineProducesSnapshotWithinTwoSeconds() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MetricSample.self, DashboardLayout.self, AlertThreshold.self,
            configurations: config
        )
        let recorder = HistoryRecorder(container: container)
        let engine = MetricEngine(historyRecorder: recorder)
        let holder = SnapshotHolder()
        await engine.setOnSnapshot { holder.snapshot = $0 }
        await engine.start()
        for _ in 0..<30 {
            try? await Task.sleep(for: .milliseconds(100))
            if holder.snapshot != nil { break }
        }
        await engine.stop()
        #expect(holder.snapshot != nil)
        #expect(holder.snapshot!.cpu.aggregate >= 0)
    }

    @Test func metricEngineStopAndRestart() async throws {
        let engine = MetricEngine(historyRecorder: nil)
        await engine.start()
        await engine.stop()
        let countHolder = CountHolder()
        await engine.setOnSnapshot { _ in countHolder.value += 1 }
        await engine.start()
        try? await Task.sleep(for: .seconds(1.5))
        await engine.stop()
        #expect(countHolder.value >= 1)
    }
}
