// NetworkMetricCollector.swift
// Pulse — macOS system monitor

import Foundation
import Darwin
import os

private let networkLogger = Logger(subsystem: "com.pulse.app", category: "Network")

public actor NetworkMetricCollector: MetricCollecting {
    public typealias Metric = [NetworkMetric]

    private var previous: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
    private var lastTime: Date?

    public init() {}

    public func currentUsage() async throws -> [NetworkMetric] {
        let now = Date()
        var iflist: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&iflist) == 0, let first = iflist else {
            networkLogger.error("getifaddrs failed: \(errno)")
            throw MetricCollectionError.syscallFailed(errno: errno)
        }
        defer { freeifaddrs(iflist) }

        var nameToBytes: [String: (in: UInt64, out: UInt64)] = [:]
        var ptr = first
        while true {
            let name = String(cString: ptr.pointee.ifa_name)
            if ptr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let ifData = ptr.pointee.ifa_data?.assumingMemoryBound(to: if_data.self)
                if let data = ifData {
                    let inBytes = UInt64(data.pointee.ifi_ibytes)
                    let outBytes = UInt64(data.pointee.ifi_obytes)
                    if nameToBytes[name] == nil { nameToBytes[name] = (0, 0) }
                    nameToBytes[name] = (inBytes, outBytes)
                }
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }

        let dt = lastTime.map { now.timeIntervalSince($0) } ?? 1.0
        let safeDt = max(0.001, dt)
        var result: [NetworkMetric] = []
        for (name, bytes) in nameToBytes.sorted(by: { $0.key < $1.key }) {
            guard !name.hasPrefix("lo") && name != "bridge" && name != "awdl" && name != "llw" else { continue }
            let prev = previous[name]
            let inPerSec: Double = prev.map { p in bytes.in >= p.bytesIn ? Double(bytes.in - p.bytesIn) / safeDt : 0 } ?? 0
            let outPerSec: Double = prev.map { p in bytes.out >= p.bytesOut ? Double(bytes.out - p.bytesOut) / safeDt : 0 } ?? 0
            result.append(NetworkMetric(
                interface: name,
                bytesIn: bytes.in,
                bytesOut: bytes.out,
                bytesInPerSec: max(0, inPerSec),
                bytesOutPerSec: max(0, outPerSec),
                timestamp: now
            ))
        }
        previous = nameToBytes.mapValues { ($0.in, $0.out) }
        lastTime = now
        if result.isEmpty {
            result.append(NetworkMetric(interface: "en0", bytesIn: 0, bytesOut: 0, bytesInPerSec: 0, bytesOutPerSec: 0, timestamp: now))
        }
        return result
    }
}
