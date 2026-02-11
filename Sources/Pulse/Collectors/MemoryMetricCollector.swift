// MemoryMetricCollector.swift
// Pulse — macOS system monitor

import Foundation
import Darwin
import os

private let memoryLogger = Logger(subsystem: "com.pulse.app", category: "Memory")

public actor MemoryMetricCollector: MetricCollecting {
    public typealias Metric = MemoryMetric

    public init() {}

    public func currentUsage() async throws -> MemoryMetric {
        let host = mach_host_self()
        var vmStats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let kr = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else {
            memoryLogger.error("host_statistics64 failed: \(kr)")
            throw MetricCollectionError.syscallFailed(errno: Int32(kr))
        }

        let pageSize = UInt64(sysconf(_SC_PAGESIZE))
        let free = UInt64(vmStats.free_count) * pageSize
        let active = UInt64(vmStats.active_count) * pageSize
        let inactive = UInt64(vmStats.inactive_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        let used = active + inactive + wired + compressed
        let total = ProcessInfo.processInfo.physicalMemory
        var swapUsed: UInt64 = 0
        var size = 0
        if sysctlbyname("vm.swapusage", nil, &size, nil, 0) == 0, size > 0 {
            var swap = xsw_usage()
            if sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 {
                swapUsed = swap.xsu_used
            }
        }
        let pressure = memoryPressureLevel()
        let now = Date()
        return MemoryMetric(
            used: used,
            free: free,
            total: total,
            swap: swapUsed,
            pressure: pressure,
            timestamp: now
        )
    }

    private func memoryPressureLevel() -> MemoryPressure {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_level", &level, &size, nil, 0) == 0 {
            if level >= 90 { return .critical }
            if level >= 70 { return .warning }
        }
        return .nominal
    }
}
