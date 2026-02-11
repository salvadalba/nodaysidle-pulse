// MetricTypes.swift
// Pulse — macOS system monitor

import Foundation
import Darwin

// MARK: - Metric Type

public enum MetricType: String, Codable, CaseIterable, Sendable {
    case cpu
    case memory
    case gpu
    case disk
    case network
}

// MARK: - Comparison Operator

public enum ComparisonOperator: String, Codable, Sendable {
    case greaterThan
    case lessThan
}

// MARK: - Memory Pressure

public enum MemoryPressure: String, Codable, Sendable {
    case nominal
    case warning
    case critical
}

// MARK: - Metric Collection Error

public enum MetricCollectionError: Error, Sendable {
    case permissionDenied
    case syscallFailed(errno: Int32)
    case ioKitError(kern_return_t: kern_return_t)
    case propertyNotFound(String)
}

// MARK: - CPU Metric

public struct CPUMetric: Sendable {
    public let aggregate: Double
    public let perCore: [Double]
    public let timestamp: Date

    public init(aggregate: Double, perCore: [Double], timestamp: Date) {
        self.aggregate = aggregate
        self.perCore = perCore
        self.timestamp = timestamp
    }
}

// MARK: - Memory Metric

public struct MemoryMetric: Sendable {
    public let used: UInt64
    public let free: UInt64
    public let total: UInt64
    public let swap: UInt64
    public let pressure: MemoryPressure
    public let timestamp: Date

    public init(used: UInt64, free: UInt64, total: UInt64, swap: UInt64, pressure: MemoryPressure, timestamp: Date) {
        self.used = used
        self.free = free
        self.total = total
        self.swap = swap
        self.pressure = pressure
        self.timestamp = timestamp
    }
}

// MARK: - GPU Metric

public struct GPUMetric: Sendable {
    public let utilization: Double
    public let vramUsed: UInt64
    public let vramTotal: UInt64
    public let temperature: Double?
    public let timestamp: Date

    public init(utilization: Double, vramUsed: UInt64, vramTotal: UInt64, temperature: Double?, timestamp: Date) {
        self.utilization = utilization
        self.vramUsed = vramUsed
        self.vramTotal = vramTotal
        self.temperature = temperature
        self.timestamp = timestamp
    }
}

// MARK: - Disk Metric

public struct DiskMetric: Sendable {
    public let mountPoint: String
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let availableBytes: UInt64
    public let timestamp: Date

    public init(mountPoint: String, totalBytes: UInt64, usedBytes: UInt64, availableBytes: UInt64, timestamp: Date) {
        self.mountPoint = mountPoint
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.availableBytes = availableBytes
        self.timestamp = timestamp
    }
}

// MARK: - Network Metric

public struct NetworkMetric: Sendable {
    public let interface: String
    public let bytesIn: UInt64
    public let bytesOut: UInt64
    public let bytesInPerSec: Double
    public let bytesOutPerSec: Double
    public let timestamp: Date

    public init(interface: String, bytesIn: UInt64, bytesOut: UInt64, bytesInPerSec: Double, bytesOutPerSec: Double, timestamp: Date) {
        self.interface = interface
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.bytesInPerSec = bytesInPerSec
        self.bytesOutPerSec = bytesOutPerSec
        self.timestamp = timestamp
    }
}
