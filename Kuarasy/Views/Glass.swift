import SwiftUI

/// How much of the window colour is laid inside each glass shape, under its content.
/// `Glass` has no opacity or blur control, so this is the dial for contrast: 0 is
/// stock Liquid Glass, higher is more solid. Dark grey in dark mode, light in light.
private let glassBacking = Color(nsColor: .windowBackgroundColor).opacity(0.6)

/// Liquid Glass on macOS 26+, translucent material on 14 and 15.
extension View {
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 18, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            let base: Glass = tint.map { Glass.regular.tint($0) } ?? .regular
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            // Tint again above the backing, or the backing hides the glass's own tint.
            self
                .background(tint ?? .clear, in: shape)
                .background(glassBacking, in: shape)
                .glassEffect(interactive ? base.interactive() : base, in: shape)
        } else {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            self
                .background(.ultraThinMaterial, in: shape)
                .background((tint ?? .clear).opacity(0.25), in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    func glassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            let base: Glass = tint.map { Glass.regular.tint($0) } ?? .regular
            self
                .background(tint ?? .clear, in: Capsule())
                .background(glassBacking, in: Capsule())
                .glassEffect(interactive ? base.interactive() : base, in: .capsule)
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .background((tint ?? .clear).opacity(0.25), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        }
    }

    /// Glass button style on 26+, borderless on older systems.
    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.glass) }
        } else {
            if prominent { self.buttonStyle(.borderedProminent) } else { self.buttonStyle(.bordered) }
        }
    }
}

/// Groups glass shapes so they blend and morph together on macOS 26+.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

extension TimeStatus {
    var color: Color {
        switch self {
        case .working: Color(red: 0.42, green: 0.78, blue: 0.36)
        case .offHours: Color(red: 0.98, green: 0.76, blue: 0.20)
        case .sleeping: Color(red: 0.93, green: 0.27, blue: 0.42)
        }
    }
}

extension SolarPhase {
    var color: Color {
        switch self {
        case .sunrise: .orange
        case .day: .yellow
        case .sunset: .pink
        case .night: .indigo
        }
    }
}
