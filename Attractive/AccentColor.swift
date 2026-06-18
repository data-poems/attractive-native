import SwiftUI

extension AttractiveSettings {
    /// The single accent colour derived from the user's hue, used across every
    /// view. Centralised so the saturation/brightness can't drift between sites.
    var accentColor: Color {
        Color(hue: hue, saturation: 0.85, brightness: 1.0)
    }
}
