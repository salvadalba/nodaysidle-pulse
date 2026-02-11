# Pulse

## 🎯 Product Vision
A beautiful, local-first macOS system monitor that presents real-time hardware metrics through stunning Metal-powered visualizations, making performance monitoring feel effortless and visually delightful.

## ❓ Problem Statement
Existing macOS system monitors are either ugly terminal utilities, bloated Electron apps, or lack real-time visual feedback. Users who care about their system's health deserve a native, performant, and visually rich tool that runs entirely on-device without phoning home.

## 🎯 Goals
- Display real-time CPU, memory, GPU, disk, and network statistics with sub-second refresh rates
- Render animated sparkline charts with Metal shader gradient backgrounds for a premium visual experience
- Provide a draggable dashboard grid where users can rearrange metric cards to their preference
- Support card expansion from summary sparkline to detailed historical view with matchedGeometryEffect transitions
- Run a persistent menu bar icon showing a live miniature CPU graph via TimelineView
- Alert users when critical thresholds are breached (CPU > 90%, disk > 95%) via native macOS notifications
- Persist layout preferences and historical metric data locally using SwiftData
- Maintain zero network dependency — fully local-first architecture with no server required

## 🚫 Non-Goals
- Remote monitoring of other machines or network devices
- Cloud-based dashboards or web interface
- Process management or killing processes
- Integration with third-party monitoring services (Datadog, Grafana, etc.)
- Cross-platform support for iOS, iPadOS, or Windows
- AI-powered anomaly detection or predictive analytics
- Plugin or extension system

## 👥 Target Users
- macOS power users and developers who want at-a-glance system health visibility
- Professionals running resource-intensive workloads (ML training, video editing, compiling) who need threshold alerts
- Design-conscious users who want a system monitor that matches the aesthetic quality of macOS

## 🧩 Core Features
- [object Object]
- [object Object]
- [object Object]
- [object Object]
- [object Object]
- [object Object]
- [object Object]

## ⚙️ Non-Functional Requirements
- CPU overhead of the app itself must stay below 3% during normal dashboard monitoring
- Metric refresh rate of at least 1Hz for all sensors, with TimelineView driving smooth visual interpolation
- App launch to dashboard visible in under 1 second on Apple Silicon Macs
- All data collection and storage is local-first with no network calls unless CloudKit sync is explicitly enabled
- Metal shader rendering must maintain 60fps on all supported Apple Silicon GPUs
- SwiftData historical storage must handle 30 days of per-second samples without exceeding 500MB
- macOS 15+ (Sequoia) minimum deployment target
- NSWindow customization for .ultraThinMaterial backgrounds and premium window chrome
- Swift 6 strict concurrency compliance — no data races, full Sendable conformance

## 📊 Success Metrics
- Dashboard renders all five metric cards with live data within 1 second of launch
- Metal shader animations sustain 60fps with total app CPU usage under 3%
- Card drag-to-rearrange completes with persisted layout in under 100ms
- Card expansion/collapse animation runs at 60fps using matchedGeometryEffect
- Threshold alert notification fires within 2 seconds of a metric breaching its limit
- Menu bar CPU graph updates at least once per second with accurate readings
- SwiftData write operations for metric samples complete in under 10ms per batch

## 📌 Assumptions
- The app runs on Apple Silicon Macs with macOS 15+ (Sequoia) where Metal 3 is available
- System metric APIs (host_processor_info, IOKit, sysctl) provide sufficient data without requiring elevated privileges
- GPU metrics are accessible via IOKit or Metal system info without requiring admin permissions
- Users are comfortable granting Accessibility or monitoring permissions if required by macOS
- SwiftData with CloudKit sync is stable enough for production use on macOS 15
- Metal shaders can be applied to SwiftUI chart views via .visualEffect or .layerEffect modifiers

## ❓ Open Questions
- Which specific system APIs should be used for GPU metrics — IOKit, Metal performance counters, or both?
- Should disk metrics cover all mounted volumes or only the boot volume by default?
- What is the optimal data sampling interval for balancing historical granularity vs. storage size?
- Should the menu bar popover support the same drag-to-rearrange behavior as the main dashboard?
- How should the app handle permission denial for system metrics that require entitlements?
- Should alert thresholds be per-core for CPU or aggregate only?
- What pruning strategy for historical data — rolling window, downsampling older data, or user-configurable?