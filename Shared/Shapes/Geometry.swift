//
//  Geometry.swift
//  fb
//
//  Created by Eric O'Connell on 10/17/18.
//  Copyright © 2018 compassing. All rights reserved.
//

import Foundation

enum GeometryError: Error {
    case ZeroVector
}

extension float3 {
    var normalized: float3 {
        let mag = sqrt(x * x + y * y + z * z)
        return float3(
            x / mag,
            y / mag,
            z / mag
        )
    }
    
    var homogenized: float4 {
        return float4(x, y, z, 1)
    }
    
//    var asVertex: Vertex {
//        return Vertex(x, y, z)
//    }
    
    // cross product
    func cross(_ rhs: float3) -> float3 {
        return float3(
            self.y * rhs.z - self.z * rhs.y,
            self.z * rhs.x - self.x * rhs.z,
            self.x * rhs.y - self.y * rhs.x
        )
    }
    
    /*
     From https://codereview.stackexchange.com/questions/43928/algorithm-to-get-an-arbitrary-perpendicular-vector:
    */
    func arbitraryPerpendicular() throws -> float3 {
        if x == 0 && y == 0 {
            if z == 0 {
                throw GeometryError.ZeroVector
            }
            return float3(0, 1, 0)
        }
        return float3(-y, x, 0)
    }

    func axisRotationMatrix(theta: Float) -> float4x4 {
        return float4x4.makeRotate(theta, x, y, z)
    }
}

extension float4 {
    var xyz: float3 {
        return float3(x, y, z)
    }
}

struct Vertex {
    let position: float4
    let normal: float4
    let color: float4
    
    init (position: float4, normal: float4, color: float4) {
        self.position = position
        self.normal = normal
        self.color = color
    }
    
    init (position: float3, normal: float3, color: float4) {
        self.position = position.homogenized
        self.normal = normal.homogenized
        self.color = color
    }
    
    static func *(lhs: float4x4, rhs: Vertex) -> Vertex {
        return Vertex(position: lhs * rhs.position, normal: lhs * rhs.normal, color: rhs.color)
    }
}

//struct Triangle {
//    init(_ v1: float3, _ v2: float3, _ v3: float3, modelMatrix: float4x4) {
//        self.v1 = v1.asVertex
//        self.v2 = v2.asVertex
//        self.v3 = v3.asVertex
//        self.modelMatrix = modelMatrix
//    }
//
//    init(v1: Vertex, v2: Vertex, v3: Vertex, modelMatrix: float4x4) {
//        self.v1 = v1
//        self.v2 = v2
//        self.v3 = v3
//        self.modelMatrix = modelMatrix
//    }
//
//    var v1, v2, v3: Vertex
//    var modelMatrix: float4x4
//}
