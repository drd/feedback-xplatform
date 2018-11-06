//
//  Uniforms.swift
//  metalrefresh
//
//  Created by Eric O'Connell on 5/26/18.
//  Copyright © 2018 compassing. All rights reserved.
//

import Foundation
import simd


struct State {
    var outputSize: float2
    var position: float2
    var zoom: Float
    var rotation: Float
    var time: Float
    var aspectRatio: Float
    var colorOffset: Float
    var nonlinearity: Float
    
    var projectionMatrix: float4x4
    var light: float4
}
