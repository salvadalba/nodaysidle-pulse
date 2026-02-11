// AlertFlowTests.swift
// Pulse — integration tests for alert evaluation and debounce

import Testing
import Foundation
@testable import Pulse

struct AlertFlowTests {
    @Test func alertEvaluatorReturnsEventWhenCpuAboveThreshold() async throws {
        let specs = [
            AlertThresholdSpec(metricType: .cpu, op: .greaterThan, value: 90, enabled: true)
        ]
        let cpu = CPUMetric(aggregate: 95, perCore: [95], timestamp: Date())
        let mem = MemoryMetric(used: 1, free: 1, total: 2, swap: 0, pressure: .nominal, timestamp: Date())
        let gpu = GPUMetric(utilization: 0, vramUsed: 0, vramTotal: 1, temperature: nil, timestamp: Date())
        let disk = DiskMetric(mountPoint: "/", totalBytes: 100, usedBytes: 50, availableBytes: 50, timestamp: Date())
        let net = NetworkMetric(interface: "en0", bytesIn: 0, bytesOut: 0, bytesInPerSec: 0, bytesOutPerSec: 0, timestamp: Date())
        let snapshot = MetricSnapshot(cpu: cpu, memory: mem, gpu: gpu, disks: [disk], network: [net], timestamp: Date())
        let evaluator = AlertEvaluator()
        let events = evaluator.evaluate(snapshot, thresholds: specs)
        #expect(events.count == 1)
        #expect(events[0].metricType == .cpu)
        #expect(events[0].currentValue == 95)
    }

    @Test func alertEvaluatorNoEventWhenCpuExactlyAtThreshold() {
        let specs = [
            AlertThresholdSpec(metricType: .cpu, op: .greaterThan, value: 90, enabled: true)
        ]
        let cpu = CPUMetric(aggregate: 90, perCore: [90], timestamp: Date())
        let mem = MemoryMetric(used: 1, free: 1, total: 2, swap: 0, pressure: .nominal, timestamp: Date())
        let gpu = GPUMetric(utilization: 0, vramUsed: 0, vramTotal: 1, temperature: nil, timestamp: Date())
        let snapshot = MetricSnapshot(cpu: cpu, memory: mem, gpu: gpu, disks: [], network: [], timestamp: Date())
        let events = AlertEvaluator().evaluate(snapshot, thresholds: specs)
        #expect(events.isEmpty)
    }

    @Test func alertEvaluatorSkipsDisabledThreshold() {
        let specs = [
            AlertThresholdSpec(metricType: .cpu, op: .greaterThan, value: 50, enabled: false)
        ]
        let cpu = CPUMetric(aggregate: 99, perCore: [99], timestamp: Date())
        let mem = MemoryMetric(used: 1, free: 1, total: 2, swap: 0, pressure: .nominal, timestamp: Date())
        let gpu = GPUMetric(utilization: 0, vramUsed: 0, vramTotal: 1, temperature: nil, timestamp: Date())
        let snapshot = MetricSnapshot(cpu: cpu, memory: mem, gpu: gpu, disks: [], network: [], timestamp: Date())
        let events = AlertEvaluator().evaluate(snapshot, thresholds: specs)
        #expect(events.isEmpty)
    }
}
