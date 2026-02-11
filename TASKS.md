# Tasks Plan — Pulse

## 📌 Global Assumptions
- Target is macOS 15 (Sequoia) or later only
- Solo developer workflow with SwiftPM (no Xcode project file)
- Swift 6 strict concurrency mode enabled from the start
- Apple Silicon is the primary target; Intel support is best-effort
- No external dependencies — all functionality uses Apple frameworks
- CloudKit sync is optional and disabled by default
- GPU metrics may be limited on some hardware configurations

## ⚠️ Risks
- IOKit APIs for GPU metrics are not publicly documented and may change between macOS versions
- App sandbox may restrict access to some Mach/IOKit system APIs needed for metric collection
- Metal shader behavior may differ between Apple Silicon GPU generations
- host_processor_info and host_statistics64 Mach APIs may require special entitlements in future macOS versions
- SwiftData performance for high-frequency writes (1Hz x 5 metrics) needs validation
- Memory pressure API access may be restricted in sandboxed apps

## 🧩 Epics
## Project Scaffolding
**Goal:** Set up the SwiftPM project structure, targets, and base app entry point

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Create SwiftPM package and app target (S)

Initialize a SwiftPM-based macOS app with Package.swift, main app target, and test target. Set minimum deployment target to macOS 15. Configure Swift 6 language mode with strict concurrency.

**Acceptance Criteria**
- Package.swift compiles with swift build
- App target runs and shows an empty window
- Test target runs with swift test
- Swift 6 strict concurrency enabled

**Dependencies**
_None_

### ✅ Define PulseApp entry point with scene structure (S)

Create @main PulseApp struct with WindowGroup for the dashboard, MenuBarExtra placeholder, and Settings placeholder. Configure ModelContainer with empty schema for now.

**Acceptance Criteria**
- App launches with an empty main window
- Menu bar icon appears (static placeholder)
- Settings window opens from app menu
- ModelContainer initializes without errors

**Dependencies**
- Create SwiftPM package and app target

### ✅ Define all data model types and enums (S)

Create MetricType enum, ComparisonOperator enum, MemoryPressure enum. Create all Sendable metric structs: CPUMetric, MemoryMetric, GPUMetric, DiskMetric, NetworkMetric, MetricSnapshot. Create AlertEvent struct. Create MetricCollectionError enum.

**Acceptance Criteria**
- All types compile with Sendable conformance
- MetricType is CaseIterable and Codable
- MetricCollectionError has cases for permissionDenied, syscallFailed, ioKitError, propertyNotFound
- Unit test verifies Codable round-trip for MetricType

**Dependencies**
- Create SwiftPM package and app target

### ✅ Define SwiftData models (S)

Create @Model classes: MetricSample (id, timestamp, metricType, value, metadata), DashboardLayout (id, cardOrder, expandedCardId), AlertThreshold (id, metricType, op, value, enabled). Add compound index on (metricType, timestamp) for MetricSample.

**Acceptance Criteria**
- ModelContainer initializes with all three schemas
- MetricSample can be inserted and fetched by predicate
- DashboardLayout singleton can be created and updated
- AlertThreshold can be seeded with defaults

**Dependencies**
- Define all data model types and enums

### ✅ Register SwiftData schemas in PulseApp ModelContainer (S)

Wire MetricSample, DashboardLayout, and AlertThreshold into ModelContainer in PulseApp. Configure MetricSample to exclude from CloudKit sync. Configure DashboardLayout and AlertThreshold for optional CloudKit sync.

**Acceptance Criteria**
- App launches with ModelContainer containing all three schemas
- Inserting and querying each model type works
- CloudKit config set correctly (MetricSample excluded)

**Dependencies**
- Define SwiftData models
- Define PulseApp entry point with scene structure

## CPU Metric Collection
**Goal:** Collect real-time CPU usage data via Mach APIs in a dedicated actor

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Define MetricCollecting protocol (XS)

Create protocol MetricCollecting with Actor constraint, associatedtype Metric: Sendable, and async throwing currentUsage() method.

**Acceptance Criteria**
- Protocol compiles under Swift 6 strict concurrency
- Can be adopted by an actor with a concrete Metric type

**Dependencies**
- Define all data model types and enums

### ✅ Implement CPUMetricCollector actor (M)

Create actor CPUMetricCollector conforming to MetricCollecting. Call host_processor_info() via Mach API to read per-core CPU ticks. Compute aggregate and per-core usage percentages by comparing current ticks to previous sample. Cache previous ticks for delta calculation.

**Acceptance Criteria**
- currentUsage() returns CPUMetric with aggregate between 0-100
- perCore array has one entry per logical core
- Calling currentUsage() twice with delay shows different values
- Throws MetricCollectionError.syscallFailed on Mach API failure
- No data races under Swift 6 strict concurrency

**Dependencies**
- Define MetricCollecting protocol

### ✅ Write unit tests for CPUMetricCollector (S)

Test that CPUMetricCollector returns valid data. Test aggregate is within 0-100 range. Test perCore count matches ProcessInfo.processInfo.processorCount. Test consecutive calls produce different timestamps.

**Acceptance Criteria**
- All tests pass on macOS 15
- Tests verify value ranges
- Tests verify array sizes

**Dependencies**
- Implement CPUMetricCollector actor

## Memory Metric Collection
**Goal:** Collect real-time memory usage via Mach VM statistics

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement MemoryMetricCollector actor (M)

Create actor MemoryMetricCollector conforming to MetricCollecting. Call host_statistics64() to read vm_statistics64_data_t. Compute used, free, total, swap from page counts and vm_page_size. Map memory pressure from dispatch_source memorypressure or kern.memorystatus_level sysctl.

**Acceptance Criteria**
- currentUsage() returns MemoryMetric with used + free approximately equal to total
- total matches ProcessInfo.processInfo.physicalMemory
- pressure returns a valid MemoryPressure case
- Throws MetricCollectionError.syscallFailed on failure

**Dependencies**
- Define MetricCollecting protocol

### ✅ Write unit tests for MemoryMetricCollector (S)

Test that total matches system physical memory. Test used > 0. Test used <= total. Test pressure is a valid enum case.

**Acceptance Criteria**
- All tests pass
- Values are within expected ranges

**Dependencies**
- Implement MemoryMetricCollector actor

## GPU Metric Collection
**Goal:** Collect GPU utilization and VRAM usage via IOKit

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement GPUMetricCollector actor (L)

Create actor GPUMetricCollector conforming to MetricCollecting. Use IOServiceMatching for IOAccelerator to find GPU services. Read PerformanceStatistics dictionary for utilization and VRAM properties. Handle Macs without discrete GPUs by reading integrated GPU stats.

**Acceptance Criteria**
- currentUsage() returns GPUMetric with utilization between 0-100
- vramUsed <= vramTotal
- Works on Apple Silicon Macs (integrated GPU)
- Throws MetricCollectionError.ioKitError on IOKit failure
- temperature is optional (nil if unavailable)

**Dependencies**
- Define MetricCollecting protocol

### ✅ Write unit tests for GPUMetricCollector (S)

Test utilization is within 0-100. Test vramTotal > 0. Test function does not crash on the current hardware.

**Acceptance Criteria**
- Tests pass on Apple Silicon Mac
- Values are within expected ranges

**Dependencies**
- Implement GPUMetricCollector actor

## Disk Metric Collection
**Goal:** Collect disk usage statistics for mounted volumes

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement DiskMetricCollector actor (M)

Create actor DiskMetricCollector conforming to MetricCollecting (Metric = [DiskMetric]). Use statfs() or statvfs() to read mounted volume stats. Filter to relevant volumes (exclude devfs, autofs, etc).

**Acceptance Criteria**
- currentUsage() returns at least one DiskMetric for the root volume
- usedBytes + availableBytes approximately equals totalBytes
- mountPoint is a valid path string
- Throws MetricCollectionError.syscallFailed on failure

**Dependencies**
- Define MetricCollecting protocol

### ✅ Write unit tests for DiskMetricCollector (S)

Test root volume is present. Test totalBytes > 0. Test usedBytes <= totalBytes.

**Acceptance Criteria**
- Tests pass
- Root volume data is valid

**Dependencies**
- Implement DiskMetricCollector actor

## Network Metric Collection
**Goal:** Collect per-interface network throughput via sysctl

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement NetworkMetricCollector actor (M)

Create actor NetworkMetricCollector conforming to MetricCollecting (Metric = [NetworkMetric]). Use getifaddrs() and sysctl NET_RT_IFLIST2 to read per-interface byte counters. Cache previous sample to compute bytesInPerSec and bytesOutPerSec as deltas. Filter to active interfaces (en0, en1, etc).

**Acceptance Criteria**
- currentUsage() returns at least one NetworkMetric
- bytesIn and bytesOut are cumulative counters >= 0
- bytesInPerSec and bytesOutPerSec are >= 0
- Second call with 1s delay shows meaningful per-second rates
- Throws MetricCollectionError.syscallFailed on failure

**Dependencies**
- Define MetricCollecting protocol

### ✅ Write unit tests for NetworkMetricCollector (S)

Test at least one interface is returned. Test cumulative counters are non-negative. Test delta rates are non-negative after two calls.

**Acceptance Criteria**
- Tests pass
- Values are within expected ranges

**Dependencies**
- Implement NetworkMetricCollector actor

## Metric Engine
**Goal:** Orchestrate all collectors into a unified polling loop

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement MetricEngine actor (L)

Create actor MetricEngine that owns all five collector actors. Use a Task with infinite loop and Task.sleep(for: .seconds(1)) for 1Hz tick. On each tick, use TaskGroup to poll all collectors in parallel. Assemble MetricSnapshot from results. Expose onSnapshot callback. Implement start() and stop() methods.

**Acceptance Criteria**
- MetricEngine produces MetricSnapshot at ~1Hz
- All five metric types are populated in snapshot
- Individual collector failure does not crash the tick
- stop() cancels the polling task cleanly
- start() after stop() resumes polling
- No data races under Swift 6

**Dependencies**
- Implement CPUMetricCollector actor
- Implement MemoryMetricCollector actor
- Implement GPUMetricCollector actor
- Implement DiskMetricCollector actor
- Implement NetworkMetricCollector actor

### ✅ Handle per-collector errors in MetricEngine (M)

When a collector throws in the TaskGroup, catch the error, log it via os.Logger, and use the previous snapshot value for that metric type. Track consecutive failure count per collector. Expose failure state for UI to show warning badges.

**Acceptance Criteria**
- A throwing collector does not prevent other collectors from completing
- Previous value is used when a collector fails
- Consecutive failure count is tracked
- Errors are logged with os.Logger at .error level

**Dependencies**
- Implement MetricEngine actor

### ✅ Write integration test for MetricEngine (M)

Test that MetricEngine produces a complete MetricSnapshot within 2 seconds of start(). Test that stopping and restarting works. Test that snapshot contains all metric types.

**Acceptance Criteria**
- Integration test passes
- Snapshot arrives within 2 seconds
- All metric types are present in snapshot

**Dependencies**
- Implement MetricEngine actor

### ✅ Add os.Logger and os_signpost instrumentation (S)

Add os.Logger with subsystem com.pulse.app and categories per module (MetricEngine, CPU, Memory, GPU, Disk, Network). Add os_signpost intervals for MetricEngine tick duration. Add debug-level logs for each tick.

**Acceptance Criteria**
- Logs appear in Console.app filtered by subsystem
- Signpost intervals visible in Instruments
- Each module has its own log category

**Dependencies**
- Implement MetricEngine actor

## Dashboard UI
**Goal:** Build the main dashboard grid with metric cards and sparkline charts

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement CardViewModel (M)

Create @MainActor @Observable CardViewModel class. Hold metricType, currentValue, formatted display string, and a fixed-size ring buffer of 60 Doubles for sparkline data. Implement update(from:) to extract the relevant value from MetricSnapshot and push into ring buffer.

**Acceptance Criteria**
- Ring buffer holds exactly 60 values
- Oldest value is dropped when buffer is full
- currentValue and sparklineBuffer update correctly from MetricSnapshot
- Formatted display shows appropriate units (%, GB, MB/s)

**Dependencies**
- Define all data model types and enums

### ✅ Implement DashboardViewModel (M)

Create @MainActor @Observable DashboardViewModel. Initialize with one CardViewModel per MetricType. Implement moveCard(from:to:) for reordering. Implement toggleExpand(_:) to set/clear expandedCardId. Wire MetricEngine onSnapshot to distribute values to card view models.

**Acceptance Criteria**
- cards array has 5 entries on init
- moveCard reorders the array correctly
- toggleExpand toggles expandedCardId
- Snapshot distribution updates all card view models

**Dependencies**
- Implement CardViewModel
- Implement MetricEngine actor

### ✅ Implement SparklineChartView with Canvas (M)

Create SparklineChartView that takes [Double] data points. Use Canvas to draw a smooth line path connecting data points. Scale Y-axis to min-max of data. Use strokeStyle with round line join for smooth appearance. Accept a gradient color pair for the line.

**Acceptance Criteria**
- Chart renders a smooth line from data points
- Chart scales Y-axis appropriately
- Empty data shows nothing (no crash)
- Single data point shows a dot

**Dependencies**
_None_

### ✅ Implement MetricCardView (M)

Create MetricCardView that displays metric name, current formatted value, and SparklineChartView. Use .background with RoundedRectangle and .ultraThinMaterial. Accept Namespace.ID for matchedGeometryEffect. Show metric icon appropriate to type.

**Acceptance Criteria**
- Card shows metric name and value
- Sparkline chart is visible
- Card has material background with rounded corners
- matchedGeometryEffect ID is set correctly

**Dependencies**
- Implement SparklineChartView with Canvas
- Implement CardViewModel

### ✅ Implement DashboardView with LazyVGrid (M)

Create DashboardView with LazyVGrid layout. Render MetricCardView for each card in DashboardViewModel. Use adaptive columns with minimum width of 300pt. Apply .ultraThinMaterial to window background via NSWindow customization.

**Acceptance Criteria**
- Dashboard shows all 5 metric cards in a grid
- Cards reflow on window resize
- Window has material background
- Cards update live from MetricEngine data

**Dependencies**
- Implement MetricCardView
- Implement DashboardViewModel

### ✅ Add PhaseAnimator entry animations (S)

Apply PhaseAnimator to MetricCardView for staggered appearance on launch. Cards should fade in and slide up with a slight delay between each card.

**Acceptance Criteria**
- Cards animate in on app launch
- Animation is staggered (not all at once)
- Animation completes within 1 second

**Dependencies**
- Implement DashboardView with LazyVGrid

### ✅ Add shimmer placeholder while awaiting first data (S)

Show placeholder shimmer cards before first MetricSnapshot arrives. Use PhaseAnimator or redacted(reason: .placeholder) modifier. Remove placeholders once first snapshot populates card view models.

**Acceptance Criteria**
- Placeholder cards are visible on launch
- Shimmer animation plays
- Placeholders are replaced by real data within ~1 second

**Dependencies**
- Implement DashboardView with LazyVGrid

### ✅ Customize NSWindow for premium appearance (S)

Use NSWindow customization to set titlebar appearance, title visibility, and toolbar style. Set window background to .ultraThinMaterial. Set minimum window size.

**Acceptance Criteria**
- Window has customized titlebar
- Background is translucent material
- Window cannot be resized below minimum size

**Dependencies**
- Implement DashboardView with LazyVGrid

## Metal Shaders
**Goal:** Add Metal-powered animated gradient backgrounds to charts

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Create ChartGradient.metal shader (M)

Write a Metal fragment shader that produces a smooth animated gradient. Accept uniforms: float time (for animation), half4 colorA, half4 colorB. Animate gradient angle or color blend based on time. Output per-pixel color.

**Acceptance Criteria**
- Shader compiles without errors
- Gradient animates smoothly over time
- Colors blend between colorA and colorB
- No visual artifacts

**Dependencies**
_None_

### ✅ Integrate Metal shader via ShaderLibrary (M)

Access ChartGradient shader via ShaderLibrary.chartGradient. Apply to SparklineChartView background using .visualEffect or .layerEffect modifier. Pass TimelineView .animation date as time uniform. Define per-metric-type color pairs.

**Acceptance Criteria**
- Each metric card has a unique gradient color pair
- Gradient animates smoothly at display refresh rate
- Shader renders correctly on Apple Silicon
- No performance degradation (GPU usage stays low)

**Dependencies**
- Create ChartGradient.metal shader
- Implement SparklineChartView with Canvas

## Drag and Drop
**Goal:** Allow users to rearrange dashboard cards by dragging

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Add drag-and-drop to DashboardView (M)

Add .draggable and .dropDestination modifiers to MetricCardView in DashboardView. On drop, call DashboardViewModel.moveCard(from:to:). Apply move animation.

**Acceptance Criteria**
- Cards can be dragged and dropped to new positions
- Card order updates visually during drag
- Animation is smooth during reorder
- Non-dragged cards shift smoothly to accommodate

**Dependencies**
- Implement DashboardView with LazyVGrid

### ✅ Persist card order to SwiftData (M)

On card reorder, save the new cardOrder array to DashboardLayout in SwiftData. On app launch, read DashboardLayout and restore card order. Create DashboardLayout singleton on first launch with default order.

**Acceptance Criteria**
- Reordered card positions persist across app restart
- Default order is MetricType.allCases order
- Write to SwiftData does not block UI thread

**Dependencies**
- Add drag-and-drop to DashboardView
- Register SwiftData schemas in PulseApp ModelContainer

## Card Expansion and Detail View
**Goal:** Clicking a card expands it to a detailed view with historical data

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement DetailView (M)

Create DetailView that shows an expanded metric card with a full-width SparklineChartView. Display min, max, and average statistics. Accept Namespace.ID for matchedGeometryEffect animation from card.

**Acceptance Criteria**
- Detail view shows large chart
- Min/max/avg stats are displayed
- matchedGeometryEffect animates transition from card

**Dependencies**
- Implement SparklineChartView with Canvas
- Implement CardViewModel

### ✅ Add time range selector to DetailView (M)

Add a segmented control or picker with time range options: 1h, 6h, 24h, 7d, 30d. Selecting a range triggers a history query and updates the chart data.

**Acceptance Criteria**
- All five time ranges are selectable
- Chart data updates when range changes
- Selected range is visually indicated
- Default range is 1h

**Dependencies**
- Implement DetailView
- Implement HistoryRecorder query method

### ✅ Wire card expansion in DashboardView (M)

When a MetricCardView is tapped, toggle DashboardViewModel.expandedCardId. If expanded, replace the card grid with DetailView using matchedGeometryEffect animation. Tapping again or pressing Escape collapses back to grid.

**Acceptance Criteria**
- Tapping a card expands to detail view
- matchedGeometryEffect provides smooth transition
- Tapping again or pressing Escape collapses
- Only one card can be expanded at a time

**Dependencies**
- Implement DetailView
- Implement DashboardView with LazyVGrid

### ✅ Load historical data in CardViewModel (M)

Implement loadHistory() async in CardViewModel. Query HistoryRecorder for the selected date range and metricType. Populate historicalData array. Call from DetailView on appear and on range change.

**Acceptance Criteria**
- Historical data loads when detail view appears
- Data updates when time range changes
- Loading state is shown while fetching
- Empty state shown if no history exists

**Dependencies**
- Implement HistoryRecorder query method
- Implement CardViewModel

## History Recording
**Goal:** Persist metric samples to SwiftData for historical charts

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement HistoryRecorder ModelActor (M)

Create @ModelActor actor HistoryRecorder. Implement record(_ samples:) that accumulates MetricSample values in a buffer and commits to ModelContext every 5 seconds or 50 samples, whichever comes first.

**Acceptance Criteria**
- Samples are batched before writing
- Batch commits every 5 seconds or 50 samples
- MetricSample records appear in SwiftData store
- No main thread blocking

**Dependencies**
- Define SwiftData models

### ✅ Implement HistoryRecorder query method (S)

Implement query(metricType:range:) in HistoryRecorder. Use SwiftData FetchDescriptor with predicate filtering by metricType and timestamp within DateInterval. Return results sorted by timestamp ascending.

**Acceptance Criteria**
- Query returns samples matching type and date range
- Results are sorted by timestamp ascending
- Empty result returns empty array
- Query does not block UI

**Dependencies**
- Implement HistoryRecorder ModelActor

### ✅ Implement HistoryRecorder prune method (S)

Implement prune(olderThan:) in HistoryRecorder. Use SwiftData predicate delete to remove all MetricSample records with timestamp before the given date. Call on app launch for records older than 30 days.

**Acceptance Criteria**
- Records older than cutoff date are deleted
- Uses predicate delete (no fetch-then-delete loop)
- Runs on app launch without blocking UI
- Logs number of pruned records

**Dependencies**
- Implement HistoryRecorder ModelActor

### ✅ Wire MetricEngine to HistoryRecorder (S)

In MetricEngine onSnapshot callback, convert MetricSnapshot to [MetricSample] (one per metric type) and send to HistoryRecorder.record(). Ensure samples are created with correct metricType and value.

**Acceptance Criteria**
- Each tick produces 5 MetricSample records
- Samples have correct metricType values
- Samples accumulate in SwiftData over time

**Dependencies**
- Implement MetricEngine actor
- Implement HistoryRecorder ModelActor

### ✅ Add os_signpost to HistoryRecorder batch writes (XS)

Add os_signpost interval for each batch commit in HistoryRecorder. Log batch size and commit duration. Target < 10ms per batch.

**Acceptance Criteria**
- Signpost intervals visible in Instruments
- Batch write duration is logged
- Typical batch commit is under 10ms

**Dependencies**
- Implement HistoryRecorder ModelActor

## Alert System
**Goal:** Notify users when metrics exceed configured thresholds

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement AlertEvaluator (S)

Create struct AlertEvaluator with evaluate(_ snapshot:thresholds:) method. Compare each metric's current value against matching AlertThreshold records. Support greaterThan and lessThan operators. Return [AlertEvent] for all breached thresholds.

**Acceptance Criteria**
- Returns AlertEvent when CPU exceeds threshold
- Returns empty array when no thresholds breached
- Handles both greaterThan and lessThan operators
- Skips disabled thresholds
- Pure function with no side effects

**Dependencies**
- Define all data model types and enums

### ✅ Write unit tests for AlertEvaluator (S)

Test threshold comparison for boundary values. Test CPU at exactly 90% does not trigger > 90. Test CPU at 90.1% triggers > 90. Test disabled thresholds are skipped. Test multiple thresholds can fire simultaneously.

**Acceptance Criteria**
- Boundary value tests pass
- Disabled threshold test passes
- Multiple simultaneous alerts test passes

**Dependencies**
- Implement AlertEvaluator

### ✅ Implement AlertNotifier (M)

Create @MainActor AlertNotifier class. Implement notify(_ events:) that posts UNUserNotification for each AlertEvent. Request notification permission on first invocation. Debounce: suppress re-notification for the same metricType within 60 seconds.

**Acceptance Criteria**
- Notification appears for alert event
- Permission is requested before first notification
- Same metric does not re-notify within 60 seconds
- Different metrics can notify independently
- Notification shows metric type and current value

**Dependencies**
- Implement AlertEvaluator

### ✅ Seed default AlertThreshold records (S)

On first app launch, seed AlertThreshold records: CPU > 90% (enabled), disk > 95% (enabled). Check if thresholds exist before seeding to avoid duplicates.

**Acceptance Criteria**
- Default thresholds exist after first launch
- Re-launching does not create duplicates
- CPU threshold is 90 with greaterThan operator
- Disk threshold is 95 with greaterThan operator

**Dependencies**
- Register SwiftData schemas in PulseApp ModelContainer

### ✅ Wire AlertEvaluator and AlertNotifier to MetricEngine (M)

In MetricEngine onSnapshot, call AlertEvaluator.evaluate with current snapshot and fetched AlertThreshold records. Pass resulting events to AlertNotifier.notify(). Fetch thresholds from SwiftData.

**Acceptance Criteria**
- Alerts fire when thresholds are breached
- Notifications appear on macOS
- Alert evaluation runs every tick
- No performance impact on tick loop

**Dependencies**
- Implement AlertNotifier
- Implement MetricEngine actor
- Seed default AlertThreshold records

### ✅ Show alert badge on metric cards (S)

When a metric's threshold is currently breached, show a small warning badge icon on the MetricCardView. Read alert state from the most recent AlertEvaluator result.

**Acceptance Criteria**
- Warning badge appears on card when threshold breached
- Badge disappears when value drops below threshold
- Badge uses SF Symbol exclamationmark.triangle
- Badge animates in/out

**Dependencies**
- Wire AlertEvaluator and AlertNotifier to MetricEngine
- Implement MetricCardView

## Menu Bar
**Goal:** Show a live CPU sparkline in the macOS menu bar

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement MenuBarView with live CPU sparkline (M)

Create MenuBarView using MenuBarExtra scene. Use TimelineView with .animation schedule to redraw at display refresh rate. Use Canvas to draw a 22x16pt sparkline of the CPU CardViewModel's sparklineBuffer. Stroke a thin line path.

**Acceptance Criteria**
- Menu bar icon shows a live sparkline
- Sparkline updates at ~1Hz with new CPU data
- Sparkline is 22x16pt (fits menu bar)
- Drawing is efficient (trivial Canvas path)

**Dependencies**
- Implement CardViewModel
- Define PulseApp entry point with scene structure

### ✅ Add menu bar dropdown with quick stats (M)

Add a dropdown panel to MenuBarExtra showing current values for all 5 metrics. Include a button to open/bring forward the main window.

**Acceptance Criteria**
- Dropdown shows all 5 metric values
- Values update live
- Open Main Window button focuses the main window
- Dropdown has clean layout with labels and values

**Dependencies**
- Implement MenuBarView with live CPU sparkline
- Implement DashboardViewModel

## Settings
**Goal:** Provide user-configurable settings for thresholds, polling, and sync

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement SettingsView (M)

Create SettingsView with sections: Alert Thresholds (list of thresholds with value fields and enable toggles), Polling Interval (picker: 0.5Hz, 1Hz, 2Hz), History Retention (picker: 7 days, 30 days, 90 days), CloudKit Sync (toggle on/off). Use Form layout with GroupBox sections.

**Acceptance Criteria**
- Settings window shows all four sections
- Threshold values can be edited and saved to SwiftData
- Threshold enable/disable toggle works
- Polling interval selection is persisted
- All controls use SwiftUI native components

**Dependencies**
- Register SwiftData schemas in PulseApp ModelContainer
- Seed default AlertThreshold records

### ✅ Apply polling interval setting to MetricEngine (S)

Read polling interval from UserDefaults or SwiftData. Pass to MetricEngine as tick interval. Update MetricEngine when setting changes without restarting the app.

**Acceptance Criteria**
- Changing polling interval changes tick frequency
- 1Hz, 2Hz, and 0.5Hz all work correctly
- Setting persists across app restart
- MetricEngine updates without restart

**Dependencies**
- Implement SettingsView
- Implement MetricEngine actor

### ✅ Apply history retention setting to pruning (S)

Read history retention setting and use it as the prune threshold in HistoryRecorder.prune() on app launch instead of hardcoded 30 days.

**Acceptance Criteria**
- Retention setting affects prune behavior
- 7-day, 30-day, and 90-day options all work
- Setting persists across app restart

**Dependencies**
- Implement SettingsView
- Implement HistoryRecorder prune method

## Collector Error UI
**Goal:** Surface collector failures to the user in the dashboard

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Show warning badge on cards with consecutive collector failures (S)

When MetricEngine reports 3+ consecutive failures for a collector, show a warning indicator on the corresponding MetricCardView. Use a different badge than the alert badge (e.g., exclamationmark.circle). Show tooltip or popover explaining the error on hover.

**Acceptance Criteria**
- Warning badge appears after 3+ consecutive failures
- Badge is distinct from alert threshold badge
- Hovering shows error explanation
- Badge disappears when collector recovers

**Dependencies**
- Handle per-collector errors in MetricEngine
- Implement MetricCardView

## Testing and Polish
**Goal:** Comprehensive testing and final polish before distribution

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Write integration test for alert flow (M)

Test end-to-end: inject a MetricSnapshot with CPU at 95%, verify AlertEvaluator returns an AlertEvent, verify AlertNotifier would post a notification (mock UNUserNotificationCenter).

**Acceptance Criteria**
- Test verifies alert is triggered for CPU > 90%
- Test verifies debounce suppresses repeat within 60s
- Test passes

**Dependencies**
- Wire AlertEvaluator and AlertNotifier to MetricEngine

### ✅ Write integration test for history record and query (M)

Test batch write of 50 MetricSample records. Test query by metricType and date range returns correct results. Test prune removes old records.

**Acceptance Criteria**
- Batch write test passes
- Query test returns correct filtered results
- Prune test deletes only old records

**Dependencies**
- Wire MetricEngine to HistoryRecorder

### ✅ Write E2E test for app launch to live dashboard (M)

Launch app programmatically. Verify all 5 metric cards display non-zero values within 2 seconds. Use XCUITest or similar.

**Acceptance Criteria**
- Test launches app and verifies 5 cards exist
- All cards show non-zero values within 2 seconds
- Test passes reliably

**Dependencies**
- Implement DashboardView with LazyVGrid
- Implement MetricEngine actor

### ✅ Profile with Instruments and optimize (M)

Run Time Profiler, Allocations, and Metal System Trace instruments. Verify MetricEngine tick completes in < 50ms. Verify no memory leaks. Verify Metal shader GPU usage is minimal. Fix any issues found.

**Acceptance Criteria**
- Tick duration < 50ms
- No memory leaks detected
- GPU usage is minimal
- App uses < 50MB resident memory steady state

**Dependencies**
- Implement DashboardView with LazyVGrid
- Integrate Metal shader via ShaderLibrary

### ✅ Configure app sandbox entitlements (S)

Add com.apple.security.app-sandbox entitlement. Verify all metric collectors work within sandbox. Add any required temporary exceptions if needed for IOKit or Mach APIs.

**Acceptance Criteria**
- App runs in sandbox mode
- All metric collectors still function
- No sandbox violations in Console logs

**Dependencies**
- Implement MetricEngine actor

### ✅ Set up code signing and notarization (M)

Configure Apple Developer ID signing. Set up notarization via xcrun notarytool. Create a build script that archives, signs, notarizes, and staples the app. Package as .dmg.

**Acceptance Criteria**
- App is signed with Developer ID
- App passes notarization
- DMG can be distributed and opened without Gatekeeper warnings

**Dependencies**
- Configure app sandbox entitlements

## ❓ Open Questions
- Should GPU metric collection fall back gracefully on Macs with no discrete GPU, or should the GPU card be hidden entirely?
- What specific Metal gradient animation style is desired — should colors shift over time, react to metric value, or both?
- Should the 30-day history retention be configurable by the user, or fixed?
- For network metrics, should all interfaces be shown individually or aggregated into a single total?
- Should CloudKit sync include alert notification history, or only layout and thresholds?
- What should the app do when running on battery — reduce polling frequency to save power, or maintain 1Hz?