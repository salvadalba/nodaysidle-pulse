<div align="center">

![Pulse logo](Resources/logo.svg)

# Pulse

**A beautiful, local-first macOS system monitor**

Real-time metrics · Live menu bar sparkline · Zero telemetry · No sign-in

[![macOS 15+](https://img.shields.io/badge/macOS-15+-blue?logo=apple)](https://www.apple.com/macos)
[![Swift 6](https://img.shields.io/badge/Swift-6-orange?logo=swift)](https://swift.org)
[![Open Source](https://img.shields.io/badge/Open%20Source-✓-green.svg)](.)

</div>

---

## ✨ What you get

| Feature | Description |
|---------|-------------|
| **Dashboard** | Five metric cards (CPU, Memory, GPU, Disk, Network) with live sparklines. Drag to reorder, tap to see history. |
| **Menu bar** | Tiny live CPU graph and dropdown with all five metrics, plus *Open* and *Quit*. |
| **Alerts** | Optional notifications when CPU or disk cross your thresholds (default: CPU > 90%, disk > 95%). |
| **History** | Per-metric history with time ranges (1h, 6h, 24h, 7d, 30d) and min/max/avg in the detail view. |
| **Local only** | Everything stays on your Mac. SwiftData for storage; optional CloudKit sync for layout and thresholds only. |

---

## 🚀 Quick start

### Run from source

```bash
git clone https://github.com/salvadalba/nodaysidle-pulse.git
cd nodaysidle-pulse
swift run Pulse
```

### Build and install to Applications

```bash
git clone https://github.com/salvadalba/nodaysidle-pulse.git
cd nodaysidle-pulse
./Scripts/install-app.sh
```

Then open **/Applications/Pulse.app**.

For signed + notarized DMG (Developer ID required):

```bash
./Scripts/build-and-notarize.sh
```

---

## 📋 Requirements

- **macOS 15 (Sequoia)** or later  
- **Xcode 16+** or Swift 6 toolchain  
- **Apple Silicon** or Intel Mac  

---

## 🛠 Development

```bash
swift build          # Debug build
swift test           # Run tests (14 tests)
swift run Pulse      # Run the app
```

---

## 📁 Project structure

```
Sources/Pulse/
├── Collectors/      CPU, Memory, GPU, Disk, Network (Mach / IOKit / sysctl)
├── Engine/          MetricEngine, HistoryRecorder, AlertEvaluator, AlertNotifier
├── Models/          Metric types, SwiftData schemas, MetricCollecting
├── ViewModels/      DashboardViewModel, CardViewModel
├── Views/           Dashboard, MetricCard, DetailView, MenuBar, Settings
└── Resources/       Logo, Metal shaders
Tests/PulseTests/    Unit and integration tests
```

---

## 📜 License

Use and modify as you like. If you ship a derivative, a mention is appreciated but not required.

---

<div align="center">

*Made with Swift & SwiftUI · No telemetry · No accounts · No cloud · nodaysidle*

</div>
