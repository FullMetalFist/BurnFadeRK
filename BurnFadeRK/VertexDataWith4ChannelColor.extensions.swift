//
//  VertexDataWith4ChannelColor.extensions.swift
//  BurnFadeRK
//
//  Created by Michael Vilabrera on 9/10/25.
//


import Foundation
import RealityKit

extension VertexDataWith4ChannelColor {
    static var vertexAttributes: [LowLevelMesh.Attribute] = [
        .init(semantic: .position, format: .float3, offset: MemoryLayout<Self>.offset(of: \.position)!),
        .init(semantic: .normal, format: .float3, offset: MemoryLayout<Self>.offset(of: \.normal)!),
        .init(semantic: .uv0, format: .float2, offset: MemoryLayout<Self>.offset(of: \.uv)!),
        .init(semantic: .uv2, format: .float4, offset: MemoryLayout<Self>.offset(of: \.color)!)
    ]
    
    static var vertexLayouts: [LowLevelMesh.Layout] = [
        .init(bufferIndex: 0, bufferStride: MemoryLayout<Self>.stride)
    ]
    
    static var descriptor: LowLevelMesh.Descriptor {
        var desc = LowLevelMesh.Descriptor()
        desc.vertexAttributes = VertexDataWith4ChannelColor.vertexAttributes
        desc.vertexLayouts = VertexDataWith4ChannelColor.vertexLayouts
        desc.indexType = .uint32
        return desc
    }
    
    @MainActor static func initializeMesh(vertexCapacity: Int, indexCapacity: Int) throws -> LowLevelMesh {
        var desc = VertexDataWith4ChannelColor.descriptor
        desc.vertexCapacity = vertexCapacity
        desc.indexCapacity = indexCapacity
        return try LowLevelMesh(descriptor: desc)
    }
}
