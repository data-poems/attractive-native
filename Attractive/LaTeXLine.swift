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
    }

    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MTMathUILabel, context: Context) -> CGSize? {
        let fitting = uiView.sizeThatFits(CGSize(width: proposal.width ?? .greatestFiniteMagnitude,
                                                 height: .greatestFiniteMagnitude))
        return CGSize(width: proposal.width ?? fitting.width, height: fitting.height)
    }
}
