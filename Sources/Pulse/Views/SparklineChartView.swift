// SparklineChartView.swift
// Pulse — macOS system monitor

import SwiftUI

public struct SparklineChartView: View {
    let dataPoints: [Double]
    let color: Color
    let showGradient: Bool

    public init(dataPoints: [Double], color: Color = .primary, showGradient: Bool = true) {
        self.dataPoints = dataPoints
        self.color = color
        self.showGradient = showGradient
    }

    public var body: some View {
        GeometryReader { geo in
            let (minVal, maxVal) = minMax
            Canvas { context, size in
                guard dataPoints.count > 1, maxVal > minVal || maxVal == minVal else { return }
                let range = maxVal - minVal
                let scale = range > 0 ? (size.height - 2) / range : 0
                let step = size.width / CGFloat(max(1, dataPoints.count - 1))
                var path = Path()
                for (i, v) in dataPoints.enumerated() {
                    let x = CGFloat(i) * step
                    let y = size.height - 1 - CGFloat(v - minVal) * scale
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
        .drawingGroup()
    }

    private var minMax: (Double, Double) {
        guard !dataPoints.isEmpty else { return (0, 100) }
        let mn = dataPoints.min() ?? 0
        let mx = dataPoints.max() ?? 100
        if mn == mx { return (mn, mx + 1) }
        return (mn, mx)
    }
}
