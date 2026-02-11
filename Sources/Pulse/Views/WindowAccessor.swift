// WindowAccessor.swift
// Pulse — macOS system monitor

import SwiftUI
import AppKit

public struct WindowAccessor: NSViewRepresentable {
    var configure: (NSWindow) -> Void

    public init(configure: @escaping (NSWindow) -> Void) {
        self.configure = configure
    }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.widthAnchor.constraint(equalToConstant: 1).isActive = true
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            self.configure(window)
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            self.configure(window)
        }
    }
}
