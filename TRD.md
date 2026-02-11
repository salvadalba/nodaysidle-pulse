# Technical Requirements Document

## 🧭 System Context
Pulse is a native macOS 15+ system monitor app built with SwiftUI 6 and Swift 6 strict concurrency. It displays real-time CPU, memory, GPU, disk, and network metrics as animated sparkline cards in a draggable dashboard grid. Metal shaders render smooth gradient backgrounds on charts. A menu bar icon shows a live miniature CPU sparkline via TimelineView. The app is fully local-first with no server dependency, using SwiftData for persistence and optional CloudKit sync for layout/thresholds only. All metric collection runs via Swift actors with structured concurrency.

## 🔌 API Contracts
### CPUMetricCollector.currentUsage
- **Method:** async func
- **Path:** CPUMetricCollector.currentUsage() async -> CPUMetric
- **Auth:** none — in-process actor call
- **Request:** No parameters. Reads host_processor_info() via Mach API.
- **Response:** CPUMetric { aggregate: Double, perCore: [Double], timestamp: Date }
- **Errors:** MetricCollectionError.permissionDenied, MetricCollectionError.syscallFailed(errno: Int32)

### MemoryMetricCollector.currentUsage
- **Method:** async func
- **Path:** MemoryMetricCollector.currentUsage() async -> MemoryMetric
- **Auth:** none — in-process actor call
- **Request:** No parameters. Reads host_statistics64() for VM info.
- **Response:** MemoryMetric { used: UInt64, free: UInt64, total: UInt64, swap: UInt64, pressure: MemoryPressure, timestamp: Date }
- **Errors:** MetricCollectionError.syscallFailed(errno: Int32)

### GPUMetricCollector.currentUsage
- **Method:** async func
- **Path:** GPUMetricCollector.currentUsage() async -> GPUMetric
- **Auth:** none — in-process actor call, IOKit access
- **Request:** No parameters. Reads IOKit IOAccelerator dictionary via IOServiceMatching.
- **Response:** GPUMetric { utilization: Double, vramUsed: UInt64, vramTotal: UInt64, temperature: Double?, timestamp: Date }
- **Errors:** MetricCollectionError.ioKitError(kern_return_t), MetricCollectionError.propertyNotFound(String)

### DiskMetricCollector.currentUsage
- **Method:** async func
- **Path:** DiskMetricCollector.currentUsage() async -> [DiskMetric]
- **Auth:** none — in-process actor call
- **Request:** No parameters. Reads statfs() for all mounted volumes.
- **Response:** [DiskMetric] where DiskMetric { mountPoint: String, totalBytes: UInt64, usedBytes: UInt64, availableBytes: UInt64, timestamp: Date }
- **Errors:** MetricCollectionError.syscallFailed(errno: Int32)

### NetworkMetricCollector.currentUsage
- **Method:** async func
- **Path:** NetworkMetricCollector.currentUsage() async -> [NetworkMetric]
- **Auth:** none — in-process actor call
- **Request:** No parameters. Reads getifaddrs() and sysctl NET_RT_IFLIST2 for per-interface byte counters.
- **Response:** [NetworkMetric] where NetworkMetric { interface: String, bytesIn: UInt64, bytesOut: UInt64, bytesInPerSec: Double, bytesOutPerSec: Double, timestamp: Date }
- **Errors:** MetricCollectionError.syscallFailed(errno: Int32)

### AlertEvaluator.evaluate
- **Method:** func
- **Path:** AlertEvaluator.evaluate(_ snapshot: MetricSnapshot) -> [AlertEvent]
- **Auth:** none — in-process call
- **Request:** MetricSnapshot containing latest values for all metric types plus the active [AlertThreshold] from SwiftData.
- **Response:** [AlertEvent] where AlertEvent { threshold: AlertThreshold, currentValue: Double, timestamp: Date }

### HistoryRecorder.record
- **Method:** async func
- **Path:** HistoryRecorder.record(_ samples: [MetricSample]) async
- **Auth:** none — in-process ModelActor call
- **Request:** [MetricSample] batch to persist. Typically 5 samples per tick (one per metric type).
- **Response:** Void. Writes are batched and committed to SwiftData ModelContext.
- **Errors:** SwiftData.ModelError

### HistoryRecorder.query
- **Method:** async func
- **Path:** HistoryRecorder.query(metricType: MetricType, range: DateInterval) async -> [MetricSample]
- **Auth:** none — in-process ModelActor call
- **Request:** metricType: MetricType enum, range: DateInterval for the query window.
- **Response:** [MetricSample] sorted by timestamp ascending.
- **Errors:** SwiftData.ModelError

### HistoryRecorder.prune
- **Method:** async func
- **Path:** HistoryRecorder.prune(olderThan: Date) async
- **Auth:** none — in-process ModelActor call
- **Request:** olderThan: Date. Deletes all MetricSample records with timestamp before this date.
- **Response:** Void.
- **Errors:** SwiftData.ModelError

## 🧱 Modules
### MetricCollectors
- **Responsibilities:**
- Poll system APIs at 1Hz for CPU, memory, GPU, disk, and network metrics
- Return typed Sendable metric structs
- Isolate all syscall/IOKit work in dedicated actors to prevent data races
- Compute delta-based rates (e.g. network bytes/sec) by caching previous sample
- **Interfaces:**
- protocol MetricCollecting: Actor { associatedtype Metric: Sendable; func currentUsage() async throws -> Metric }
- actor CPUMetricCollector: MetricCollecting
- actor MemoryMetricCollector: MetricCollecting
- actor GPUMetricCollector: MetricCollecting
- actor DiskMetricCollector: MetricCollecting
- actor NetworkMetricCollector: MetricCollecting

### MetricEngine
- **Responsibilities:**
- Orchestrate all collectors via a single Task with TaskGroup for parallel reads
- Publish aggregated MetricSnapshot to DashboardViewModel at each tick
- Feed AlertEvaluator with each snapshot
- Feed HistoryRecorder with batched samples
- Manage tick interval (default 1Hz) and lifecycle (start/stop on app activate/deactivate)
- **Interfaces:**
- actor MetricEngine { func start() async; func stop(); var onSnapshot: @Sendable (MetricSnapshot) -> Void }
- **Dependencies:**
- MetricCollectors
- AlertEvaluator
- HistoryRecorder

### AlertEvaluator
- **Responsibilities:**
- Compare current metric values against user-configured AlertThreshold records
- Return triggered AlertEvent values for the engine to act on
- No state — pure function evaluation against thresholds
- **Interfaces:**
- struct AlertEvaluator { func evaluate(_ snapshot: MetricSnapshot, thresholds: [AlertThreshold]) -> [AlertEvent] }

### AlertNotifier
- **Responsibilities:**
- Post UNUserNotification for each AlertEvent
- Debounce notifications — suppress re-fire for the same metric within 60 seconds
- Request notification permission on first alert
- **Interfaces:**
- @MainActor final class AlertNotifier { func notify(_ events: [AlertEvent]) async }
- **Dependencies:**
- AlertEvaluator

### HistoryRecorder
- **Responsibilities:**
- Persist MetricSample records to SwiftData via a background ModelActor
- Batch writes — accumulate samples and commit every 5 seconds or 50 samples
- Query historical samples by metric type and date range for detail views
- Prune samples older than 30 days on app launch
- **Interfaces:**
- @ModelActor actor HistoryRecorder { func record(_ samples: [MetricSample]) async; func query(metricType: MetricType, range: DateInterval) async -> [MetricSample]; func prune(olderThan: Date) async }

### DashboardViewModel
- **Responsibilities:**
- Hold the array of CardViewModel instances — one per metric type
- Manage card order and expanded card state
- Persist layout changes to SwiftData DashboardLayout on drop
- Receive MetricSnapshot from MetricEngine and distribute values to card view models
- **Interfaces:**
- @MainActor @Observable final class DashboardViewModel { var cards: [CardViewModel]; var expandedCardId: MetricType?; func moveCard(from: IndexSet, to: Int); func toggleExpand(_ type: MetricType) }
- **Dependencies:**
- MetricEngine
- HistoryRecorder

### CardViewModel
- **Responsibilities:**
- Hold current value, formatted display string, and sparkline ring buffer (60 samples) for one metric
- Provide data points array for SparklineChartView
- Load historical data from HistoryRecorder when card is expanded
- **Interfaces:**
- @MainActor @Observable final class CardViewModel: Identifiable { let metricType: MetricType; var currentValue: Double; var sparklineBuffer: [Double]; var historicalData: [MetricSample]; func update(from snapshot: MetricSnapshot); func loadHistory() async }
- **Dependencies:**
- HistoryRecorder

### DashboardView
- **Responsibilities:**
- Render a LazyVGrid of MetricCardViews
- Support drag-and-drop reordering via onMove and draggable/dropDestination modifiers
- Animate card expansion/collapse with matchedGeometryEffect
- Apply PhaseAnimator for card entry animations on launch
- **Interfaces:**
- struct DashboardView: View { @State var viewModel: DashboardViewModel }
- **Dependencies:**
- DashboardViewModel
- MetricCardView
- DetailView

### MetricCardView
- **Responsibilities:**
- Display metric name, current value, and a SparklineChartView
- Apply Metal gradient shader background via .visualEffect modifier
- Participate in matchedGeometryEffect namespace for expansion animation
- Show alert badge icon when threshold is breached
- **Interfaces:**
- struct MetricCardView: View { let viewModel: CardViewModel; let namespace: Namespace.ID }
- **Dependencies:**
- SparklineChartView
- CardViewModel

### SparklineChartView
- **Responsibilities:**
- Render an animated line chart from an array of Double values using Swift Charts or Canvas
- Update smoothly via TimelineView at display refresh rate with interpolation between 1Hz data points
- Apply Metal shader as chart background gradient via ShaderLibrary
- **Interfaces:**
- struct SparklineChartView: View { let dataPoints: [Double]; let gradientShader: Shader }

### DetailView
- **Responsibilities:**
- Show expanded metric card with full-width chart and historical data
- Provide time range selector (1h, 6h, 24h, 7d, 30d)
- Display min/max/avg statistics for the selected range
- Animate in via matchedGeometryEffect from the card
- **Interfaces:**
- struct DetailView: View { let viewModel: CardViewModel; let namespace: Namespace.ID }
- **Dependencies:**
- CardViewModel
- SparklineChartView

### MenuBarView
- **Responsibilities:**
- Render a tiny live CPU sparkline in the macOS menu bar via MenuBarExtra
- Use TimelineView with Canvas to draw a 16pt-tall sparkline at 1Hz
- Provide a dropdown with quick stats and a button to open the main window
- **Interfaces:**
- struct MenuBarView: Scene { @State var viewModel: CardViewModel }
- **Dependencies:**
- CardViewModel

### SettingsView
- **Responsibilities:**
- Configure alert thresholds per metric type
- Toggle CloudKit sync on/off
- Set polling interval (1Hz, 2Hz, 0.5Hz)
- Set history retention period
- **Interfaces:**
- struct SettingsView: View

### MetalShaders
- **Responsibilities:**
- Provide .metal shader files for animated gradient backgrounds
- Expose shaders via ShaderLibrary for use in .visualEffect and .layerEffect modifiers
- Accept uniform parameters: time (for animation), color stops, intensity
- **Interfaces:**
- ChartGradient.metal — fragment shader accepting float time, half4 colorA, half4 colorB
- ShaderLibrary.chartGradient(time:colorA:colorB:) accessed in SwiftUI

### PulseApp
- **Responsibilities:**
- App entry point with @main
- Configure ModelContainer with MetricSample, DashboardLayout, AlertThreshold schemas
- Initialize MetricEngine and DashboardViewModel
- Declare WindowGroup for DashboardView, MenuBarExtra for MenuBarView, Settings for SettingsView
- **Interfaces:**
- @main struct PulseApp: App { var body: some Scene }
- **Dependencies:**
- DashboardView
- MenuBarView
- SettingsView
- MetricEngine
- HistoryRecorder

## 🗃 Data Model Notes
- @Model final class MetricSample { var id: UUID; var timestamp: Date; var metricType: MetricType; var value: Double; var metadata: [String: String]; init(...) } — indexed on (metricType, timestamp). Append-only, pruned at 30 days.

- @Model final class DashboardLayout { var id: UUID; var cardOrder: [MetricType]; var expandedCardId: MetricType? } — singleton record, created on first launch.

- @Model final class AlertThreshold { var id: UUID; var metricType: MetricType; var op: ComparisonOperator; var value: Double; var enabled: Bool } — one per metric type, seeded with defaults (CPU > 90%, disk > 95%).

- enum MetricType: String, Codable, CaseIterable, Sendable { case cpu, memory, gpu, disk, network }

- enum ComparisonOperator: String, Codable, Sendable { case greaterThan, lessThan }

- struct CPUMetric: Sendable { let aggregate: Double; let perCore: [Double]; let timestamp: Date }

- struct MemoryMetric: Sendable { let used: UInt64; let free: UInt64; let total: UInt64; let swap: UInt64; let pressure: MemoryPressure; let timestamp: Date }

- enum MemoryPressure: String, Sendable { case nominal, warning, critical }

- struct GPUMetric: Sendable { let utilization: Double; let vramUsed: UInt64; let vramTotal: UInt64; let temperature: Double?; let timestamp: Date }

- struct DiskMetric: Sendable { let mountPoint: String; let totalBytes: UInt64; let usedBytes: UInt64; let availableBytes: UInt64; let timestamp: Date }

- struct NetworkMetric: Sendable { let interface: String; let bytesIn: UInt64; let bytesOut: UInt64; let bytesInPerSec: Double; let bytesOutPerSec: Double; let timestamp: Date }

- struct MetricSnapshot: Sendable { let cpu: CPUMetric; let memory: MemoryMetric; let gpu: GPUMetric; let disks: [DiskMetric]; let network: [NetworkMetric]; let timestamp: Date }

- struct AlertEvent: Sendable { let threshold: AlertThreshold; let currentValue: Double; let timestamp: Date }

- CloudKit sync enabled only for DashboardLayout and AlertThreshold via ModelConfiguration. MetricSample excluded from sync to avoid bandwidth and storage costs.

## 🔐 Validation & Security
- All metric collector actors validate Mach/IOKit return codes before processing results. Invalid kern_return_t values throw MetricCollectionError rather than returning garbage data.
- AlertThreshold values are validated on save: value must be within sensible ranges per metric type (e.g. CPU 0–100, disk 0–100). ComparisonOperator is an enum — no string injection possible.
- No network calls unless CloudKit sync is explicitly enabled. No URLs fetched, no external APIs called. Attack surface is limited to local Mach/IOKit/sysctl APIs.
- App is sandboxed with com.apple.security.app-sandbox entitlement. SwiftData container is stored in the app sandbox container.
- No user-provided string interpolation into syscalls. All system API calls use typed parameters.
- Notification content contains only metric type name and value — no user-controlled strings in notification body.
- Code-signed and notarized via Apple Developer ID for distribution outside Mac App Store.

## 🧯 Error Handling Strategy
Metric collectors throw typed MetricCollectionError enum values. MetricEngine catches per-collector errors in TaskGroup, logs them, and continues with remaining collectors — a single collector failure does not halt the entire tick. The UI displays a small warning badge on the affected card when its collector has failed for 3+ consecutive ticks. SwiftData write errors in HistoryRecorder are logged and retried on next batch; persistent failures trigger a one-time user notification suggesting app restart. Alert notification failures (UNUserNotificationCenter errors) are logged silently — alerts are best-effort. All errors are logged via os.Logger with appropriate log levels (error for collector failures, fault for SwiftData failures, info for expected conditions).

## 🔭 Observability
- **Logging:** os.Logger with subsystem 'com.pulse.app' and per-module categories: 'MetricEngine', 'CPU', 'Memory', 'GPU', 'Disk', 'Network', 'Alerts', 'History', 'UI'. Debug-level logs for each tick and sample. Error-level for collector and persistence failures. Signpost intervals for MetricEngine tick duration and HistoryRecorder batch writes.
- **Tracing:** os_signpost used for performance-critical paths: MetricEngine tick, TaskGroup collector execution, HistoryRecorder batch commit, and Metal shader compilation. Viewable in Instruments Time Profiler and os_signpost instrument.
- **Metrics:**
- MetricEngine tick duration (os_signpost interval) — target < 50ms
- HistoryRecorder batch write duration (os_signpost interval) — target < 10ms
- Collector individual latency per type per tick
- SwiftData store size on disk (logged at app launch)
- Consecutive collector failure count per type

## ⚡ Performance Notes
- MetricEngine uses TaskGroup to poll all 5 collectors in parallel — total tick latency is max(individual collector latencies), not sum.
- SparklineChartView ring buffer is a fixed-size array of 60 Doubles (~480 bytes). No heap allocation per tick — values are shifted in-place.
- HistoryRecorder batches writes: accumulates samples in an actor-isolated array and commits to ModelContext every 5 seconds or when buffer reaches 50 samples, whichever comes first. This amortizes SwiftData transaction overhead.
- Metal shader for chart gradients accepts a time uniform and computes gradient per-fragment on GPU. No CPU-side gradient image generation.
- Menu bar Canvas rendering clips to 22x16 points. TimelineView schedules at .animation cadence but the canvas draw is trivial — single path stroke.
- Card drag-and-drop uses onMove which triggers a single array reorder + SwiftData write. The write is dispatched async to HistoryRecorder so the UI thread is not blocked.
- matchedGeometryEffect for card expansion reuses the same view identity — no view destruction/recreation during animation.
- 30-day pruning runs once on app launch in a background task. Uses a single SwiftData predicate delete — no fetch-then-delete loop.
- App launch: ModelContainer init and MetricEngine.start() run concurrently. First snapshot arrives within 1 tick (1 second). UI renders placeholder shimmer cards via PhaseAnimator until first data arrives.

## 🧪 Testing Strategy
### Unit
- CPUMetricCollector: mock host_processor_info() responses, verify aggregate/per-core calculation
- MemoryMetricCollector: mock host_statistics64() responses, verify used/free/pressure derivation
- NetworkMetricCollector: verify bytes-per-second delta calculation given two sequential samples
- AlertEvaluator: verify threshold comparison logic for >, < operators, verify no false positives at boundary values
- AlertNotifier: verify debounce logic suppresses re-notification within 60 seconds
- DashboardViewModel: verify card reorder persists correct order, verify expand/collapse toggles correctly
- CardViewModel: verify sparkline ring buffer correctly drops oldest value when full, verify history load populates historicalData
### Integration
- MetricEngine + all collectors: verify TaskGroup produces complete MetricSnapshot with all 5 metric types within 2 seconds
- MetricEngine + AlertEvaluator + AlertNotifier: inject snapshot with CPU at 95%, verify UNUserNotification is posted
- HistoryRecorder + SwiftData: verify batch write of 50 samples, verify query returns correct samples for date range, verify prune deletes old records
- DashboardViewModel + HistoryRecorder: verify card expansion triggers history load and populates detail view data
### E2E
- App launch to live dashboard: verify all 5 metric cards display non-zero values within 2 seconds of launch
- Card drag-and-drop: drag CPU card to position 3, quit and relaunch, verify CPU card is at position 3
- Card expansion: click memory card, verify detail view shows with historical chart, click again to collapse
- Menu bar: verify menu bar icon shows live CPU sparkline that updates at ~1Hz
- Alert flow: set CPU threshold to 1%, verify notification fires within 5 seconds
- Settings: change polling interval to 2Hz, verify sparkline updates at ~2Hz cadence

## 🚀 Rollout Plan
- Phase 1 — Core Metric Collection: Implement CPUMetricCollector, MemoryMetricCollector, MetricEngine with TaskGroup orchestration. Verify data flows to a simple SwiftUI Text view.

- Phase 2 — Dashboard UI: Build DashboardView with LazyVGrid, MetricCardView, SparklineChartView using Canvas. Wire CardViewModel to MetricEngine output. Implement PhaseAnimator entry animations.

- Phase 3 — Metal Shaders: Author ChartGradient.metal, integrate via ShaderLibrary in SparklineChartView .visualEffect modifier. Tune gradient colors per metric type.

- Phase 4 — Remaining Collectors: Implement GPUMetricCollector (IOKit), DiskMetricCollector (statfs), NetworkMetricCollector (getifaddrs). Add corresponding cards to dashboard.

- Phase 5 — Drag and Drop + Persistence: Add draggable/dropDestination modifiers, DashboardLayout SwiftData model, persist card order on drop.

- Phase 6 — Card Expansion + History: Implement matchedGeometryEffect expansion, HistoryRecorder ModelActor, DetailView with time range selector and historical chart.

- Phase 7 — Alerts: Implement AlertEvaluator, AlertThreshold SwiftData model, AlertNotifier with UNUserNotification and debounce. Seed default thresholds (CPU > 90%, disk > 95%).

- Phase 8 — Menu Bar: Implement MenuBarExtra with TimelineView + Canvas CPU sparkline. Add dropdown with quick stats.

- Phase 9 — Settings + Polish: Build SettingsView for thresholds, polling interval, CloudKit toggle. Add .ultraThinMaterial window background. NSWindow customization for premium chrome.

- Phase 10 — Testing + Distribution: Write unit/integration/e2e tests. Profile with Instruments. Archive, sign, notarize, distribute as .dmg and/or Mac App Store submission.

## ❓ Open Questions
- Should GPU metric collection fall back gracefully on Macs with no discrete GPU, or should the GPU card be hidden entirely?
- What specific Metal gradient animation style is desired — should colors shift over time, react to metric value, or both?
- Should the 30-day history retention be configurable by the user, or fixed?
- For network metrics, should all interfaces be shown individually or aggregated into a single total?
- Should CloudKit sync include alert notification history, or only layout and thresholds?
- What should the app do when running on battery — reduce polling frequency to save power, or maintain 1Hz?