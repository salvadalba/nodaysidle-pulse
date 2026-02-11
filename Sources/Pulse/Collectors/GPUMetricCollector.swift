// GPUMetricCollector.swift
// Pulse — macOS system monitor

import Foundation
import IOKit
import os

private let gpuLogger = Logger(subsystem: "com.pulse.app", category: "GPU")

public actor GPUMetricCollector: MetricCollecting {
    public typealias Metric = GPUMetric

    public init() {}

    public func currentUsage() async throws -> GPUMetric {
        let now = Date()
        guard let matching = IOServiceMatching("IOAccelerator") as NSDictionary? as CFDictionary? else {
            throw MetricCollectionError.propertyNotFound("IOServiceMatching")
        }
        var iter = io_iterator_t()
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter)
        guard kr == KERN_SUCCESS else {
            gpuLogger.error("IOServiceGetMatchingServices failed: \(kr)")
            throw MetricCollectionError.ioKitError(kern_return_t: kr)
        }
        defer { IOObjectRelease(iter) }

        var utilization: Double = 0
        var vramUsed: UInt64 = 0
        var vramTotal: UInt64 = 0
        var temperature: Double? = nil

        while case let entry = IOIteratorNext(iter), entry != IO_OBJECT_NULL {
            defer { IOObjectRelease(entry) }
            var dict: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(entry, &dict, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let props = dict?.takeRetainedValue() as? [String: Any] else { continue }
            if let ps = props["PerformanceStatistics"] as? [String: Any] {
                if let v = ps["Device Utilization %"] as? Int { utilization = max(utilization, Double(v)) }
                else if let v = ps["Device Utilization %"] as? Double { utilization = max(utilization, v) }
                if let v = ps["Renderer Utilization %"] as? Int { utilization = max(utilization, Double(v)) }
                if let v = ps["VRAM Used"] as? Int { vramUsed = UInt64(v) }
                if let v = ps["VRAM Used"] as? Int64 { vramUsed = UInt64(max(0, v)) }
                if let v = ps["VRAM Total"] as? Int { vramTotal = max(vramTotal, UInt64(v)) }
                if let v = ps["VRAM Total"] as? Int64 { vramTotal = max(vramTotal, UInt64(max(0, v))) }
            }
            if let temp = props["Temperature"] as? Double { temperature = temp }
        }

        if vramTotal == 0 { vramTotal = 1 }
        return GPUMetric(
            utilization: min(100, max(0, utilization)),
            vramUsed: vramUsed,
            vramTotal: vramTotal,
            temperature: temperature,
            timestamp: now
        )
    }
}
