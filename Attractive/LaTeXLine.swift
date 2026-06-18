import SwiftUI
import SwiftMath

/// Renders a single line of LaTeX (e.g. an ODE) using SwiftMath's `MTMathUILabel`.
/// Wrapped behind this small type so the rest of the app never imports SwiftMath
/// directly — if the dependency ever needs swapping for a unicode `Text`
/// fallback, only this file changes.
struct LaTeXLine: UIViewRepresentable {
    let latex: String
    var color: UIColor = .white
    var fontSize: CGFloat = 20
    /// Spoken form for VoiceOver. Defaults to a reduction of the LaTeX; pass an
    /// explicit phrase when the heuristic reads awkwardly.
    var spokenLabel: String? = nil

    func makeUIView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.labelMode = .display
        label.textAlignment = .left
        label.contentInsets = MTEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
        configure(label)
        return label
    }

    func updateUIView(_ label: MTMathUILabel, context: Context) {
        configure(label)
    }

    private func configure(_ label: MTMathUILabel) {
        label.latex = latex
        label.textColor = color
        label.fontSize = fontSize
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        // The label renders math as glyphs (silent to VoiceOver) — give it a
        // spoken equivalent so the equations aren't lost to assistive tech.
        label.isAccessibilityElement = true
        label.accessibilityLabel = spokenLabel ?? Self.speak(latex)
    }

    /// Reduce the LaTeX used in this app to an intelligible spoken phrase.
    static func speak(_ latex: String) -> String {
        var s = latex
        // Fractions: \tfrac{a}{b} / \frac{a}{b} -> "a over b".
        s = s.replacingOccurrences(
            of: #"\\t?frac\{([^{}]*)\}\{([^{}]*)\}"#,
            with: " $1 over $2 ", options: .regularExpression)
        // Derivative: \dot{x} -> "x dot".
        s = s.replacingOccurrences(
            of: #"\\dot\{([^{}]*)\}"#, with: " $1 dot ", options: .regularExpression)
        let words: [(String, String)] = [
            ("\\sigma", " sigma "), ("\\rho", " rho "), ("\\beta", " beta "),
            ("\\alpha", " alpha "), ("\\lambda", " lambda "), ("\\delta", " delta "),
            ("\\approx", " approximately "), ("\\sin", " sine "), ("\\,", " "),
            ("^{3}", " cubed "), ("^3", " cubed "), ("^{2}", " squared "), ("^2", " squared "),
            ("_{1}", " one "), ("_1", " one "), ("_{0}", " naught "), ("_0", " naught "),
            ("=", " equals "), ("+", " plus "), ("-", " minus "), ("*", " times "), ("/", " over "),
            ("{", " "), ("}", " "), ("\\", " "), ("(", " open paren "), (")", " close paren "),
        ]
        for (from, to) in words { s = s.replacingOccurrences(of: from, with: to) }
        // Collapse runs of whitespace.
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespaces)
    }

    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MTMathUILabel, context: Context) -> CGSize? {
        let fitting = uiView.sizeThatFits(CGSize(width: proposal.width ?? .greatestFiniteMagnitude,
                                                 height: .greatestFiniteMagnitude))
        return CGSize(width: proposal.width ?? fitting.width, height: fitting.height)
    }
}
