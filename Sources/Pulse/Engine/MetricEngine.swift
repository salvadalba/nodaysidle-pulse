// MetricEngine.swift
// Pulse — macOS system monitor

import Foundation
import SwiftData
import os

private let engineLogger = Logger(subsystem: "com.pulse.app", category: "MetricEngine")
private let signposter = OSSignposter(logger: Logger(subsystem: "com.pulse.app", category: "MetricEngine"))

public actor MetricEngine {
    private let cpu = CPUMetricCollector()
    private let memory = MemoryMetricCollector()
    private let gpu = GPUMetricCollector()
    private let disk = DiskMetricCollector()
    private let network = NetworkMetricCollector()

    nonisolated(unsafe) public var onSnapshot: (@Sendable (MetricSnapshot) -> Void)?
    public var tickInterval: TimeInterval = 1.0

    public func setOnSnapshot(_ handler: @Sendable @escaping (MetricSnapshot) -> Void) {
        onSnapshot = handler
    }

    public func setTickInterval(_ interval: TimeInterval) {
        tickInterval = max(0.25, min(5, interval))
    }

    private var task: Task<Void, Never>?
    private var lastSnapshot: MetricSnapshot?
    private var failureCount: [MetricType: Int] = [:]
    private let historyRecorder: HistoryRecorder?

    public init(historyRecorder: HistoryRecorder? = nil) {
        self.historyRecorder = historyRecorder
    }

    public func start() async {
        guard task == nil else { return }
        task = Task {
            while !Task.isCancelled {
                let id = signposter.beginInterval("tick")
                defer { signposter.endInterval("tick", id) }
                let snapshot = await collectSnapshot()
                lastSnapshot = snapshot
                onSnapshot?(snapshot)
                await pushToHistory(snapshot)
                try? await Task.sleep(for: .seconds(tickInterval))
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    public func consecutiveFailureCount(for type: MetricType) -> Int {
        failureCount[type] ?? 0
    }

    private func collectSnapshot() async -> MetricSnapshot {
        let now = Date()
        let prev = lastSnapshot

        async let cpuResult: CPUMetric = collectCPU(prev: prev)
        async let memoryResult: MemoryMetric = collectMemory(prev: prev)
        async let gpuResult: GPUMetric = collectGPU(prev: prev)
        async let diskResult: [DiskMetric] = collectDisk(prev: prev)
        async let networkResult: [NetworkMetric] = collectNetwork(prev: prev)

        let cpu = await cpuResult
        let memory = await memoryResult
        let gpu = await gpuResult
        let disks = await diskResult
        let network = await networkResult

        return MetricSnapshot(cpu: cpu, memory: memory, gpu: gpu, disks: disks, network: network, timestamp: now)
    }

    private func collectCPU(prev: MetricSnapshot?) async -> CPUMetric {
        do {
            let m = try await cpu.currentUsage()
            failureCount[.cpu] = 0
            return m
        } catch {
            failureCount[.cpu, default: 0] += 1
            engineLogger.error("CPU collector failed: \(error.localizedDescription)")
            return prev?.cpu ?? CPUMetric(aggregate: 0, perCore: [], timestamp: Date())
        }
    }

    private func collectMemory(prev: MetricSnapshot?) async -> MemoryMetric {
        do {
            let m = try await memory.currentUsage()
            failureCount[.memory] = 0
            return m
        } catch {
            failureCount[.memory, default: 0] += 1
            engineLogger.error("Memory collector failed: \(error.localizedDescription)")
            let t = ProcessInfo.processInfo.physicalMemory
            return prev?.memory ?? MemoryMetric(used: 0, free: t, total: t, swap: 0, pressure: .nominal, timestamp: Date())
        }
    }

    private func collectGPU(prev: MetricSnapshot?) async -> GPUMetric {
        do {
            let m = try await gpu.currentUsage()
            failureCount[.gpu] = 0
            return m
        } catch {
            failureCount[.gpu, default: 0] += 1
            engineLogger.error("GPU collector failed: \(error.localizedDescription)")
            return prev?.gpu ?? GPUMetric(utilization: 0, vramUsed: 0, vramTotal: 1, temperature: nil, timestamp: Date())
        }
    }

    private func collectDisk(prev: MetricSnapshot?) async -> [DiskMetric] {
        do {
            let m = try await disk.currentUsage()
            failureCount[.disk] = 0
            return m
        } catch {
            failureCount[.disk, default: 0] += 1
            engineLogger.error("Disk collector failed: \(error.localizedDescription)")
            return prev?.disks ?? []
        }
    }

    private func collectNetwork(prev: MetricSnapshot?) async -> [NetworkMetric] {
        do {
            let m = try await network.currentUsage()
            failureCount[.network] = 0
            return m
        } catch {
            failureCount[.network, default: 0] += 1
            engineLogger.error("Network collector failed: \(error.localizedDescription)")
            return prev?.network ?? []
        }
    }

    private func pushToHistory(_ snapshot: MetricSnapshot) async {
        guard let recorder = historyRecorder else { return }
        let t = snapshot.timestamp
        var records: [MetricSampleRecord] = [
            MetricSampleRecord(timestamp: t, metricType: .cpu, value: snapshot.cpu.aggregate),
            MetricSampleRecord(timestamp: t, metricType: .memory, value: Double(snapshot.memory.used) / Double(max(1, snapshot.memory.total)) * 100),
            MetricSampleRecord(timestamp: t, metricType: .gpu, value: snapshot.gpu.utilization)
        ]
        if let d = snapshot.disks.first(where: { $0.mountPoint == "/" }) ?? snapshot.disks.first {
            let pct = d.totalBytes > 0 ? Double(d.usedBytes) / Double(d.totalBytes) * 100 : 0
            records.append(MetricSampleRecord(timestamp: t, metricType: .disk, value: pct))
        }
        let netTotal = snapshot.network.reduce(0.0) { $0 + $1.bytesInPerSec + $1.bytesOutPerSec }
        records.append(MetricSampleRecord(timestamp: t, metricType: .network, value: netTotal))
        await recorder.record(records)
    }
}
