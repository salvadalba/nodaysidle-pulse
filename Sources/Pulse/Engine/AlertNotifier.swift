// AlertNotifier.swift
// Pulse — macOS system monitor

import Foundation
import UserNotifications
import os

private let notifierLogger = Logger(subsystem: "com.pulse.app", category: "Alerts")

@MainActor
public final class AlertNotifier {
    private var lastFired: [MetricType: Date] = [:]
    private let debounceSeconds: TimeInterval = 60
    private var didRequestPermission = false

    public init() {}

    public func notify(_ events: [AlertEvent]) async {
        if !didRequestPermission {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            didRequestPermission = true
            if !granted { notifierLogger.info("Notification permission denied") }
        }
        for event in events {
            let last = lastFired[event.metricType]
            if let last, Date().timeIntervalSince(last) < debounceSeconds { continue }
            lastFired[event.metricType] = Date()
            let content = UNMutableNotificationContent()
            content.title = "Pulse: \(event.metricType.rawValue.capitalized)"
            content.body = String(format: "%.1f%% (threshold: %.0f%%)", event.currentValue, event.thresholdValue)
            content.sound = .default
            let request = UNNotificationRequest(identifier: "pulse-\(event.metricType.rawValue)-\(UUID().uuidString)", content: content, trigger: nil)
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                notifierLogger.error("Failed to post notification: \(error.localizedDescription)")
            }
        }
    }
}
