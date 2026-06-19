import XCTest
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
@testable import AttractiveKit

/// App Store "card" generator: renders each strange attractor (the real engine
/// trail) onto an App-Store-sized canvas with a caption, the same captioned-card
/// idea as the clocks widget-shot generator. Runs headless on macOS via
/// `swift test` (AttractiveKit builds for macOS), so no simulator or browser is
/// needed; writes PNGs straight to ../screenshots-appstore/<device>/.
///
///   cd AttractiveCore && swift test --filter StoreCardGenerator
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
        // swift test runs with cwd = the package dir (AttractiveCore); the repo is
        // its parent.
        let repo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).deletingLastPathComponent()
        for (label, size) in sizes {
            let dir = repo.appendingPathComponent("screenshots-appstore/\(label)")
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
