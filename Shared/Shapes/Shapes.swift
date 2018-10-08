//
//  Shapes.swift
//  fb iOS
//
//  Created by Eric O'Connell on 10/6/18.
//  Copyright © 2018 compassing. All rights reserved.
//

import Foundation

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
}

struct Triangle {
    var v1, v2, v3: Vertex
    var modelMatrix: float4x4
}

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
            
            triangles.append(Triangle(v1: outer0, v2: inner0, v3: outer, modelMatrix: modelMatrix))
            triangles.append(Triangle(v1: outer, v2: inner0, v3: inner, modelMatrix: modelMatrix))
            
            outer0 = outer
            inner0 = inner
        }
        
        return triangles
    }
}


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

