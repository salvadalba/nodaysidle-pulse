# Pulse

<p align="center">
  <img src="Resources/logo.svg" width="120" alt="Pulse logo" />
</p>

**A beautiful, local-first macOS system monitor.** Real-time CPU, memory, GPU, disk, and network metrics in a clean dashboard—with a live sparkline in your menu bar and optional alerts. No accounts, no cloud, no bloat.

---

## What’s inside

- **Dashboard** — Five metric cards (CPU, Memory, GPU, Disk, Network) with live sparklines. Drag to reorder; tap a card to see history.
- **Menu bar** — Tiny live CPU graph and a dropdown with all metrics and a quick “Open” / “Quit.”
- **Alerts** — Optional notifications when CPU or disk cross thresholds (e.g. CPU &gt; 90%, disk &gt; 95%). Configurable in Settings.
- **History** — Per-metric history (1h / 6h / 24h / 7d / 30d) and min/max/avg in the detail view.
- **Local only** — Everything stays on your Mac. SwiftData for storage; optional CloudKit sync for layout and thresholds only.

Built with **Swift 6**, **SwiftUI**, and **SwiftPM** (macOS 15+).

---

## Quick start

### Run from source

```bash
git clone https://github.com/YOUR_USERNAME/pulse.git   # use your repo URL
cd pulse
swift run Pulse
```

**First-time push to your empty GitHub repo** (from inside the project):

```bash
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

### Build and install as an app

```bash
swift build -c release
# Then copy .build/release/Pulse.app to /Applications (see Scripts/build-and-notarize.sh for a full script)
```

Or use the included script to build a signed, notarization-ready app and DMG:

```bash
./Scripts/build-and-notarize.sh
```

---

## Requirements

- **macOS 15 (Sequoia)** or later  
- **Xcode 16+** or Swift 6 toolchain (for building)  
- Apple Silicon or Intel Mac  

---

## Project layout

```
Sources/Pulse/
├── Collectors/     # CPU, Memory, GPU, Disk, Network (Mach / IOKit / sysctl)
├── Engine/         # MetricEngine, HistoryRecorder, AlertEvaluator, AlertNotifier
├── Models/         # Metric types, SwiftData schemas, MetricCollecting
├── ViewModels/     # DashboardViewModel, CardViewModel
├── Views/          # Dashboard, MetricCard, DetailView, MenuBar, Settings
└── Resources/      # Logo, Metal shaders
Tests/PulseTests/   # Unit and integration tests
```

---

## Development

```bash
swift build          # Debug build
swift test           # Run tests
swift run Pulse      # Run the app
```

---

## License

Use and modify as you like. If you ship a derivative, a mention is appreciated but not required.

---

<p align="center">
  <sub>Made with Swift &amp; SwiftUI · No telemetry, no sign-in, nodaysidle</sub>
</p>
