import SwiftUI

struct ContentView: View {

    @State private var settings = AttractiveSettings.shared
    @State private var canvasSize: CGSize = .zero
    @State private var showPicker = false
    @State private var showTune = false

    var body: some View {
        ZStack {
            // Layer 1 — edge-to-edge attractor canvas.
            GeometryReader { geo in
                ZStack {
                    Color.black
                    AttractiveCanvas(size: geo.size,
                                     config: settings.currentConfig(),
                                     speed: settings.speed,
                                     zoom: settings.zoom,
                                     hue: settings.hue,
                                     lineWidth: settings.lineWidth,
                                     glow: settings.glow,
                                     integrator: settings.integrator)
                }
                .onAppear { canvasSize = geo.size }
                .onChange(of: geo.size) { _, new in canvasSize = new }
            }
            .ignoresSafeArea()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(settings.attractor.displayName) attractor")

            // Layer 2 — bottom control bar.
            VStack {
                Spacer()
                controlBar
            }
        }
        .sheet(isPresented: $showPicker) {
            AttractorPickerSheet(settings: settings)
        }
        .sheet(isPresented: $showTune) {
            ParameterPanel(settings: settings)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Control bar

    private var controlBar: some View {
        HStack(spacing: 18) {
            controlButton(system: "circle.grid.cross", label: settings.attractor.displayName) {
                showPicker = true
            }

            controlButton(system: settings.glow ? "sparkles" : "sparkle",
                          label: settings.glow ? "Glow" : "Flat") {
                settings.glow.toggle()
            }

            controlButton(system: "paintpalette", label: "Color") {
                settings.hue = (settings.hue + 0.12).truncatingRemainder(dividingBy: 1.0)
            }

            controlButton(system: speedIcon, label: speedLabel) {
                let next = settings.speed >= 2.0 ? 0.5 : settings.speed + 0.5
                settings.speed = next
            }

            controlButton(system: "slider.horizontal.3", label: "Tune") {
                showTune = true
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

    private var speedIcon: String {
        settings.speed < 1.0 ? "tortoise" : (settings.speed > 1.5 ? "hare" : "gauge.medium")
    }

    private var speedLabel: String {
        String(format: "%.1f×", settings.speed)
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
