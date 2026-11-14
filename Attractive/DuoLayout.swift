import SwiftUI
import os

private let duoLog = Logger(subsystem: "com.lukesteuber.attractive", category: "duo")

// iPhone Duo support (iOS 27.1+).
//
// On the Duo's inner display the attractor and its controls sit in a system
// `ArrangementView` split that follows the fold: side by side when the phone
// is folded like a book, attractor on top and controls below when it stands
// like a laptop. Everywhere else (other iPhones, iPad, the Duo's outer display,
// iOS before 27.1) ContentView keeps its original layout.
//
// Layout decisions use the fold's reserved region, as Apple asks; the hinge
// angle drives only the optional "fold to turn" effect.

// MARK: - Fold detection

extension View {
    /// Reports whether this view's display has a fold (a `.division` reserved
    /// region, active or not). Only the Duo's inner display has one; the outer
    /// display, other iPhones and iPads report `false`. Before iOS 27.1 this
    /// never fires and the binding keeps its initial `false`.
    @ViewBuilder
    func detectsFold(_ hasFold: Binding<Bool>) -> some View {
        if #available(iOS 27.1, *) {
            onGeometryChange(for: Bool.self) { proxy in
                !proxy.reservedRegions(kind: .division, options: .includeInactive).isEmpty
            } action: {
                duoLog.debug("fold present \($0, privacy: .public)")
                hasFold.wrappedValue = $0
            }
        } else {
            self
        }
    }

    /// Pads this view so its content stays clear of an active fold that runs
    /// through it. A no-op when no fold crosses the view (the usual case
    /// inside an arrangement pane, which the system already keeps off the
    /// fold) and before iOS 27.1.
    func foldClearance() -> some View {
        modifier(FoldClearance())
    }
}

private struct FoldClearance: ViewModifier {
    @State private var insets = EdgeInsets()

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content
                .padding(insets)
                .onGeometryChange(for: EdgeInsets.self) { proxy in
                    Self.insets(for: proxy.reservedRegions(kind: .division),
                                in: CGRect(origin: .zero, size: proxy.size))
                } action: { insets = $0 }
        } else {
            content
        }
    }

    /// For each fold crossing `bounds`, give up the narrower side: a vertical
    /// fold (book pose) left of centre pads the leading edge past it, right of
    /// centre pads the trailing edge; a horizontal fold (laptop pose) pads top
    /// or bottom the same way. Region frames are already in local coordinates
    /// and include Apple's margins.
    @available(iOS 27.1, *)
    static func insets(for regions: [ReservedRegion], in bounds: CGRect) -> EdgeInsets {
        var e = EdgeInsets()
        for r in regions where r.isActive {
            let f = r.frame.intersection(bounds)
            guard !f.isNull, f.width > 0, f.height > 0 else { continue }
            if r.frame.height > r.frame.width {
                if f.midX < bounds.midX { e.leading = max(e.leading, f.maxX - bounds.minX) }
                else { e.trailing = max(e.trailing, bounds.maxX - f.minX) }
            } else {
                if f.midY < bounds.midY { e.top = max(e.top, f.maxY - bounds.minY) }
                else { e.bottom = max(e.bottom, bounds.maxY - f.minY) }
            }
        }
        return e
    }
}

// MARK: - Split layout

/// The Duo inner-display layout: attractor in the primary pane, Tune / Math
/// and the control bar in the secondary pane.
@available(iOS 27.1, *)
struct DuoSplitLayout<Stage: View>: View {
    @Bindable var settings: AttractiveSettings
    /// Cumulative extra yaw (radians) for the 3D view from the hinge.
    @Binding var hingeYaw: Double
    let present: (ContentView.ActiveSheet) -> Void
    @ViewBuilder let stage: () -> Stage

    /// Off by default: folding the phone shouldn't spin the view until the
    /// person asks for it. Per device, not synced.
    @AppStorage("duo.hingeTurnsView") private var hingeTurnsView = false
    /// Hinge angle (degrees) at the previous partially-open update; nil while
    /// the phone is closed or flat, so each fold starts from where the view is.
    @State private var lastHingeDegrees: Double?

    var body: some View {
        ArrangementView {
            stage()
        } secondary: {
            DuoControlPane(settings: settings,
                           hingeTurnsView: $hingeTurnsView,
                           present: present)
        }
        .arrangementViewStyle(.split)
        .onHingeChange(isEnabled: hingeTurnsView) { _, new in
            if let hinge = new.hinge {
                duoLog.debug("hinge \(Self.name(hinge.status), privacy: .public) \(hinge.angle.degrees, format: .fixed(precision: 1), privacy: .public)°")
            }
            guard let hinge = new.hinge, hinge.status == .partiallyOpen else {
                lastHingeDegrees = nil
                return
            }
            let degrees = hinge.angle.degrees
            if let last = lastHingeDegrees {
                // Two degrees of turn per degree of hinge: a comfortable fold
                // from about 70° to 140° turns the attractor most of the way round.
                hingeYaw += (degrees - last) * 2 * .pi / 180
            }
            lastHingeDegrees = degrees
        }
        .onChange(of: hingeTurnsView) { _, on in
            if !on { lastHingeDegrees = nil }
        }
    }

    private static func name(_ status: DeviceHinge.Status) -> String {
        switch status {
        case .closed: "closed"
        case .partiallyOpen: "partiallyOpen"
        case .fullyOpen: "fullyOpen"
        default: "unknown"
        }
    }
}

/// Secondary pane: the parameter sliders and the equations on a segmented
/// control (they were the Tune inspector and the Math sheet), the optional
/// hinge toggle, and the rest of the control bar.
@available(iOS 27.1, *)
private struct DuoControlPane: View {
    enum Panel: String, CaseIterable, Identifiable {
        case tune = "Tune", math = "Math"
        var id: Self { self }
    }

    @Bindable var settings: AttractiveSettings
    @Binding var hingeTurnsView: Bool
    let present: (ContentView.ActiveSheet) -> Void

    /// Remembered per device, so the pane reopens on the panel last used.
    @AppStorage("duo.panel") private var panel: Panel = .tune

    var body: some View {
        VStack(spacing: 0) {
            header

            Group {
                switch panel {
                case .tune: ParameterPanel(settings: settings, embedded: true)
                case .math: EquationView(settings: settings, embedded: true)
                }
            }
            .frame(maxHeight: .infinity)

            hingeRow
            bar
        }
        .background(Color.black.ignoresSafeArea())
        .foldClearance()
        .preferredColorScheme(.dark)
    }

    /// A plain header rather than a NavigationStack bar: inside an
    /// arrangement pane on iOS 27.2 the nested stack's bar didn't draw.
    private var header: some View {
        HStack(spacing: 12) {
            Picker("Panel", selection: $panel) {
                ForEach(Panel.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)

            Spacer(minLength: 0)

            if panel == .tune {
                Button("Reset") { settings.resetParameters() }
                    .disabled(!settings.hasParameterOverrides)
                    .tint(settings.accentColor)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
        }
    }

    private var hingeRow: some View {
        Toggle(isOn: $hingeTurnsView) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Fold to turn")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Text(settings.viewMode == .scene3D
                     ? "Open or close the hinge part way to turn the 3D view."
                     : "Turns the 3D view; switch to 3D to use it.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(settings.accentColor)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
        }
    }

    private var bar: some View {
        HStack(spacing: 14) {
            ControlBarButton(system: "circle.grid.cross", label: settings.attractor.displayName) {
                present(.picker)
            }
            ControlBarButton(system: "graduationcap", label: "Learn") {
                present(.lessons)
            }
            ControlBarButton(system: settings.viewMode == .scene3D ? "cube" : "square.on.square",
                             label: settings.viewMode.displayName,
                             a11yLabel: settings.viewMode == .scene3D
                                 ? "Switch to 2D canvas" : "Switch to 3D phase space") {
                settings.viewMode = settings.viewMode == .scene3D ? .canvas2D : .scene3D
            }
            ControlBarButton(system: "paintbrush.pointed", label: "Style") {
                present(.settings)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
        }
    }
}
