//
//  Shapes.swift
//  fb iOS
//
//  Created by Eric O'Connell on 10/6/18.
//  Copyright © 2018 compassing. All rights reserved.
//

import Foundation
import simd

protocol Shape {
    var geometry: [Triangle] { get }
}

class CachedShape : Shape {
    let shape: Shape
    
    lazy var geometry: [Triangle] = {
        return shape.geometry
    }()
    
    init(shape: Shape) {
        self.shape = shape
    }
}


class OutlinedPolygon : Shape {
    
    let sides: Int
    let outerRadius: Float
    let innerRadius: Float
    
    init(sides: Int, length: Float, width: Float) {
        self.sides = sides
        self.outerRadius = length
        self.innerRadius = length - width
    }
    
    var geometry: [Triangle] {
        var triangles = [Triangle]()
        let modelMatrix = float4x4()

        var outer0 = Vertex(0, outerRadius * sin(0), 0)
        var inner0 = Vertex(0, innerRadius * sin(0), 0)
        
        // start iterating at 1, and go full circle:
        for s in 1...sides + 1 {
            let theta = Float(s) / Float(sides) * 2 * Float.pi
            let outer = Vertex(cos(theta) * outerRadius, sin(theta) * outerRadius, 0)
            let inner = Vertex(cos(theta) * innerRadius, sin(theta) * innerRadius, 0)
            
            triangles.append(contentsOf: [
                Triangle(v1: outer0, v2: inner0, v3: outer, modelMatrix: modelMatrix),
                Triangle(v1: outer, v2: inner0, v3: inner, modelMatrix: modelMatrix)
            ])
            
            outer0 = outer
            inner0 = inner
        }
        
        return triangles
    }
}

let modelMatrix = float4x4()

class DiscOfShards : Shape {
    var geometry: [Triangle] {
        var triangles = [Triangle]()
        
        let dt = 0.1
        let base1 = 0.2, base2 = 0.4
        
        for theta in stride(from: 0.0, to: .pi * 2, by: dt) {
            var r1 = base1 + drand48() * 0.1 - 0.05
            var r2 = base2 + drand48() * 0.1 - 0.05
            let v1 = Vertex(
                x: Float(cos(theta) * r1),
                y: Float(sin(theta) * r1),
                z: 0.0
            )
            
            let v2 = Vertex(
                x: Float(cos(theta + dt / 2) * r2),
                y: Float(sin(theta + dt / 2) * r2),
                z: 0.0
            )
            
            let v3 = Vertex(
                x: Float(cos(theta - dt / 2) * r2),
                y: Float(sin(theta - dt / 2) * r2),
                z: 0.0
            )
            
            triangles.append(Triangle(
                v1: v1,
                v2: v2,
                v3: v3,
                modelMatrix: float4x4()))
            
            r1 = base1 + drand48() * 0.1 - 0.05
            r2 = base2 + drand48() * 0.1 - 0.05
            
            let v4 = Vertex(
                x: Float(cos(theta) * r1),
                y: Float(sin(theta) * r1),
                z: 0.0
            )
            
            let v5 = Vertex(
                x: Float(cos(theta + dt) * r1),
                y: Float(sin(theta + dt) * r1),
                z: 0.0
            )
            
            let v6 = Vertex(
                x: Float(cos(theta + dt / 2) * r2),
                y: Float(sin(theta + dt / 2) * r2),
                z: 0.0
            )
            
            triangles.append(Triangle(
                v1: v4,
                v2: v5,
                v3: v6,
                modelMatrix: float4x4()))
        }
        
        return triangles
    }
}


func quad(_ v1: float3, _ v2: float3, _ v3: float3, _ v4: float3, _ modelMatrix: float4x4) -> [Triangle] {
    return [
        Triangle(v1, v2, v3, modelMatrix: modelMatrix),
        Triangle(v1, v3, v4, modelMatrix: modelMatrix)
    ]
}


class ParametricCurve : Shape {
    var geometry: [Triangle] {
        let modelMatrix = float4x4()

        let sides = 10
        let dtt = .pi * 2 / Float(sides)
        let dt = Float(0.03)

        return stride(from: dt, to: 2 * .pi, by: dt).reduce([Triangle](), { triangles, t in
            let v0 = vertexAt(t - dt)
            let v1 = vertexAt(t)

            let tangent = (v1 - v0).normalized
            do {
                let r0 = try tangent.arbitraryPerpendicular() * 0.1
                var r1 = r0
                
                return stride(from: dtt, to: 2 * .pi + dtt, by: dtt).reduce(triangles, { ts, tt in
                    let m = tangent.axisRotationMatrix(theta: tt)
                    let rr = r0.homogenized * m // * 0.1
                    
                    defer { r1 = rr.xyz }
                    
                    // yucko back-indexing is horrible. maybe there's a nicer swift
                    // syntax for relative-to-end indices?
                    
                    // this will get the value of v1+r1 at the last index
                    let lastV0r1 = ts.count > sides * 2
                        ? ts[ts.count - sides * 2 + 1].v3.asFloat3
                        : v0 + r1

                    // this will get the value of v1+rr.xyz at the last index
                    let lastV0r2 = ts.count > sides * 2
                        ? ts[ts.count - sides * 2].v3.asFloat3
                        : v0 + rr.xyz

                    return ts + quad(
                        lastV0r1,
                        lastV0r2,
                        v1 + rr.xyz,
                        v1 + r1,
                        modelMatrix)
                })
            } catch {
                return triangles
            }
        })
    }

    func vertexAt(_ t: Float) -> float3 {
        return float3(
            x: 0.3 * sin(5 * t),
            y: 0.3 * cos(-3 * t),
            z: 0.3 * sin(3 * t))
    }
}
