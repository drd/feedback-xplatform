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
    var geometry: [Vertex] { get }
}

class CachedShape : Shape {
    let shape: Shape
    
    lazy var geometry: [Vertex] = {
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
    
    var geometry: [Vertex] {
        var vertices = [Vertex]()
        let normal = float3(0, 0, 1)
        let color = float4(0.7, 0.3, 0.3, 1.0)

        var outer0 = float3(0, outerRadius * sin(0), 0)
        var inner0 = float3(0, innerRadius * sin(0), 0)
        
        // start iterating at 1, and go full circle:
        for s in 1...sides + 1 {
            let theta = Float(s) / Float(sides) * 2 * .pi
            let outer = float3(cos(theta) * outerRadius, sin(theta) * outerRadius, 0)
            let inner = float3(cos(theta) * innerRadius, sin(theta) * innerRadius, 0)
            
            vertices.append(contentsOf: [
                outer0, inner0, outer,
                outer, inner0, inner
                ].map { position in
                    return Vertex(position: position, normal: normal, color: color)
            })
            
            outer0 = outer
            inner0 = inner
        }
        
        return vertices
    }
}

class DiscOfShards : Shape {
    var geometry: [Vertex] {
        var vertices = [Vertex]()
        
        let normal = float3(0, 0, 1)
        let color = float4(0.7, 0.3, 0.3, 1.0)

        let dt = 0.1
        let base1 = 0.2, base2 = 0.4
        
        for theta in stride(from: 0.0, to: .pi * 2, by: dt) {
            var r1 = base1 + drand48() * 0.1 - 0.05
            var r2 = base2 + drand48() * 0.1 - 0.05
            let v1 = float3(
                x: Float(cos(theta) * r1),
                y: Float(sin(theta) * r1),
                z: 0.0
            )
            
            let v2 = float3(
                x: Float(cos(theta + dt / 2) * r2),
                y: Float(sin(theta + dt / 2) * r2),
                z: 0.0
            )
            
            let v3 = float3(
                x: Float(cos(theta - dt / 2) * r2),
                y: Float(sin(theta - dt / 2) * r2),
                z: 0.0
            )
            
            vertices.append(contentsOf: [v1, v2, v3].map { position in
                return Vertex(position: position, normal: normal, color: color)
            })
            
            r1 = base1 + drand48() * 0.1 - 0.05
            r2 = base2 + drand48() * 0.1 - 0.05
            
            let v4 = float3(
                x: Float(cos(theta) * r1),
                y: Float(sin(theta) * r1),
                z: 0.0
            )
            
            let v5 = float3(
                x: Float(cos(theta + dt) * r1),
                y: Float(sin(theta + dt) * r1),
                z: 0.0
            )
            
            let v6 = float3(
                x: Float(cos(theta + dt / 2) * r2),
                y: Float(sin(theta + dt / 2) * r2),
                z: 0.0
            )
            
            vertices.append(contentsOf: [v4, v5, v6].map { position in
                return Vertex(position: position, normal: normal, color: color)
            })
        }
        
        return vertices
    }
}


func quad(_ v1: Vertex, _ v2: Vertex, _ v3: Vertex, _ v4: Vertex) -> [Vertex] {
    return [
        v1, v2, v3,
        v1, v3, v4
    ]
}


class ParametricCurve : Shape {

    var color = float4(0.7, 0.8, 0.3, 0.7)
    let sides = 30

    lazy var geometry: [Vertex] = {
//        let backReference = (sides + 1) * 2 * 3 // 2 triangles per quad, 3 vertices per triangle
        let dtt = .pi * 2 / Float(sides)
        let dt = Float(0.01)

        return stride(from: dt, to: 2 * .pi + dt, by: dt).reduce([[Vertex]](), { vertices, t in
            let segmentStart = positionAt(t - dt)
            let segmentEnd = positionAt(t)

            let tangent = (segmentEnd - segmentStart).normalized
            do {
                let r0 = try tangent.arbitraryPerpendicular() * 0.075
                var r1 = r0
                
                return vertices + [(stride(from: dtt, to: 2 * .pi + dtt, by: dtt).enumerated().reduce([Vertex](), { vs, pair in
                    let (offset, tt) = pair
                    let m = tangent.axisRotationMatrix(theta: tt)
                    let rr = r0.homogenized * m // * 0.1
                    
                    defer { r1 = rr.xyz }
                    
                    // yucko back-indexing is horrible. maybe there's a nicer swift
                    // syntax for relative-to-end indices?
                    
                    // this will get the value of v1+r1 at the last index
                    let p1 = vertices.count > 0
                        ? vertices[vertices.count - 1][offset * 6 + 5].position.xyz
                        : segmentStart + r1

                    // this will get the value of v1+rr.xyz at the last index
                    let p2 = vertices.count > 0
                        ? vertices[vertices.count - 1][offset * 6 + 2].position.xyz
                        : segmentStart + rr.xyz
                    
                    let p3 = segmentEnd + rr.xyz
                    let p4 = segmentEnd + r1
                    
                    let n1 = (p1 - segmentStart).normalized
                    let n2 = (p2 - segmentStart).normalized
                    let n3 = (p3 - segmentEnd).normalized
                    let n4 = (p4 - segmentEnd).normalized

                    let v1 = Vertex(position: p1, normal: n1, color: color) //p1.homogenized)
                    let v2 = Vertex(position: p2, normal: n2, color: color) //p2.homogenized)
                    let v3 = Vertex(position: p3, normal: n3, color: color) //p3.homogenized)
                    let v4 = Vertex(position: p4, normal: n4, color: color) //p4.homogenized)

                    return vs + quad(v1, v2, v3, v4)
                }))]
            } catch {
                return vertices
            }
        }).reduce([Vertex](), { accumulator, vertices in
            return accumulator + vertices
        })
    }()

    func positionAt(_ t: Float) -> float3 {
        return float3(
            x: 0.3 * sin( 5 * t),
            y: 0.3 * cos(-13 * t),
            z: 0.3 * sin( 7 * t))
    }
}
