// MenuBarView.swift
// Pulse — macOS system monitor

import SwiftUI

/// Dropdown content for the menu bar extra (stats + Open/Quit).
public struct MenuBarView: View {
    @Bindable var viewModel: DashboardViewModel

    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.cards, id: \.metricType) { card in
                    HStack {
                        Text(card.metricType.rawValue.capitalized)
                        Spacer()
                        Text(card.formattedValue)
                            .monospacedDigit()
                    }
                }
                Divider()
                Button("Open Main Window") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    for w in NSApplication.shared.windows where w.canBecomeMain {
                        w.makeKeyAndOrderFront(nil)
                        break
                    }
                }
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .padding()
            .frame(width: 220)
    }
}

struct MenuBarIconView: View {
    let cards: [CardViewModel]
    private var cpuCard: CardViewModel? { cards.first { $0.metricType == .cpu } }

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let points = cpuCard?.sparklineBuffer ?? []
                guard points.count > 1 else { return }
                let w = size.width - 2
                let h = size.height - 2
                let mn = points.min() ?? 0
                let mx = points.max() ?? 1
                let range = mx - mn
                let scale = range > 0 ? h / range : 0
                let step = w / CGFloat(points.count - 1)
                var path = Path()
                for (i, v) in points.enumerated() {
                    let x = 1 + CGFloat(i) * step
                    let y = 1 + h - CGFloat(v - mn) * scale
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                ctx.stroke(path, with: .color(.primary), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            }
            .frame(width: 22, height: 16)
        }
    }
}
