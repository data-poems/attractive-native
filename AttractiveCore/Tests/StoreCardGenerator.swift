import XCTest
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
@testable import AttractiveKit

/// App Store "card" generator: renders each strange attractor (the real engine
/// trail) onto an App-Store-sized canvas with a caption, the same captioned-card
/// idea as the clocks widget-shot generator. Runs headless on macOS via
/// `swift test` (AttractiveKit builds for macOS), so no simulator or browser is
/// needed. Routine tests render into a temporary directory and clean it up.
///
/// To deliberately replace the tracked App Store cards:
///
///   cd AttractiveCore
///   ATTRACTIVE_STORE_CARD_OUTPUT=../screenshots-appstore \
///     swift test --filter StoreCardGenerator/testGenerateStoreCards
@MainActor
final class StoreCardGenerator: XCTestCase {

    private struct Card { let id: AttractorID; let caption: String; let hue: Double }

    // 5-shot storyboard (captions ≤8 words, searchable terms — Apple OCR-indexes them).
    private let cards: [Card] = [
        Card(id: .lorenz,    caption: "Watch deterministic chaos unfold",     hue: 0.55),
        Card(id: .aizawa,    caption: "Six strange attractors, drawn live",   hue: 0.42),
        Card(id: .chen,      caption: "Orbit the chaos in 2D and 3D",         hue: 0.62),
        Card(id: .halvorsen, caption: "A simple rule, an endless path",       hue: 0.92),
        Card(id: .thomas,    caption: "Strange beauty, on your Home Screen",  hue: 0.12),
    ]

    private let sizes: [(String, CGSize)] = [
        ("iphone-6.9", CGSize(width: 1320, height: 2868)),   // iPhone 17 Pro Max
        ("ipad-13",    CGSize(width: 2064, height: 2752)),   // iPad Pro 13"
    ]

    func testGenerateStoreCards() throws {
        let output = Self.outputRoot(
            environment: ProcessInfo.processInfo.environment,
            temporaryDirectory: FileManager.default.temporaryDirectory
        )
        defer {
            if output.isTemporary {
                try? FileManager.default.removeItem(at: output.url)
            }
        }

        for (label, size) in sizes {
            let dir = output.url.appendingPathComponent(label)
            try? FileManager.default.removeItem(at: dir)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for (i, card) in cards.enumerated() {
                let renderer = ImageRenderer(content: AttractorCard(card: card, size: size))
                renderer.scale = 1   // view is framed in points == pixels
                guard let cg = renderer.cgImage else {
                    XCTFail("ImageRenderer returned nil for \(card.id.rawValue) \(label)")
                    continue
                }
                let url = dir.appendingPathComponent(String(format: "%02d-%@.png", i + 1, card.id.rawValue))
                try Self.writePNG(cg, to: url)
                print("WROTE \(url.path)  \(cg.width)x\(cg.height)")
            }

            // 6th shot: the widget showcase. The app ships a Home-Screen widget
            // (systemSmall/Medium/Large) that had no App Store media; this renders
            // the same attractor tiles on a Home-Screen mockup so the listing
            // shows the widget in context.
            let widgetRenderer = ImageRenderer(content: WidgetShowcaseCard(size: size))
            widgetRenderer.scale = 1
            if let cg = widgetRenderer.cgImage {
                let url = dir.appendingPathComponent("06-widgets.png")
                try Self.writePNG(cg, to: url)
                print("WROTE \(url.path)  \(cg.width)x\(cg.height)")
            } else {
                XCTFail("ImageRenderer returned nil for widget showcase \(label)")
            }
        }
    }

    func testOutputPolicyUsesTemporaryDirectoryByDefault() {
        let temporaryDirectory = URL(fileURLWithPath: "/tmp/attractive-card-tests")
        let output = Self.outputRoot(environment: [:], temporaryDirectory: temporaryDirectory)

        XCTAssertTrue(output.isTemporary)
        XCTAssertEqual(output.url.deletingLastPathComponent().path, temporaryDirectory.path)
        XCTAssertNotEqual(output.url.lastPathComponent, "screenshots-appstore")
    }

    func testOutputPolicyHonorsExplicitGenerationDirectory() {
        let destination = "/tmp/deliberate-attractive-store-cards"
        let output = Self.outputRoot(
            environment: ["ATTRACTIVE_STORE_CARD_OUTPUT": destination],
            temporaryDirectory: URL(fileURLWithPath: "/tmp/ignored")
        )

        XCTAssertFalse(output.isTemporary)
        XCTAssertEqual(output.url.path, destination)
    }

    private static func outputRoot(environment: [String: String],
                                   temporaryDirectory: URL) -> (url: URL, isTemporary: Bool) {
        if let path = environment["ATTRACTIVE_STORE_CARD_OUTPUT"], !path.isEmpty {
            return (URL(fileURLWithPath: path).standardizedFileURL, false)
        }

        return (
            temporaryDirectory.appendingPathComponent("attractive-store-cards-\(UUID().uuidString)"),
            true
        )
    }

    /// Per-attractor hue, mirroring `AttractorPalette` in the widget target (kept
    /// in sync by hand — the widget target isn't importable from these tests).
    private static func hue(for id: AttractorID) -> Double {
        switch id {
        case .lorenz:    return 0.55
        case .rossler:   return 0.78
        case .aizawa:    return 0.42
        case .thomas:    return 0.12
        case .halvorsen: return 0.92
        case .chen:      return 0.62
        }
    }

    /// Draws one attractor trail (dim full trail + bright leading head) into a
    /// GraphicsContext, matching `AttractorWidgetView.draw`. Shared by the widget
    /// tiles so the shot reads exactly like the shipping widget.
    fileprivate static func drawAttractor(_ id: AttractorID, hue: Double, in ctx: inout GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
        guard size.width > 1, size.height > 1 else { return }
        let engine = AttractiveEngine(config: AttractorRegistry.defaultConfig(for: id))
        engine.integrator = .rk4
        engine.maxPoints = 7000
        engine.regenerate(width: Double(size.width), height: Double(size.height))
        let target = min(engine.maxPoints - 200, 6000)
        var t = 0.0
        while engine.points.count < target {
            t += 16.0
            engine.advance(timeMs: t)
            if t > 120_000 { break }
        }
        guard engine.points.count > 2 else { return }
        let base = Color(hue: hue, saturation: 0.85, brightness: 1.0)
        let lw = max(1.0, size.width * 0.012)
        var trail = ctx
        trail.addFilter(.shadow(color: base.opacity(0.7), radius: size.width * 0.04))
        trail.stroke(Path(engine.trailPath()),
                     with: .color(base.opacity(0.6)),
                     style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
        let headCount = min(engine.points.count, 600)
        if headCount > 1 {
            let pts = engine.points.suffix(headCount)
            var head = Path()
            head.move(to: pts.first!)
            for p in pts.dropFirst() { head.addLine(to: p) }
            var hl = ctx
            hl.addFilter(.shadow(color: base.opacity(0.9), radius: size.width * 0.05))
            hl.stroke(head, with: .color(.white.opacity(0.95)),
                      style: StrokeStyle(lineWidth: lw * 1.2, lineCap: .round, lineJoin: .round))
        }
    }

    /// One widget tile: a rounded attractor render on black, matching how
    /// WidgetKit frames `AttractorWidgetView`.
    private struct WidgetTile: View {
        let id: AttractorID
        let side: CGSize
        var body: some View {
            Canvas(opaque: true, colorMode: .extendedLinear) { ctx, sz in
                StoreCardGenerator.drawAttractor(id, hue: StoreCardGenerator.hue(for: id), in: &ctx, size: sz)
            }
            .frame(width: side.width, height: side.height)
            .clipShape(RoundedRectangle(cornerRadius: side.height * 0.22, style: .continuous))
        }
    }

    /// A Home-Screen mockup: soft wallpaper, a medium widget over two small
    /// widgets (three distinct attractors), and a headline. Reads as "the widget,
    /// on your Home Screen."
    private struct WidgetShowcaseCard: View {
        let size: CGSize
        var body: some View {
            let unit = size.width * 0.40          // a systemSmall tile edge
            let gap = size.width * 0.06
            ZStack(alignment: .top) {
                LinearGradient(colors: [Color(hue: 0.62, saturation: 0.55, brightness: 0.22),
                                        Color(hue: 0.80, saturation: 0.6, brightness: 0.10),
                                        .black],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: gap) {
                    Spacer(minLength: size.height * 0.14)
                    Text("Live attractors on your Home Screen")
                        .font(.system(size: size.width * 0.048, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, size.width * 0.08)
                    // Medium widget (2 wide) over two small widgets.
                    WidgetTile(id: .lorenz, side: CGSize(width: unit * 2 + gap, height: unit))
                    HStack(spacing: gap) {
                        WidgetTile(id: .aizawa, side: CGSize(width: unit, height: unit))
                        WidgetTile(id: .thomas, side: CGSize(width: unit, height: unit))
                    }
                    Spacer()
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "StoreCard", code: 1)
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw NSError(domain: "StoreCard", code: 2) }
    }

    /// One captioned card: black field, the attractor trail centered, a headline
    /// near the top. Mirrors `AttractiveCanvas.drawScene` (dim trail + bright head).
    private struct AttractorCard: View {
        let card: Card
        let size: CGSize

        var body: some View {
            ZStack(alignment: .top) {
                Color.black
                Canvas(opaque: true, colorMode: .extendedLinear) { ctx, sz in
                    draw(in: &ctx, size: sz)
                }
                Text(card.caption)
                    .font(.system(size: size.width * 0.050, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, size.width * 0.08)
                    .padding(.top, size.height * 0.06)
                    .frame(maxWidth: .infinity)
            }
            .frame(width: size.width, height: size.height)
        }

        private func draw(in ctx: inout GraphicsContext, size: CGSize) {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            let engine = AttractiveEngine(config: AttractorRegistry.defaultConfig(for: card.id))
            engine.integrator = .rk4
            engine.maxPoints = 9000
            engine.zoom = 1.35   // fill more of the tall card than the in-app default
            engine.regenerate(width: Double(size.width), height: Double(size.height))
            var t = 0.0
            while engine.points.count < 7500 {
                t += 16.0
                engine.advance(timeMs: t)
                if t > 180_000 { break }
            }
            guard engine.points.count > 2 else { return }

            let base = Color(hue: card.hue, saturation: 0.85, brightness: 1.0)
            let lw = max(1.0, size.width * 0.0035)

            var trail = ctx
            trail.addFilter(.shadow(color: base.opacity(0.7), radius: size.width * 0.02))
            trail.stroke(Path(engine.trailPath()),
                         with: .color(base.opacity(0.6)),
                         style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))

            let headCount = min(engine.points.count, 700)
            if headCount > 1 {
                let pts = engine.points.suffix(headCount)
                var head = Path()
                head.move(to: pts.first!)
                for p in pts.dropFirst() { head.addLine(to: p) }
                var hl = ctx
                hl.addFilter(.shadow(color: base.opacity(0.9), radius: size.width * 0.03))
                hl.stroke(head, with: .color(.white.opacity(0.95)),
                          style: StrokeStyle(lineWidth: lw * 1.25, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
