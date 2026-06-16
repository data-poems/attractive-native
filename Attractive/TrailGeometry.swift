import SceneKit
import simd

/// Builds and updates a SceneKit line-strip geometry for one trajectory trail.
/// Vertex and color buffers are preallocated at capacity and refilled in place
/// each frame from the engine's ring buffer; the line index buffer is computed
/// once. No per-frame array growth — only the `Data` wrappers are rebuilt, which
/// is the documented-cheap path. The owned `node` is added to the scene by the
/// coordinator.
final class TrailGeometry {
    let node = SCNNode()

    private let capacity: Int
    private var vertices: [Float]          // capacity * 3
    private var colors: [Float]            // capacity * 4 (RGBA)
    private let indices: [UInt32]          // (capacity - 1) * 2 line endpoints

    init(capacity: Int) {
        self.capacity = capacity
        self.vertices = [Float](repeating: 0, count: capacity * 3)
        self.colors = [Float](repeating: 0, count: capacity * 4)
        var idx = [UInt32]()
        idx.reserveCapacity(max(0, (capacity - 1) * 2))
        for i in 0..<(capacity - 1) {
            idx.append(UInt32(i))
            idx.append(UInt32(i + 1))
        }
        self.indices = idx
        node.castsShadow = false
    }

    /// Rebuild the geometry from the current trail. `rgb` is the base colour;
    /// the trail fades from faint (oldest) to full (newest) via per-vertex alpha.
    func update(points: RingBuffer<SIMD3<Float>>, rgb: SIMD3<Float>) {
        let n = points.count
        guard n > 1 else { node.geometry = nil; return }

        var i = 0
        let denom = Float(max(1, n - 1))
        points.forEachOrdered { p in
            guard i < capacity else { return }
            vertices[i * 3 + 0] = p.x
            vertices[i * 3 + 1] = p.y
            vertices[i * 3 + 2] = p.z
            let a = Float(i) / denom
            colors[i * 4 + 0] = rgb.x
            colors[i * 4 + 1] = rgb.y
            colors[i * 4 + 2] = rgb.z
            colors[i * 4 + 3] = 0.12 + 0.88 * a
            i += 1
        }
        let count = min(n, capacity)

        let vData = Data(bytes: vertices, count: count * 3 * MemoryLayout<Float>.size)
        let cData = Data(bytes: colors, count: count * 4 * MemoryLayout<Float>.size)
        let segCount = count - 1
        let iData = indices.withUnsafeBytes { Data($0.prefix(segCount * 2 * MemoryLayout<UInt32>.size)) }

        let vSource = SCNGeometrySource(
            data: vData, semantic: .vertex, vectorCount: count,
            usesFloatComponents: true, componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0,
            dataStride: 3 * MemoryLayout<Float>.size)

        let cSource = SCNGeometrySource(
            data: cData, semantic: .color, vectorCount: count,
            usesFloatComponents: true, componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0,
            dataStride: 4 * MemoryLayout<Float>.size)

        let element = SCNGeometryElement(
            data: iData, primitiveType: .line,
            primitiveCount: segCount, bytesPerIndex: MemoryLayout<UInt32>.size)

        let geo = SCNGeometry(sources: [vSource, cSource], elements: [element])
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.blendMode = .add
        mat.writesToDepthBuffer = false
        mat.diffuse.contents = UIColor.white   // modulated by per-vertex colour
        geo.materials = [mat]
        node.geometry = geo
    }

    func clear() { node.geometry = nil }
}
