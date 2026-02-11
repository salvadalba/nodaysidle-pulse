# Agent Prompts — Pulse

## Global Rules

### Do
- Use SwiftPM exclusively (no .xcodeproj) with Package.swift targeting macOS 15+
- Enable Swift 6 strict concurrency mode in all targets
- Use actors for all metric collectors conforming to a MetricCollecting protocol
- Use SwiftData for persistence (MetricSample, DashboardLayout, AlertThreshold)
- Use Metal shaders via ShaderLibrary for animated gradient chart backgrounds

### Don't
- Do not introduce any external dependencies — use only Apple frameworks
- Do not create a backend server — this is a local-first macOS app
- Do not use Combine or completion handlers — use async/await and Observation
- Do not target iOS or any platform other than macOS 15+
- Do not use AppKit directly except for NSWindow customization

---

## Task Prompts
### Task 1: Project Scaffold and Data Layer

**Role:** Expert Swift macOS Engineer
**Goal:** Create the SwiftPM project structure, all model types, SwiftData schemas, and PulseApp entry point

**Context**
Initialize the SwiftPM project, define all data models, SwiftData schemas, and the app entry point with MenuBarExtra and Settings scenes.

**Files to Create**
- Package.swift
- Sources/Pulse/PulseApp.swift
- Sources/Pulse/Models/MetricTypes.swift
- Sources/Pulse/Models/MetricSnapshot.swift
- Sources/Pulse/Models/SwiftDataModels.swift
- Sources/Pulse/Models/MetricCollecting.swift
- Tests/PulseTests/ModelTests.swift

**Files to Modify**
_None_

**Steps**
1. Create Package.swift with macOS 15+ deployment target, Swift 6 language mode, main app target (type: .executableTarget with SwiftUI entrypoint), and test target. Add .metal file processing support.
2. Define MetricType (cpu/memory/gpu/disk/network) as CaseIterable/Codable/Sendable enum, ComparisonOperator enum, MemoryPressure enum, and all Sendable metric structs (CPUMetric, MemoryMetric, GPUMetric, DiskMetric, NetworkMetric, MetricSnapshot, AlertEvent, MetricCollectionError).
3. Create SwiftData @Model classes: MetricSample (id, timestamp, metricType, value, metadata with compound index on metricType+timestamp), DashboardLayout (id, cardOrder, expandedCardId), AlertThreshold (id, metricType, op, value, enabled).
4. Create PulseApp @main struct with WindowGroup for dashboard, MenuBarExtra placeholder with static icon, Settings scene placeholder. Initialize ModelContainer with all three schemas. Seed default AlertThreshold records (CPU>90%, disk>95%) on first launch.
5. Define MetricCollecting protocol with Actor constraint, associatedtype Metric: Sendable, and async throwing currentUsage() method. Write unit tests for Codable round-trip and model insertion.

**Validation**
`swift build && swift test`

---

### Task 2: Metric Collectors and Engine

**Role:** Expert macOS Systems Engineer
**Goal:** Build all metric collectors, the polling engine, history recording, and alert evaluation pipeline

**Context**
Implement all five metric collector actors (CPU, Memory, GPU, Disk, Network) using Mach/IOKit/sysctl APIs, then orchestrate them in MetricEngine with 1Hz polling, error handling, and HistoryRecorder persistence.

**Files to Create**
- Sources/Pulse/Collectors/CPUMetricCollector.swift
- Sources/Pulse/Collectors/MemoryMetricCollector.swift
- Sources/Pulse/Collectors/GPUMetricCollector.swift
- Sources/Pulse/Collectors/DiskMetricCollector.swift
- Sources/Pulse/Collectors/NetworkMetricCollector.swift
- Sources/Pulse/Engine/MetricEngine.swift
- Sources/Pulse/Engine/HistoryRecorder.swift
- Sources/Pulse/Engine/AlertEvaluator.swift

**Files to Modify**
_None_

**Steps**
1. Implement CPUMetricCollector actor using host_processor_info() Mach API to read per-core CPU ticks, computing aggregate and per-core usage by comparing deltas. Implement MemoryMetricCollector actor using host_statistics64() for vm_statistics64_data_t, computing used/free/total/swap and mapping memory pressure.
2. Implement GPUMetricCollector actor using IOServiceMatching for IOAccelerator to read PerformanceStatistics (utilization, VRAM). Implement DiskMetricCollector using statfs() for mounted volumes. Implement NetworkMetricCollector using getifaddrs()/sysctl NET_RT_IFLIST2 with delta computation for per-second rates.
3. Implement MetricEngine actor that owns all five collectors, runs a Task with 1Hz polling loop using TaskGroup for parallel collection, exposes onSnapshot callback. Handle per-collector errors by catching, logging via os.Logger, using previous values, and tracking consecutive failure counts. Add os_signpost instrumentation.
4. Implement HistoryRecorder as @ModelActor that buffers MetricSample writes and commits every 5s or 50 samples. Add query(metricType:range:) with FetchDescriptor predicate and prune(olderThan:) with predicate delete. Wire MetricEngine onSnapshot to HistoryRecorder.
5. Implement AlertEvaluator struct with pure evaluate(_:thresholds:) method supporting greaterThan/lessThan operators with debounce tracking. Write unit tests for boundary values, disabled thresholds, and collector value ranges.

**Validation**
`swift build && swift test`

---

### Task 3: Dashboard UI and Metal Shaders

**Role:** Expert SwiftUI macOS Engineer
**Goal:** Build the dashboard grid, sparkline charts, Metal gradient shaders, drag-and-drop, and detail expansion views

**Context**
Build the main dashboard with metric cards, sparkline charts using Canvas, Metal animated gradient backgrounds, drag-and-drop reordering, and card expansion with detail views.

**Files to Create**
- Sources/Pulse/Views/DashboardView.swift
- Sources/Pulse/Views/MetricCardView.swift
- Sources/Pulse/Views/SparklineChartView.swift
- Sources/Pulse/Views/DetailView.swift
- Sources/Pulse/ViewModels/DashboardViewModel.swift
- Sources/Pulse/ViewModels/CardViewModel.swift
- Sources/Pulse/Shaders/ChartGradient.metal
- Sources/Pulse/Views/WindowAccessor.swift

**Files to Modify**
- Sources/Pulse/PulseApp.swift

**Steps**
1. Implement CardViewModel (@MainActor @Observable) with metricType, currentValue, formatted display string, 60-element ring buffer for sparkline data, and update(from:) method. Implement DashboardViewModel with cards array, moveCard(from:to:), toggleExpand(_:), and MetricEngine snapshot distribution.
2. Implement SparklineChartView using Canvas to draw smooth line paths with round line joins, Y-axis auto-scaling. Create ChartGradient.metal fragment shader with time/colorA/colorB uniforms for animated gradient. Integrate via ShaderLibrary.chartGradient with TimelineView .animation schedule, defining unique color pairs per MetricType.
3. Implement MetricCardView with metric name, formatted value, SparklineChartView, .ultraThinMaterial RoundedRectangle background, matchedGeometryEffect support, SF Symbol icons, alert/error warning badges. Add PhaseAnimator staggered entry animations and shimmer placeholders before first data.
4. Implement DashboardView with LazyVGrid (adaptive columns, 300pt min). Add .draggable/.dropDestination for card reordering with DashboardLayout SwiftData persistence. Implement DetailView with full-width chart, min/max/avg stats, time range selector (1h/6h/24h/7d/30d), and matchedGeometryEffect expand/collapse transitions.
5. Customize NSWindow via WindowAccessor for titlebar appearance, .ultraThinMaterial background, and minimum window size. Wire DashboardView into PulseApp WindowGroup with DashboardViewModel and MetricEngine.

**Validation**
`swift build`

---

### Task 4: Menu Bar, Alerts, and Settings

**Role:** Expert SwiftUI macOS Engineer
**Goal:** Build the menu bar sparkline, notification alerts, and settings UI with all configurable options

**Context**
Implement the menu bar live CPU sparkline, alert notification system with UNUserNotification, and the full settings view for thresholds, polling interval, and history retention.

**Files to Create**
- Sources/Pulse/Views/MenuBarView.swift
- Sources/Pulse/Engine/AlertNotifier.swift
- Sources/Pulse/Views/SettingsView.swift

**Files to Modify**
- Sources/Pulse/PulseApp.swift
- Sources/Pulse/Engine/MetricEngine.swift

**Steps**
1. Implement MenuBarView using MenuBarExtra scene with TimelineView(.animation) and Canvas drawing a 22x16pt sparkline from CPU CardViewModel's ring buffer. Add dropdown panel showing all 5 current metric values and an Open Main Window button.
2. Implement AlertNotifier (@MainActor class) that posts UNUserNotification for AlertEvents, requests permission on first use, and debounces re-notifications per metricType within 60 seconds. Wire AlertEvaluator.evaluate() and AlertNotifier.notify() into MetricEngine's onSnapshot callback.
3. Implement SettingsView with Form/GroupBox sections: Alert Thresholds (list with value fields and enable toggles bound to SwiftData), Polling Interval picker (0.5Hz/1Hz/2Hz), History Retention picker (7d/30d/90d), CloudKit Sync toggle.
4. Apply polling interval setting to MetricEngine tick duration with live update support. Apply history retention setting to HistoryRecorder.prune() on app launch. Persist settings via UserDefaults.
5. Wire MenuBarView into PulseApp MenuBarExtra scene. Update PulseApp to pass shared DashboardViewModel to both WindowGroup and MenuBarExtra. Add Settings scene with SettingsView.

**Validation**
`swift build`

---

### Task 5: Testing, Entitlements, and Distribution

**Role:** Expert macOS DevOps and Testing Engineer
**Goal:** Add integration tests, E2E tests, sandbox entitlements, code signing, notarization, and build script

**Context**
Write integration and E2E tests, configure app sandbox entitlements, set up code signing and notarization, and create the build/package script.

**Files to Create**
- Tests/PulseTests/AlertFlowTests.swift
- Tests/PulseTests/HistoryRecorderTests.swift
- Tests/PulseTests/MetricEngineTests.swift
- Sources/Pulse/Pulse.entitlements
- Scripts/build-and-notarize.sh

**Files to Modify**
- Package.swift

**Steps**
1. Write integration test for alert flow: inject MetricSnapshot with CPU at 95%, verify AlertEvaluator returns AlertEvent, verify debounce suppresses repeat within 60s. Write integration test for history: batch write 50 MetricSamples, query by metricType and date range, verify prune removes old records.
2. Write MetricEngine integration test verifying complete MetricSnapshot arrives within 2 seconds of start(), stop/restart works, and all metric types are present. Write collector unit tests verifying value ranges for all five collectors.
3. Create Pulse.entitlements with com.apple.security.app-sandbox. Test all metric collectors function within sandbox. Add any required temporary exceptions for IOKit/Mach APIs. Update Package.swift to include entitlements.
4. Create Scripts/build-and-notarize.sh that runs swift build -c release, assembles .app bundle with correct Info.plist and entitlements, signs with Developer ID via codesign, notarizes via xcrun notarytool, staples the ticket, and packages as .dmg.
5. Verify the full build pipeline: swift build succeeds, swift test passes all unit and integration tests, the build script produces a signed and notarized .dmg. Document any Instruments profiling targets (tick < 50ms, memory < 50MB, minimal GPU usage).

**Validation**
`swift build && swift test`