import SwiftUI

enum Route: Hashable {
    case list, add, pickHome, edit(UUID), settings
}

/// Root of the menu bar window. Panels swap in place; sheets are unreliable in `MenuBarExtra`.
struct PopoverView: View {
    @Environment(ClockStore.self) private var store
    @State private var route: Route

    init(initialRoute: Route = .list) {
        _route = State(initialValue: initialRoute)
    }

    var body: some View {
        Group {
            switch route {
            case .list:
                ClockListPanel(route: $route)
            case .add:
                ZonePickerView(title: "Add location") { id in
                    let added = store.add(timeZoneID: id)
                    route = .edit(added.id)
                } onCancel: { route = .list }
            case .pickHome:
                ZonePickerView(title: "Your time zone") { id in
                    store.settings.homeTimeZoneID = id
                    route = .settings
                } onCancel: { route = .settings }
            case .edit(let id):
                EditLocationView(id: id) { route = .list }
            case .settings:
                SettingsView(route: $route)
            }
        }
        .padding(12)
        .frame(width: 372)
        .animation(.snappy(duration: 0.25), value: route)
    }
}

/// The main panel: counted rows, the overlap bar, then reference rows.
/// Rows above the bar shape it; rows below only follow its time. Drag across to switch.
struct ClockListPanel: View {
    @Environment(ClockStore.self) private var store
    @Binding var route: Route

    @State private var drag: RowDrag?
    /// Layout frames (ignoring the drag offset) of rows and empty-section drop zones.
    @State private var frames: [DragTarget: CGRect] = [:]

    private let rowHeight: CGFloat = 76
    private let maxVisibleRows = 5
    private let compactRowHeight: CGFloat = 40
    private let maxVisibleCompactRows = 4
    private static let space = "clockPanel"

    var body: some View {
        TimelineView(.everyMinute) { context in
            let live = store.liveDate(context.date)
            let date = store.displayDate(live: live)
            VStack(spacing: 10) {
                header
                LocationRow(location: store.homeLocation, isHome: true, date: date, route: $route)
                countedList(date: date)
                    .zIndex(isDragging(counted: true) ? 1 : 0)
                OverlapBar(date: date, live: live)
                referenceList(date: date)
                    .zIndex(isDragging(counted: false) ? 1 : 0)
            }
            .coordinateSpace(.named(Self.space))
            // One gesture for the whole panel rather than one per row: a row that crosses
            // the bar is rebuilt in the other section, which would cancel a per-row gesture.
            // The bar's own scrub gesture is on a child view, so it still wins there.
            .gesture(reorderGesture)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.max.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 15))
            Text("Kuarasy")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
            Button {
                route = .settings
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16, height: 16)
            }
            .glassButton()
            .controlSize(.small)
            .keyboardShortcut(",")
            .help("Settings")
            Button {
                route = .add
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16, height: 16)
            }
            .glassButton()
            .controlSize(.small)
            .help("Add location")
        }
        .padding(.horizontal, 4)
    }

    // MARK: Above the bar

    @ViewBuilder
    private func countedList(date: Date) -> some View {
        let counted = store.countedLocations
        if store.locations.isEmpty {
            Text("Add the time zones your coworkers are in.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .glassCard(cornerRadius: 20)
        } else if counted.isEmpty {
            dropZone("Drag a location here to count it toward the bar", counts: true)
        } else {
            let rows = VStack(spacing: 6) {
                ForEach(counted) { location in
                    LocationRow(location: location, isHome: false, date: date, route: $route)
                        .modifier(dragged(location.id))
                }
            }
            if counted.count > maxVisibleRows {
                ScrollView { rows }
                    .frame(height: CGFloat(maxVisibleRows) * rowHeight)
                    .scrollIndicators(.never)
            } else {
                rows
            }
        }
    }

    // MARK: Below the bar

    @ViewBuilder
    private func referenceList(date: Date) -> some View {
        let reference = store.referenceLocations
        if reference.isEmpty {
            // Only while dragging, so the panel stays compact otherwise.
            if drag?.id != nil {
                dropZone("Drop here to show without counting", counts: false)
                    .transition(.opacity)
            }
        } else {
            let rows = VStack(spacing: 4) {
                ForEach(reference) { location in
                    CompactLocationRow(location: location, date: date, route: $route)
                        .modifier(dragged(location.id))
                }
            }
            if reference.count > maxVisibleCompactRows {
                ScrollView { rows }
                    .frame(height: CGFloat(maxVisibleCompactRows) * compactRowHeight)
                    .scrollIndicators(.never)
            } else {
                rows
            }
        }
    }

    private func dropZone(_ text: String, counts: Bool) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .modifier(TrackFrame(target: .zone(counts: counts), space: Self.space, frames: $frames))
    }

    // MARK: Dragging

    private func isDragging(counted: Bool) -> Bool {
        guard let id = drag?.id else { return false }
        return store.locations.first { $0.id == id }?.countsTowardBar == counted
    }

    private func dragged(_ id: UUID) -> DraggedRow {
        var offset: CGFloat = 0
        if let drag, drag.id == id, let frame = frames[.row(id)] {
            offset = drag.pointerY - drag.grabOffset - frame.minY
        }
        return DraggedRow(id: id, offset: offset, isDragged: drag?.id == id,
                          space: Self.space, frames: $frames)
    }

    private var reorderGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.space))
            .onChanged { value in
                if drag == nil {
                    // Decide once, at the start, whether this drag picked up a row.
                    let start = value.startLocation
                    let hit = frames.first { key, frame in
                        if case .row = key { return frame.contains(start) } else { return false }
                    }
                    guard case .row(let id)? = hit?.key, let frame = hit?.value else {
                        drag = RowDrag(id: nil, grabOffset: 0, pointerY: 0, current: nil)
                        return
                    }
                    withAnimation(.snappy(duration: 0.15)) {
                        drag = RowDrag(id: id, grabOffset: start.y - frame.minY,
                                       pointerY: value.location.y, current: .row(id))
                    }
                    return
                }
                guard let id = drag?.id else { return }
                drag?.pointerY = value.location.y

                // Like a drop delegate's "entered": act once per target the pointer moves onto.
                let point = CGPoint(x: frames[.row(id)]?.midX ?? value.location.x, y: value.location.y)
                let target = frames.first { $0.value.contains(point) }?.key
                guard let target, target != drag?.current else { return }
                drag?.current = target
                withAnimation(.snappy(duration: 0.2)) {
                    switch target {
                    case .row(let other): store.move(id, onto: other)
                    case .zone(let counts): store.setCountsTowardBar(id, counts)
                    }
                }
            }
            .onEnded { _ in
                withAnimation(.snappy(duration: 0.2)) { drag = nil }
            }
    }
}

private enum DragTarget: Hashable {
    case row(UUID)
    case zone(counts: Bool)
}

private struct RowDrag {
    /// `nil` when the drag started somewhere other than a row and should be ignored.
    var id: UUID?
    /// Pointer distance from the row's top edge when it was picked up.
    var grabOffset: CGFloat
    var pointerY: CGFloat
    /// The target the pointer is over, so each one triggers a move only on entry.
    var current: DragTarget?
}

/// Records a view's layout frame in the panel's coordinate space.
private struct TrackFrame: ViewModifier {
    let target: DragTarget
    let space: String
    @Binding var frames: [DragTarget: CGRect]

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(space)) } action: {
                frames[target] = $0
            }
            .onDisappear { frames[target] = nil }
    }
}

/// Lifts the dragged row and keeps it under the pointer. The frame is measured outside
/// the offset, so it reflects where the row sits in the list, not where it's drawn.
private struct DraggedRow: ViewModifier {
    let id: UUID
    let offset: CGFloat
    let isDragged: Bool
    let space: String
    @Binding var frames: [DragTarget: CGRect]

    func body(content: Content) -> some View {
        content
            .scaleEffect(isDragged ? 1.02 : 1)
            .shadow(color: .black.opacity(isDragged ? 0.3 : 0), radius: 10, y: 4)
            .offset(y: offset)
            .zIndex(isDragged ? 1 : 0)
            .modifier(TrackFrame(target: .row(id), space: space, frames: $frames))
    }
}

/// Back button + title used by the secondary panels.
struct PanelHeader<Trailing: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16, height: 16)
            }
            .glassButton()
            .controlSize(.small)
            .keyboardShortcut(.cancelAction)
            Text(title).font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
            trailing
        }
        .padding(.horizontal, 4)
    }
}

extension PanelHeader where Trailing == EmptyView {
    init(title: String, onBack: @escaping () -> Void) {
        self.init(title: title, onBack: onBack) { EmptyView() }
    }
}

