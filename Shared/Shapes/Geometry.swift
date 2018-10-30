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
    
    var asVertex: Vertex {
        return Vertex(x, y, z)
    }
    
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
    init (_ x: Float, _ y: Float, _ z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    init (x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    var x, y, z: Float
    
    var normalized: Vertex {
        let mag = sqrt(x * x + y * y + z * z)
        return Vertex(
            x / mag,
            y / mag,
            z / mag
        )
    }
    
    var asFloat3: float3 {
        return float3(x, y, z)
    }
    
    static func -(lhs: Vertex, rhs: Vertex) -> Vertex {
        return Vertex(
            rhs.x - lhs.x,
            rhs.y - lhs.y,
            rhs.z - lhs.z
        )
    }
    
    
}

struct Triangle {
    init(_ v1: float3, _ v2: float3, _ v3: float3, modelMatrix: float4x4) {
        self.v1 = v1.asVertex
        self.v2 = v2.asVertex
        self.v3 = v3.asVertex
        self.modelMatrix = modelMatrix
    }

    init(v1: Vertex, v2: Vertex, v3: Vertex, modelMatrix: float4x4) {
        self.v1 = v1
        self.v2 = v2
        self.v3 = v3
        self.modelMatrix = modelMatrix
    }

    var v1, v2, v3: Vertex
    var modelMatrix: float4x4
}
