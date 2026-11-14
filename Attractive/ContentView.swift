import SwiftUI

struct ContentView: View {

    /// Modal surfaces routed through a single `.sheet(item:)`. The parameter
    /// panel is handled separately via `.inspector` so it can dock as a sidebar
    /// on iPad. New surfaces (e.g. `.lessons`) slot in here with no structural
    /// change.
    enum ActiveSheet: Identifiable {
        case picker, equations, settings, lessons
        var id: Self { self }
    }

    @State private var settings = AttractiveSettings.shared
    @State private var hud = PhaseHUDModel()
    @State private var activeSheet: ActiveSheet?
    @State private var inspectorVisible = false
    /// True on the iPhone Duo's inner display (it has a fold). Drives the
    /// split layout in `DuoLayout.swift`; false everywhere else.
    @State private var hasFold = false
    /// Extra yaw for the 3D view from the optional Duo "fold to turn" input.
    @State private var hingeYaw: Double = 0

    var body: some View {
        rootLayout
            .detectsFold($hasFold)
            .onChange(of: hasFold) { _, fold in
                // The split shows Tune and Math itself, so close the inspector
                // and the Math sheet when the Duo opens onto its inner display.
                if fold {
                    inspectorVisible = false
                    if activeSheet == .equations { activeSheet = nil }
                }
            }
            .animation(.easeOut(duration: 0.35), value: settings.hasSeenIntro)
            // Parameter panel: a docked inspector on iPad (regular width), an
            // automatic sheet on iPhone (compact width) — SwiftUI adapts it for us.
            .inspector(isPresented: $inspectorVisible) {
                ParameterPanel(settings: settings)
                    .inspectorColumnWidth(min: 280, ideal: 340, max: 460)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .picker:    AttractorPickerSheet(settings: settings)
                case .equations: EquationView(settings: settings)
                case .settings:  SettingsSheet(settings: settings)
                case .lessons:
                    LessonsHomeView(settings: settings)
                        .presentationDetents([.medium, .large])
                }
            }
    }

    @ViewBuilder
    private var rootLayout: some View {
        if #available(iOS 27.1, *), hasFold {
            ZStack {
                DuoSplitLayout(settings: settings, hingeYaw: $hingeYaw,
                               present: present) {
                    stage
                }
                introLayer
            }
        } else {
            standardLayout
        }
    }

    /// The original layout: canvas edge to edge, control bar along the bottom.
    private var standardLayout: some View {
        ZStack {
            stage

            // Layer 3 — bottom control bar.
            VStack {
                Spacer()
                controlBar
            }

            introLayer
        }
    }

    /// Layer 4 — first-launch intro tour (covers everything so the user
    /// focuses on the overlay; the attractor stays live behind it).
    @ViewBuilder
    private var introLayer: some View {
        if !settings.hasSeenIntro {
            IntroTour(settings: settings)
                .transition(.opacity)
        }
    }

    /// The attractor (2D canvas or 3D phase space) plus its telemetry HUD.
    private var stage: some View {
        ZStack {
            // Layer 1 — edge-to-edge attractor canvas.
            GeometryReader { geo in
                ZStack {
                    Color.black
                    if settings.viewMode == .scene3D {
                        PhaseSpaceView(config: settings.currentConfig(),
                                       speed: settings.speed,
                                       zoom: settings.zoom,
                                       hue: settings.hue,
                                       glow: settings.glow,
                                       integrator: settings.integrator,
                                       sensitive: settings.sensitiveDependence,
                                       lyapunov: settings.showLyapunov,
                                       hud: hud,
                                       onInspect: { hud.inspected = $0 },
                                       extraYaw: hingeYaw)
                            .id(ViewMode.scene3D)
                    } else {
                        AttractiveCanvas(size: geo.size,
                                         config: settings.currentConfig(),
                                         speed: settings.speed,
                                         zoom: settings.zoom,
                                         hue: settings.hue,
                                         lineWidth: settings.lineWidth,
                                         glow: settings.glow,
                                         integrator: settings.integrator)
                            .id(ViewMode.canvas2D)
                    }
                }
            }
            .ignoresSafeArea()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(settings.attractor.displayName) attractor")

            // Layer 2 — telemetry HUD (3D only, when a chaos lens is on).
            if settings.viewMode == .scene3D,
               settings.sensitiveDependence || settings.showLyapunov {
                VStack {
                    HStack {
                        PhaseHUD(model: hud,
                                 metadata: AttractorMetadataRegistry.metadata(for: settings.attractor),
                                 showSeparation: settings.sensitiveDependence,
                                 showLyapunov: settings.showLyapunov,
                                 accent: settings.accentColor)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 60)
                .padding(.horizontal, 16)
                .foldClearance()
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Control bar

    /// Show a sheet, first dismissing the Tune inspector so the two can't stack
    /// on compact width (where the inspector presents as a sheet).
    private func present(_ sheet: ActiveSheet) {
        inspectorVisible = false
        activeSheet = sheet
    }

    private var controlBar: some View {
        HStack(spacing: 14) {
            // Identity anchor.
            controlButton(system: "circle.grid.cross", label: settings.attractor.displayName) {
                present(.picker)
            }

            Rectangle().fill(Color.white.opacity(0.15)).frame(width: 1, height: 30)

            // Learn cluster.
            controlButton(system: "graduationcap", label: "Learn") {
                present(.lessons)
            }
            controlButton(system: "slider.horizontal.3", label: "Tune") {
                // The Tune inspector and the sheets are mutually exclusive: on
                // compact width the inspector is itself a sheet, so never stack.
                activeSheet = nil
                inspectorVisible.toggle()
            }
            controlButton(system: "function", label: "Math") {
                present(.equations)
            }

            Rectangle().fill(Color.white.opacity(0.15)).frame(width: 1, height: 30)

            // Look cluster.
            controlButton(system: settings.viewMode == .scene3D ? "cube" : "square.on.square",
                          label: settings.viewMode.displayName,
                          a11yLabel: settings.viewMode == .scene3D
                              ? "Switch to 2D canvas" : "Switch to 3D phase space") {
                settings.viewMode = settings.viewMode == .scene3D ? .canvas2D : .scene3D
            }
            controlButton(system: "paintbrush.pointed", label: "Style") {
                present(.settings)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(Color.black.opacity(0.9))
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                }
        }
    }

    private func controlButton(system: String, label: String, a11yLabel: String? = nil,
                               action: @escaping () -> Void) -> some View {
        ControlBarButton(system: system, label: label, a11yLabel: a11yLabel, action: action)
    }
}

// MARK: - Control bar button

/// One icon-over-label button in a control bar. Shared by the standard bottom
/// bar and the Duo split's control pane.
struct ControlBarButton: View {
    let system: String
    let label: String
    var a11yLabel: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: system)
                    .font(.system(size: 20, weight: .regular))
                    .frame(height: 26)
                Text(label)
                    // Scales with Dynamic Type (capped so the bar stays usable).
                    .font(.system(.caption2, design: .monospaced).weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityLabel(a11yLabel ?? label)
    }
}

// MARK: - Attractor picker sheet

private struct AttractorPickerSheet: View {
    @Bindable var settings: AttractiveSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(AttractorID.allCases) { id in
                    Button {
                        settings.attractor = id
                        dismiss()
                    } label: {
                        HStack {
                            Text(id.displayName)
                                .foregroundStyle(.white)
                            Spacer()
                            if id == settings.attractor {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(settings.accentColor)
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Attractor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview { ContentView() }
