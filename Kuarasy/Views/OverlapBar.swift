import SwiftUI

/// The "good time" bar across your day. Green: everyone working. Yellow: nobody asleep.
/// Red: someone asleep. Drag or click to scrub every clock to that moment.
struct OverlapBar: View {
    @Environment(ClockStore.self) private var store
    /// The moment being displayed (scrubbed or live).
    let date: Date
    /// The real current time.
    let live: Date

    private let barHeight: CGFloat = 10
    private let knobSize: CGFloat = 18

    var body: some View {
        let home = store.homeTimeZone
        let day = TimeMath.day(containing: date, in: home)
        let slots = TimeMath.overlapSlots(day: day, zones: store.barZones, hours: store.settings.hours)
        let runs = TimeMath.runs(slots, day: day)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Good time to meet")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                bestWindow(slots: slots, day: day, home: home)
            }

            bar(runs: runs, day: day)

            ticks

            HStack(spacing: 8) {
                controls
                Spacer(minLength: 4)
                readout(home: home)
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 20)
    }

    // MARK: Bar

    private func bar(runs: [TimeMath.Run], day: DateInterval) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fraction = min(max(date.timeIntervalSince(day.start) / day.duration, 0), 1)
            let liveFraction = live.timeIntervalSince(day.start) / day.duration

            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(runs.indices, id: \.self) { i in
                        let run = runs[i]
                        Rectangle()
                            .fill(run.status.color.gradient)
                            .frame(width: max(0, (run.to - run.from) * width))
                    }
                }
                .frame(height: barHeight)
                .clipShape(Capsule())

                // Where "now" is, shown while scrubbing.
                if store.isScrubbing, (0...1).contains(liveFraction) {
                    Capsule()
                        .fill(.primary.opacity(0.6))
                        .frame(width: 2, height: barHeight + 8)
                        .offset(x: liveFraction * width - 1)
                }

                Circle()
                    .fill(.white)
                    .frame(width: knobSize, height: knobSize)
                    .overlay(Circle().strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    .offset(x: fraction * width - knobSize / 2)
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let f = min(max(value.location.x / width, 0), 1)
                        let target = day.start.addingTimeInterval(f * day.duration)
                        let snapped = TimeMath.snap(target, in: day)
                        if snapped != store.selectedDate { store.selectedDate = snapped }
                    }
            )
        }
        .frame(height: knobSize + 4)
        .help("Drag to see everyone's time at that moment")
    }

    private var ticks: some View {
        let use24 = store.settings.use24Hour
        return HStack(spacing: 0) {
            ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                Text(TimeFormat.hourTick(hour, use24Hour: use24))
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
                if hour != 24 { Spacer(minLength: 0) }
            }
        }
        .padding(.top, -4)
    }

    // MARK: Controls

    private var controls: some View {
        // Plain HStack, not a GlassEffectContainer: the container blends neighbouring
        // glass, which made the tinted Now button bleed into the arrows.
        HStack(spacing: 6) {
            iconButton("chevron.left", help: "30 minutes earlier") { store.shift(by: -30 * 60) }
            Button("Now") { store.resetToNow() }
                .glassButton(prominent: store.isScrubbing)
                .disabled(!store.isScrubbing)
            iconButton("chevron.right", help: "30 minutes later") { store.shift(by: 30 * 60) }
        }
        .controlSize(.small)
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 12, height: 14)
        }
        .glassButton()
        .help(help)
    }

    @ViewBuilder
    private func readout(home: TimeZone) -> some View {
        // Same two-line layout live and scrubbing, so the card height never changes.
        VStack(alignment: .trailing, spacing: 0) {
            Text(TimeFormat.shortDay(date, in: home))
                .font(.caption2)
                .foregroundStyle(.secondary)
            if store.isScrubbing {
                Text(TimeFormat.relative(date, to: live))
                    .font(.caption.weight(.semibold))
            } else {
                Label("Live", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 30)
    }

    // MARK: Best window

    /// The longest stretch where everyone is working, as a tappable summary.
    @ViewBuilder
    private func bestWindow(slots: [TimeMath.Slot], day: DateInterval, home: TimeZone) -> some View {
        let use24 = store.settings.use24Hour
        if let window = Self.longestRun(of: .working, in: slots, day: day) {
            Button {
                store.selectedDate = window.start
            } label: {
                Text("\(TimeFormat.compact(window.start, in: home, use24Hour: use24))–\(TimeFormat.compact(window.end, in: home, use24Hour: use24))")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(TimeStatus.working.color)
            }
            .buttonStyle(.plain)
            .help("Everyone is in working hours. Click to jump there.")
        } else {
            Text("No shared working hours")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    static func longestRun(of status: TimeStatus, in slots: [TimeMath.Slot], day: DateInterval) -> DateInterval? {
        var best: DateInterval?
        var runStart: Date?
        for (i, slot) in slots.enumerated() {
            let end = i + 1 < slots.count ? slots[i + 1].start : day.end
            if slot.status == status {
                if runStart == nil { runStart = slot.start }
                let candidate = DateInterval(start: runStart!, end: end)
                if candidate.duration > (best?.duration ?? 0) { best = candidate }
            } else {
                runStart = nil
            }
        }
        return best
    }
}
