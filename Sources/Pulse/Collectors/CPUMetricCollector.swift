// CPUMetricCollector.swift
// Pulse — macOS system monitor

import Foundation
import Darwin
import os

private let cpuLogger = Logger(subsystem: "com.pulse.app", category: "CPU")

public actor CPUMetricCollector: MetricCollecting {
    public typealias Metric = CPUMetric

    private var previousLoad: (ticks: [Int32], count: Int)?

    public init() {}

    public func currentUsage() async throws -> CPUMetric {
        var numCpus: natural_t = 0
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0

        let host = mach_host_self()
        let kr = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &numCpus, &cpuInfo, &numCpuInfo)
        guard kr == KERN_SUCCESS else {
            cpuLogger.error("host_processor_info failed: \(kr)")
            throw MetricCollectionError.syscallFailed(errno: Int32(kr))
        }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(Int(numCpuInfo) * MemoryLayout<integer_t>.size)) }

        let count = Int(numCpus)
        let stride = Int(CPU_STATE_MAX)
        var perCore: [Double] = []
        var totalUser: UInt64 = 0, totalSystem: UInt64 = 0, totalIdle: UInt64 = 0, totalNice: UInt64 = 0

        for i in 0..<count {
            let base = i * stride
            let user = UInt64(cpuInfo[base + Int(CPU_STATE_USER)])
            let system = UInt64(cpuInfo[base + Int(CPU_STATE_SYSTEM)])
            let idle = UInt64(cpuInfo[base + Int(CPU_STATE_IDLE)])
            let nice = UInt64(cpuInfo[base + Int(CPU_STATE_NICE)])
            totalUser += user
            totalSystem += system
            totalIdle += idle
            totalNice += nice
            let total = user + system + idle + nice
            let usage: Double = total > 0 ? (Double(user + system + nice) / Double(total)) * 100 : 0
            perCore.append(min(100, max(0, usage)))
        }

        let now = Date()
        let aggregate: Double
        if let prev = previousLoad, prev.count == count * stride {
            let totalPrev = prev.ticks
            var sumUsed: Int64 = 0, sumTotal: Int64 = 0
            for i in 0..<count {
                let base = i * stride
                let user = Int64(cpuInfo[base + Int(CPU_STATE_USER)])
                let system = Int64(cpuInfo[base + Int(CPU_STATE_SYSTEM)])
                let idle = Int64(cpuInfo[base + Int(CPU_STATE_IDLE)])
                let nice = Int64(cpuInfo[base + Int(CPU_STATE_NICE)])
                let pu = Int64(totalPrev[base + Int(CPU_STATE_USER)])
                let ps = Int64(totalPrev[base + Int(CPU_STATE_SYSTEM)])
                let pi = Int64(totalPrev[base + Int(CPU_STATE_IDLE)])
                let pn = Int64(totalPrev[base + Int(CPU_STATE_NICE)])
                sumUsed += (user - pu) + (system - ps) + (nice - pn)
                sumTotal += (user - pu) + (system - ps) + (idle - pi) + (nice - pn)
            }
            aggregate = sumTotal > 0 ? min(100, max(0, (Double(sumUsed) / Double(sumTotal)) * 100)) : (perCore.isEmpty ? 0 : perCore.reduce(0, +) / Double(perCore.count))
        } else {
            aggregate = perCore.isEmpty ? 0 : min(100, perCore.reduce(0, +) / Double(perCore.count))
        }

        var ticks: [Int32] = []
        for i in 0..<count {
            let base = i * stride
            for j in 0..<stride { ticks.append(cpuInfo[base + j]) }
        }
        previousLoad = (ticks, count * stride)

        return CPUMetric(aggregate: aggregate, perCore: perCore, timestamp: now)
    }
}
