# Architecture Requirements Document

## 🧱 System Overview
Pulse is a native macOS 15+ system monitor app built entirely in SwiftUI 6 with Swift 6 strict concurrency. It displays real-time CPU, memory, GPU, disk, and network metrics as animated sparkline cards in a draggable dashboard grid. Metal shaders power smooth gradient backgrounds on charts. A persistent menu bar icon renders a live miniature CPU graph via TimelineView. The app is fully local-first with no server dependency, using SwiftData for persistence and optional CloudKit sync. All system metric collection runs via structured concurrency actors to guarantee thread safety and Sendable conformance.

## 🏗 Architecture Style
Single-process native macOS app using MVVM with Observation framework. Metric collection runs in dedicated Swift actors. The UI layer is purely SwiftUI 6 with Metal shader effects. Data flows unidirectionally: Actor-based collectors -> @Observable view models -> SwiftUI views. No server, no network calls, no IPC.

## 🎨 Frontend Architecture
- **Framework:** SwiftUI 6 targeting macOS 15+ (Sequoia). Uses .ultraThinMaterial and .regularMaterial for window backgrounds. matchedGeometryEffect for card expansion/collapse transitions. PhaseAnimator for card entry animations. TimelineView for continuous sparkline and menu bar graph updates at 1Hz+. NSWindow customization for premium window chrome. Metal shaders applied via .visualEffect/.layerEffect modifiers for gradient chart backgrounds.
- **State Management:** Observation framework (@Observable) for all view models. Each metric card has its own @Observable model holding current value, sparkline buffer, and historical query handle. Dashboard layout state (card order, expanded card) is @Observable and persisted to SwiftData. No Combine, no ObservableObject — pure Observation.
- **Routing:** Single-window NavigationSplitView is not needed — flat dashboard grid layout. Card expansion uses matchedGeometryEffect with a boolean toggle per card, not navigation. Settings scene via SwiftUI Settings scene. Menu bar via MenuBarExtra with TimelineView content. No router abstraction needed.
- **Build Tooling:** Swift Package Manager via Xcode. No external dependencies. Metal shader files (.metal) compiled as part of the app target. SwiftData model schema defined in-code. Single app target, no frameworks or packages beyond system frameworks.

## 🧠 Backend Architecture
- **Approach:** No server backend. All 'backend' logic runs in-process as Swift actors. A MetricsCollector actor polls system APIs at configurable intervals (default 1Hz) using structured concurrency (TaskGroup for parallel sensor reads). Each metric type (CPU, memory, GPU, disk, network) has a dedicated collector function. Results are published to @Observable view models via MainActor-isolated setters.
- **API Style:** No API. In-process Swift actor method calls. Collectors expose async methods returning typed metric structs. View models call these from structured Task scopes.
- **Services:**
- CPUMetricCollector — reads host_processor_info() for per-core and aggregate CPU usage
- MemoryMetricCollector — reads host_statistics64() for memory pressure, used, free, swap
- GPUMetricCollector — reads IOKit IOAccelerator properties for GPU utilization and VRAM
- DiskMetricCollector — reads statfs() for mounted volume capacity and usage
- NetworkMetricCollector — reads getifaddrs() and sysctl for bytes in/out per interface
- AlertEvaluator — checks latest metric values against user-configured thresholds, posts UNUserNotification when breached
- HistoryRecorder — batches metric samples and writes to SwiftData on a background ModelActor

## 🗄 Data Layer
- **Primary Store:** SwiftData with ModelContainer configured at app launch. Models: MetricSample (timestamp, metricType, value, metadata), DashboardLayout (cardOrder, expandedCardId), AlertThreshold (metricType, operator, value, enabled). Optional CloudKit sync for layout and thresholds only — metric samples stay local.
- **Relationships:** MetricSample is a flat append-only model with no relationships — queried by metricType and timestamp range. DashboardLayout is a singleton. AlertThreshold has a 1:1 mapping to MetricType enum. No complex joins or relationship graphs.
- **Migrations:** SwiftData lightweight migration via VersionedSchema. Initial schema is v1. Future schema changes use staged migration plans. No manual Core Data migration code.

## ☁️ Infrastructure
- **Hosting:** Fully local macOS app. No server, no cloud hosting. Distributed via direct .dmg download or Mac App Store. Code-signed and notarized via Xcode.
- **Scaling Strategy:** Not applicable — single-user local app. Performance scaling handled by actor isolation (collectors run concurrently without blocking UI), Metal GPU rendering (offloads chart gradient computation), and SwiftData batch writes (amortize disk I/O). Historical data pruning keeps storage bounded to 30-day rolling window.
- **CI/CD:** Xcode Cloud or GitHub Actions with xcodebuild. Build, test, archive, notarize, distribute. No containers, no Terraform, no infrastructure-as-code needed.

## ⚖️ Key Trade-offs
- Polling via structured concurrency tasks instead of push-based IOKit notifications — simpler implementation, predictable 1Hz cadence, slightly higher CPU than interrupt-driven but well within 3% budget
- SwiftData over raw SQLite — simpler code and CloudKit sync for free, but less control over write batching and query optimization for high-frequency metric samples
- Metal shaders via SwiftUI .visualEffect modifiers instead of custom MTKView — tighter SwiftUI integration and simpler code, but limited to shader types SwiftUI exposes (ShaderLibrary)
- Observation framework over Combine — cleaner syntax and no publisher chains, but requires macOS 14+ (already exceeded by macOS 15 target)
- Flat MetricSample model instead of per-metric-type tables — simpler schema and queries, but slightly larger storage footprint due to repeated metricType field
- Menu bar graph uses TimelineView with Canvas rendering instead of a separate Metal view — simpler and sufficient for a tiny sparkline, avoids Metal context overhead for 16x16 drawing

## 📐 Non-Functional Requirements
- App CPU overhead must stay below 3% during normal dashboard monitoring with all five metric cards visible
- All metric collectors must refresh at 1Hz minimum with TimelineView driving smooth visual interpolation between samples
- App launch to visible dashboard with live data in under 1 second on Apple Silicon Macs
- Metal shader chart rendering must sustain 60fps on all supported Apple Silicon GPUs
- Card drag-to-rearrange must persist layout within 100ms of drop
- matchedGeometryEffect card expansion/collapse must run at 60fps
- Alert notifications must fire within 2 seconds of threshold breach
- SwiftData batch writes for metric samples must complete in under 10ms per batch
- Historical storage must handle 30 days of per-second samples without exceeding 500MB
- Full Swift 6 strict concurrency compliance — no data races, all types Sendable where required
- Zero network calls unless CloudKit sync is explicitly enabled by the user