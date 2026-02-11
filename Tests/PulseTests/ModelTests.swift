// ModelTests.swift
// Pulse — unit tests for model types and SwiftData models

import Testing
import Foundation
import SwiftData
@testable import Pulse

// MARK: - MetricType Codable Round-Trip

struct MetricTypeCodableTests {
    @Test func metricTypeCodableRoundTrip() throws {
        for type in MetricType.allCases {
            let encoded = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(MetricType.self, from: encoded)
            #expect(decoded == type)
        }
    }

    @Test func metricTypeRawValues() {
        #expect(MetricType.cpu.rawValue == "cpu")
        #expect(MetricType.memory.rawValue == "memory")
        #expect(MetricType.gpu.rawValue == "gpu")
        #expect(MetricType.disk.rawValue == "disk")
        #expect(MetricType.network.rawValue == "network")
    }
}

// MARK: - SwiftData Model Insertion and Fetch

struct SwiftDataModelTests {
    @Test func modelContainerInitializesWithAllSchemas() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MetricSample.self, DashboardLayout.self, AlertThreshold.self,
            configurations: config
        )
        #expect(container.schema.entities.count >= 3)
    }

    @Test func metricSampleInsertAndFetch() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MetricSample.self, DashboardLayout.self, AlertThreshold.self,
            configurations: config
        )
        let context = ModelContext(container)
        let sample = MetricSample(
            timestamp: Date(),
            metricType: .cpu,
            value: 42.0,
            metadata: ["key": "value"]
        )
        context.insert(sample)
        try context.save()

        let desc = FetchDescriptor<MetricSample>(
            predicate: #Predicate<MetricSample> { $0.metricType == "cpu" }
        )
        let fetched = try context.fetch(desc)
        #expect(fetched.count == 1)
        #expect(fetched[0].value == 42.0)
        #expect(fetched[0].metricTypeEnum == MetricType.cpu)
    }

    @Test func dashboardLayoutSingletonCreateAndUpdate() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MetricSample.self, DashboardLayout.self, AlertThreshold.self,
            configurations: config
        )
        let context = ModelContext(container)
        let order: [MetricType] = [.network, .cpu, .memory, .gpu, .disk]
        let layout = DashboardLayout(cardOrder: order, expandedCardId: .memory)
        context.insert(layout)
        try context.save()

        let desc = FetchDescriptor<DashboardLayout>()
        let fetched = try context.fetch(desc)
        #expect(fetched.count == 1)
        #expect(fetched[0].cardOrder == order)
        #expect(fetched[0].expandedCardId == MetricType.memory)
    }

    @Test func alertThresholdSeededWithDefaults() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MetricSample.self, DashboardLayout.self, AlertThreshold.self,
            configurations: config
        )
        let context = ModelContext(container)
        let cpu = AlertThreshold(metricType: .cpu, op: .greaterThan, value: 90, enabled: true)
        let disk = AlertThreshold(metricType: .disk, op: .greaterThan, value: 95, enabled: true)
        context.insert(cpu)
        context.insert(disk)
        try context.save()

        let desc = FetchDescriptor<AlertThreshold>()
        let fetched = try context.fetch(desc)
        #expect(fetched.count == 2)
        let cpuThreshold = fetched.first { $0.metricType == MetricType.cpu }
        let diskThreshold = fetched.first { $0.metricType == MetricType.disk }
        #expect(cpuThreshold?.value == 90)
        #expect(cpuThreshold?.op == .greaterThan)
        #expect(diskThreshold?.value == 95)
        #expect(diskThreshold?.op == .greaterThan)
    }
}
