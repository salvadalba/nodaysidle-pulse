// DiskMetricCollector.swift
// Pulse — macOS system monitor

import Foundation
import Darwin
import os

private let diskLogger = Logger(subsystem: "com.pulse.app", category: "Disk")

public actor DiskMetricCollector: MetricCollecting {
    public typealias Metric = [DiskMetric]

    public init() {}

    public func currentUsage() async throws -> [DiskMetric] {
        let now = Date()
        var result: [DiskMetric] = []
        guard let mounts = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [], options: [.skipHiddenVolumes]) else {
            return fallbackRootVolume(now)
        }
        for url in mounts {
            let path = url.path
            guard path.hasPrefix("/") else { continue }
            var stat = statfs()
            guard statfs(path, &stat) == 0 else {
                diskLogger.debug("statfs failed for \(path): \(errno)")
                continue
            }
            let blockSize = UInt64(stat.f_bsize)
            let totalBytes = UInt64(stat.f_blocks) * blockSize
            let freeBlocks = UInt64(stat.f_bavail)
            let availableBytes = freeBlocks * blockSize
            let usedBytes = totalBytes > availableBytes ? totalBytes - availableBytes : 0
            result.append(DiskMetric(
                mountPoint: path,
                totalBytes: totalBytes,
                usedBytes: usedBytes,
                availableBytes: availableBytes,
                timestamp: now
            ))
        }
        if result.isEmpty { return fallbackRootVolume(now) }
        return result
    }

    private func fallbackRootVolume(_ now: Date) -> [DiskMetric] {
        var stat = statfs()
        guard statfs("/", &stat) == 0 else {
            diskLogger.error("statfs(/) failed: \(errno)")
            return []
        }
        let blockSize = UInt64(stat.f_bsize)
        let totalBytes = UInt64(stat.f_blocks) * blockSize
        let availableBytes = UInt64(stat.f_bavail) * blockSize
        let usedBytes = totalBytes > availableBytes ? totalBytes - availableBytes : 0
        return [DiskMetric(mountPoint: "/", totalBytes: totalBytes, usedBytes: usedBytes, availableBytes: availableBytes, timestamp: now)]
    }
}
