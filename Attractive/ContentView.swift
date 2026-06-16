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
    @State private var canvasSize: CGSize = .zero
    @State private var activeSheet: ActiveSheet?
    @State private var inspectorVisible = false

    var body: some View {
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
                                       lineWidth: settings.lineWidth,
                                       glow: settings.glow,
                                       integrator: settings.integrator,
                                       sensitive: settings.sensitiveDependence,
                                       lyapunov: settings.showLyapunov,
                                       hud: hud,
                                       onInspect: { hud.inspected = $0 })
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
                .onAppear { canvasSize = geo.size }
                .onChange(of: geo.size) { _, new in canvasSize = new }
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
                                 accent: Color(hue: settings.hue, saturation: 0.85, brightness: 1.0))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 60)
                .padding(.horizontal, 16)
                .allowsHitTesting(false)
            }

            // Layer 3 — bottom control bar.
            VStack {
                Spacer()
                controlBar
            }
        }
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
            case .lessons:   EmptyView() // wired in Phase 9
            }
        }
    }

    // MARK: - Control bar

    private var controlBar: some View {
        HStack(spacing: 14) {
            // Identity anchor.
            controlButton(system: "circle.grid.cross", label: settings.attractor.displayName) {
                activeSheet = .picker
            }

            Divider().frame(height: 30).overlay(Color.white.opacity(0.15))

            // Learn cluster.
            controlButton(system: "slider.horizontal.3", label: "Tune") {
                inspectorVisible.toggle()
            }
            controlButton(system: "function", label: "Math") {
                activeSheet = .equations
            }

            Divider().frame(height: 30).overlay(Color.white.opacity(0.15))

            // Look cluster.
            controlButton(system: settings.viewMode == .scene3D ? "cube" : "square.on.square",
                          label: settings.viewMode.displayName) {
                settings.viewMode = settings.viewMode == .scene3D ? .canvas2D : .scene3D
            }
            controlButton(system: "paintbrush.pointed", label: "Style") {
                activeSheet = .settings
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

    private func controlButton(system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: system)
                    .font(.system(size: 20, weight: .regular))
                    .frame(height: 26)
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
                                    .foregroundStyle(Color(hue: settings.hue, saturation: 0.85, brightness: 1.0))
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
