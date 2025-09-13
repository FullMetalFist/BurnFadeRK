//
//  ContentView.swift
//  BurnFadeRK
//
//  Created by Michael Vilabrera on 9/10/25.
//

import SwiftUI
import RealityKit
import Metal

struct BurnFadeSettings: Equatable {
    var burnAmount: Float = 0.0
    var burnScale: Float = 8.0
    var hueRotate: Float = 0.0
    var edgeWidth: Float = 0.08
    var emberRange: Float = 0.15
}

struct BurningSphereView: View {
    @State var mesh: LowLevelMesh?
    @State var burnSettings: BurnFadeSettings = .init()
    
    @State var originalVertices: [VertexDataWith4ChannelColor] = []
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let computePipeline: MTLComputePipelineState
    
    init() {
        self.device = MTLCreateSystemDefaultDevice()!
        self.commandQueue = device.makeCommandQueue()!
        let library = device.makeDefaultLibrary()!
        let function = library.makeFunction(name: "burnFadeVertices")!
        self.computePipeline = try! device.makeComputePipelineState(function: function)
    }
    
    var body: some View {
        VStack {
            RealityView { content in
                let mesh = try! generateIconsphereMesh(subdivisions: 5)
                let meshResource = try! await MeshResource(from: mesh)
                
                let material = try! await loadMaterial()
                let entity = ModelEntity(mesh: meshResource, materials: [material])
                content.add(entity)
                self.mesh = mesh
                
                storeOriginalVertices(from: mesh)
            }
        }
    }
    
    func storeOriginalVertices(from mesh: LowLevelMesh) {
        let vertexCount = mesh.vertexCapacity
        originalVertices = Array(repeating: VertexDataWith4ChannelColor(
            position: SIMD3<Float>(0, 0, 0),
            normal: SIMD3<Float>(0, 0, 0),
            uv: SIMD2<Float>(0, 0),
            color: SIMD4<Float>(0, 0, 0, 0)
        ), count: vertexCount)
        
        mesh.withUnsafeBytes(bufferIndex: 0) { rawBytes in
            let vertexBuffer = rawBytes.bindMemory(to: VertexDataWith4ChannelColor.self)
            for i in 0..<vertexCount {
                originalVertices[i] = vertexBuffer[i]
            }
        }
    }
    
    func updateMesh() {
        guard let mesh = mesh,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              !originalVertices.isEmpty else { return }
        let originalVertexBuffer = device.makeBuffer(
            bytes: originalVertices,
            length: originalVertices.count * MemoryLayout<VertexDataWith4ChannelColor>.size,
            options: .storageModeShared
        )
        let newVertexBuffer = mesh.replace(bufferIndex: 0, using: commandBuffer)
        
        computeEncoder.setComputePipelineState(computePipeline)
        computeEncoder.setBuffer(originalVertexBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(newVertexBuffer, offset: 0, index: 1)
        var params = BurnFadeParams(
            progress: burnSettings.burnAmount,
            scale: burnSettings.burnScale,
            hueRotate: burnSettings.hueRotate,
            edgeWidth: burnSettings.edgeWidth,
            emberRange: burnSettings.emberRange
        )
        computeEncoder.setBytes(&params, length: MemoryLayout<BurnFadeParams>.size, index: 2)
        
        let vertexCount = mesh.vertexCapacity
        let threadsPerGrid = MTLSize(width: vertexCount, height: 1, depth: 1)
        let threadsPerThreadgroup = MTLSize(width: 64, height: 1, depth: 1)
        
        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()
        commandBuffer.commit()
    }
}

#Preview {
    BurningSphereView()
}

extension BurningSphereView {
    func loadMaterial() async throws -> ShaderGraphMaterial {
        let baseURL = URL(string: "https://matt54.github.io/Resources/")!
        let fullURL = baseURL.appendingPathComponent("TextureCoordinatesColorMaterial.usda")
        let data = try Data(contentsOf: fullURL)
        let materialFilenameWithPath: String = "/Root/TextureCoordinateColorMaterial"
        return try await ShaderGraphMaterial(named: materialFilenameWithPath, from: data)
    }
}

extension BurningSphereView {
    func generateIconsphereMesh(radius: Float = 0.1, subdivisions: Int) throws -> LowLevelMesh {
        let t: Float = (1.0 + sqrt(5.0)) / 2.0
        
        var vertices: [SIMD3<Float>] = [
            SIMD3<Float>(-1, t, 0),
            SIMD3<Float>(1, t, 0),
            SIMD3<Float>(-1, -t, 0),
            SIMD3<Float>(1, -t, 0),
            
            SIMD3<Float>(0, -1, t),
            SIMD3<Float>(0, 1, t),
            SIMD3<Float>(0, -1, -t),
            SIMD3<Float>(0, 1, -t),
            
            SIMD3<Float>(t, 0, -1),
            SIMD3<Float>(t, 0, 1),
            SIMD3<Float>(-t, 0, -1),
            SIMD3<Float>(-t, 0, 1)
        ].map { normalize($0) * radius }
        
        var faces: [(Int, Int, Int)] = [
            (0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11),
            (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
            (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9),
            (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)
        ]
        
        var midpointCache: [Int: Int] = [:]
        func midpoint(_ v1: Int, _ v2: Int) -> Int {
            let key = v1 < v2 ? (v1 << 16) | v2 : (v2 << 16) | v1
            if let mid = midpointCache[key] {
                return mid
            }
            let midPoint = normalize((vertices[v1] + vertices[v2]) * 0.5) * radius
            
            vertices.append(midPoint)
            let index = vertices.count - 1
            midpointCache[key] = index
            return index
        }
        
        for _ in 0..<subdivisions {
            var newFaces: [(Int, Int, Int)] = []
            for (v1, v2, v3) in faces {
                let a = midpoint(v1, v2)
                let b = midpoint(v2, v3)
                let c = midpoint(v3, v1)
                newFaces.append((v1, a, c))
                newFaces.append((v2, b, a))
                newFaces.append((v3, c, b))
                newFaces.append((a, b, c))
            }
            faces = newFaces
        }
        
        let vertexCount = vertices.count
        let indexCount = faces.count * 3
        
        var desc = VertexDataWith4ChannelColor.descriptor
        desc.vertexCapacity = vertexCount
        desc.indexCapacity = indexCount
        
        let mesh = try LowLevelMesh(descriptor: desc)
        
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { rawBytes in
            let vertexBuffer = rawBytes.bindMemory(to: VertexDataWith4ChannelColor.self)
            for (i, position) in vertices.enumerated() {
                let normal = normalize(position)
                let u = (atan2(position.z, position.x) + Float.pi) / (2.0 * Float.pi)
                let v = (asin(position.y / radius) + Float.pi / 2.0) / Float.pi
                
                vertexBuffer[i] = VertexDataWith4ChannelColor(
                    position: position,
                    normal: normal,
                    uv: SIMD2<Float>(u, v),
                    color: SIMD4<Float>(0,0.0, 0, 1.0)
                )
            }
        }
        
        mesh.withUnsafeMutableIndices { rawIndices in
            let indexBuffer = rawIndices.bindMemory(to: UInt32.self)
            var index = 0
            for (v1, v2, v3) in faces {
                indexBuffer[index] = UInt32(v1)
                indexBuffer[index + 1] = UInt32(v2)
                indexBuffer[index + 2] = UInt32(v3)
                index += 3
            }
        }
        
        mesh.parts.replaceAll([
            LowLevelMesh.Part(
                indexCount: indexCount,
                topology: .triangle,
                bounds: BoundingBox(min: [-radius, -radius, -radius], max: [radius, radius, radius])
            )
        ])
        
        return mesh
    }
}
