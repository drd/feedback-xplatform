//
//  Events.swift
//  metalrefresh
//
//  Created by Eric O'Connell on 5/26/18.
//  Copyright © 2018 compassing. All rights reserved.
//

import Foundation
import QuartzCore
import simd


extension Set where Element: Equatable {
    func containsAny(_ atLeastOneOf: [Element]) -> Bool {
        for element in atLeastOneOf {
            if (contains(element)) {
                return true
            }
        }
        return false
    }  
    
    func containsOnly(_ element: Element) -> Bool {
        return count == 1 && contains(element)
    }
}

extension Set {
    var isNonEmpty: Bool {
        get {
            return !isEmpty
        }
    }
}

func resetControls(_ controls: inout Controls) {
    controls.state.reset()
}

protocol Controllable {
    
}

enum MouseMode {
    case zoom, pan
}

extension float2: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
    }
    
    public init(from decoder: Decoder) throws {
        var values = try decoder.unkeyedContainer()
        let x = try values.decode(Float.self)
        let y = try values.decode(Float.self)
        self.init(x, y)
    }
}

struct FeedbackState: Codable {
    var zoom: Float = 0
    var dZ: Float = 0
    
    var rotation: Float = 0
    var dR: Float = 0
    
    var position: float2 = float2(0, 0)
    var dP: float2 = float2(0, 0)
    
    var colorOffset: Float = 0
    var dCO: Float = 0
    
    var linearity: Float = 0
    var dL: Float = 0
    
    mutating func reset() {
        zoom = 1.0
        dZ = 0.0
        
        rotation = 0.0
        dR = 0.0
        
        position = float2(0, 0)
        dP = float2(0, 0)
        
        colorOffset = 0
        dCO = 0.0
        
        linearity = 0
        dL = 0
    }
    
    mutating func normalize() {
        rotation = (rotation / (2 * Float.pi)).truncatingRemainder(dividingBy: 1.0) * 2 * Float.pi
        position = float2(
            constrain(position.x, between: -1, and: 1),
            constrain(position.y, between: -1, and: 1)
        )
    }
    
    func constrain(_ val: Float, between low: Float, and high: Float) -> Float {
        let t = (val - low) / (high - low)
        return low + (high - low) * (t - t.rounded(.down))
    }
}

extension FeedbackState {
    static func +(lhs: FeedbackState, rhs: FeedbackState) -> FeedbackState {
        return FeedbackState(
            zoom: lhs.zoom + rhs.zoom,
            dZ: lhs.dZ + rhs.dZ,
            rotation: lhs.rotation + rhs.rotation,
            dR: lhs.dR + rhs.dR,
            position: lhs.position + rhs.position,
            dP: lhs.dP + rhs.dP,
            colorOffset: lhs.colorOffset + rhs.colorOffset,
            dCO: lhs.dCO + rhs.dCO,
            linearity: lhs.linearity + rhs.linearity,
            dL: lhs.dL + rhs.dL
        )
    }
    
    static func +=(lhs: inout FeedbackState, rhs: FeedbackState) {
        lhs = lhs + rhs
    }

    static func -(lhs: FeedbackState, rhs: FeedbackState) -> FeedbackState {
        return FeedbackState(
            zoom: lhs.zoom - rhs.zoom,
            dZ: lhs.dZ - rhs.dZ,
            rotation: lhs.rotation - rhs.rotation,
            dR: lhs.dR - rhs.dR,
            position: lhs.position - rhs.position,
            dP: lhs.dP - rhs.dP,
            colorOffset: lhs.colorOffset - rhs.colorOffset,
            dCO: lhs.dCO - rhs.dCO,
            linearity: lhs.linearity - rhs.linearity,
            dL: lhs.dL - rhs.dL
        )
    }
    
    static func -=(lhs: inout FeedbackState, rhs: FeedbackState) {
        lhs = lhs - rhs
    }
    
    static func /(lhs: FeedbackState, rhs: Float) -> FeedbackState {
        return FeedbackState(
            zoom: lhs.zoom / rhs,
            dZ: lhs.dZ / rhs,
            rotation: lhs.rotation / rhs,
            dR: lhs.dR / rhs,
            position: lhs.position / rhs,
            dP: lhs.dP / rhs,
            colorOffset: lhs.colorOffset / rhs,
            dCO: lhs.dCO / rhs,
            linearity: lhs.linearity / rhs,
            dL: lhs.dL / rhs
        )
    }

    static func *(lhs: FeedbackState, rhs: Float) -> FeedbackState {
        return FeedbackState(
            zoom: lhs.zoom * rhs,
            dZ: lhs.dZ * rhs,
            rotation: lhs.rotation * rhs,
            dR: lhs.dR * rhs,
            position: lhs.position * rhs,
            dP: lhs.dP * rhs,
            colorOffset: lhs.colorOffset * rhs,
            dCO: lhs.dCO * rhs,
            linearity: lhs.linearity * rhs,
            dL: lhs.dL * rhs
        )
    }
}

class Controls {
    
    let controlMap: [WritableKeyPath<FeedbackState,Float>:(Set<Key>,Set<Key>,WritableKeyPath<FeedbackState,Float>)] = [
        // Property    Decrement     Increment      Delta
        \FeedbackState.zoom        : ([.Up, .I],   [.Down, .K],   \FeedbackState.dZ),
        \FeedbackState.rotation    : ([.Left, .J], [.Right, .L],  \FeedbackState.dR),
        \FeedbackState.position.x  : ([.A],        [.D],          \FeedbackState.dP.x),
        \FeedbackState.position.y  : ([.S],        [.W],          \FeedbackState.dP.y),
        \FeedbackState.colorOffset : ([.X],        [.Z],          \FeedbackState.dCO),
        \FeedbackState.linearity   : ([.Comma],    [.Period],     \FeedbackState.dL),
    ]
    
    let DD: Float = 0.00005
    let MAX: Float = 0.1
    let FALLOFF: Float = 0.95
    
    var viewportSize: CGSize! = nil

    var mouseMode = MouseMode.zoom

    var state = FeedbackState()

    var zoom: Float { return state.zoom }
    var rotation: Float { return state.rotation }
    var position: float2 { return state.position }
    var linearity: Float { return state.linearity }
    var colorOffset: Float { return state.colorOffset }
    
    var presets: [Key: FeedbackState] = [:]
    var lastStored: Key?
    var transition: Transition?

    // TODO: Controls sould have a State, or operate on a State?
    init() {
        state.reset()
    }
    
    func setViewportSize(_ size: CGSize) {
        viewportSize = size
    }
    
    func mouseMoved(_ dx: CGFloat, _ dy: CGFloat) {
        let adjustedDx = Float(dx / viewportSize.width) / 3
        let adjustedDy = Float(dy / viewportSize.height) / 3

        switch mouseMode {
        case .zoom:
            state.dR += adjustedDx
            state.dZ += adjustedDy
        case .pan:
            state.dP += float2(adjustedDx, adjustedDy)
        }
    }
    
    func attitudeChanged(_ yaw: Double, _ pitch: Double, _ roll: Double) {
        print("x: \(yaw) y: \(pitch) z: \(roll)")
        state.dR += Float(roll / 3000.0)
        state.dZ += Float(yaw / 3000.0)
        state.dP += float2(Float(sin(pitch) / 3000.0), Float(cos(pitch) / 3000.0))
    }
    
    // TODO: map keys -> commands, and operate on commands here
    //       .. eg, mouse movements can turn into parameterized commands so they're
    //       handled relatively similarly (differential vs absolute needs to be accounted for)
    func control(keysDown: Set<Key>) {
//        if (keysDown.count > 0) {
//            animationFrames = 0
//        }

        if let currentTransition = transition {
            if !currentTransition.complete {
                state = currentTransition.advance()
            }
        }
        
//        if (animationFrames > 0) {
//            animationFrames -= 1
//            let easingAmount = Curve.cubic.easeInOut(Float(ANIMATION_FRAMES - animationFrames) / Float(ANIMATION_FRAMES))
//            state = animateFrom + (animateTo - animateFrom) * easingAmount
//        }

        if (keysDown.contains(.Tab)) {
            mouseMode = mouseMode == .zoom ? .pan : .zoom
        }

        if (keysDown.contains(.Space)) {
            state.reset()
        }
        
        controlMap.forEach { pair in
            let propertyKeyPath = pair.key
            let (decr, incr, deltaKeyPath) = pair.value
            
            let dd = DD * (keysDown.contains(.Shift) ? 10.0 : 1.0)
            
            if decr.intersection(keysDown).isNonEmpty {
                state[keyPath: deltaKeyPath] -= dd
            } else if incr.intersection(keysDown).isNonEmpty {
                state[keyPath: deltaKeyPath] += dd
            } else {
                state[keyPath: deltaKeyPath] *= FALLOFF
            }
            
            state[keyPath: propertyKeyPath] += state[keyPath: deltaKeyPath]
        }
        
        state.normalize()

        if let numberKey =
            keysDown
                .filter({ (key: Key) -> Bool in key.isNumeric })
                .first {
            if (keysDown.contains(.Shift)) {
                storePreset(for: numberKey)
            } else {
                recallPreset(for: numberKey)
            }
        }
    }
    
    func storePreset(for key: Key) {
        print("Storing state for key \(key)")
        presets[key] = state
    }
    
    func recallPreset(for key: Key) {
        if let storedState = presets[key] {
            print("Updating state to \(storedState)")
            if (self.transition?.complete == false) {
                self.transition = Transition(from: self.transition!, to: storedState)
            } else {
                self.transition = Transition(from: state, to: storedState)
            }
//            // TODO: compose transitions
//            animationFrames = ANIMATION_FRAMES
//            animateFrom = state
//            animateTo = storedState
        }
    }
}

let ANIMATION_FRAMES = 180

class Transition {
    let fromState: FeedbackState?
    let fromTransition: Transition?
    let to: FeedbackState

    var frameCount = 0
    
    var complete: Bool {
        return frameCount == ANIMATION_FRAMES
    }
    
    var easingAmount: Float {
        return Curve.cubic.easeInOut(Float(frameCount) / Float(ANIMATION_FRAMES))
    }
    
    init(from: FeedbackState, to: FeedbackState) {
        self.fromState = from
        self.fromTransition = nil
        self.to = to
    }
    
    init(from: Transition, to: FeedbackState) {
        self.fromState = nil
        self.fromTransition = from
        self.to = to
    }
    
    func advance() -> FeedbackState {
        if (self.complete) {
            return self.to
        }

        let from = fromTransition?.advance() ?? fromState!
        let nextState = from + (to - from) * self.easingAmount
        frameCount += 1
        return nextState
    }
}

