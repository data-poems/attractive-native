import Foundation

/// How the trajectory is presented: the flat 2D Canvas trail or the rotatable
/// SceneKit 3D phase space. Pure value type — no UIKit/SceneKit dependency.
public enum ViewMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case canvas2D
    case scene3D

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .canvas2D: return "2D"
        case .scene3D:  return "3D"
        }
    }
}
