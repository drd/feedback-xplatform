//
//  Metallic.swift
//  metalrefresh
//
//  Created by Eric O'Connell on 5/19/18.
//  Copyright © 2018 compassing. All rights reserved.
//

import MetalKit

let SIZE = 8192

struct Vertex {
    var x, y, z: Float
}

struct Triangle {
    var v1, v2, v3: Vertex
    var modelMatrix: float4x4
}

class Feedbackian {
    
    // MARK: ivars
    
    var device: MTLDevice!

    var shapeVertexBuffer: MTLBuffer! = nil
    var textureVertexBuffer: MTLBuffer! = nil
    var uniformsBuffer: MTLBuffer! = nil
    
    var shapePipelineState: MTLRenderPipelineState! = nil
    var texturePipelineState: MTLRenderPipelineState! = nil
    var feedbackPipelineState: MTLRenderPipelineState! = nil
    var finalPipelineState: MTLRenderPipelineState! = nil

    var commandQueue: MTLCommandQueue! = nil
    
    var shapeVertex: MTLFunction! = nil
    var shapeFragment: MTLFunction! = nil

    var textureVertex: MTLFunction! = nil
    var textureFragment: MTLFunction! = nil

    var feedbackVertex: MTLFunction! = nil

    var finalVertex: MTLFunction! = nil
    var finalFragment: MTLFunction! = nil
    
    var mainTexture: MTLTexture! = nil
    var tempTexture: MTLTexture! = nil
    
    var recorder: MetalVideoRecorder! = nil
    
    var cleared = false
    var state: State = State(outputSize: float2(0, 0),
                             position: float2(0, 0),
                             zoom: 1.0,
                             rotation: 0.0,
                             time: Float(drand48() * 5) + 3.7,
                             aspectRatio: 1.0,
                             colorOffset: Float(drand48() * 5) + 3.7,
                             nonlinearity: 0.0,
                             projectionMatrix: float4x4())

    var triangles = [Triangle]()

    var projectionMatrix: float4x4!
    
    var positionX:Float = 0.0
    var positionY:Float = 0.0
    var positionZ:Float = 1.0
    
    var rotationX:Float = 0.0
    var rotationY:Float = 0.0
    var rotationZ:Float = 0.0

    var scale:Float     = 1.5

    var aspectRatio: Float = 1.0
    var viewportSize: CGSize! = nil
    
    lazy var samplerState: MTLSamplerState? = Feedbackian.defaultSampler(self.device)
    lazy var nearestSamplerState: MTLSamplerState? = Feedbackian.nearestSampler(self.device)

    var controls = Controls()
    var keySet: Set<Key>
    
    // MARK: constructor
    
    init(device: MTLDevice, viewportSize: CGSize, aspectRatio: Float, keySet: Set<Key>) {
        self.device = device
        self.keySet = keySet
        self.viewportSize = viewportSize
        controls.setViewportSize(viewportSize)
        self.aspectRatio = aspectRatio
        projectionMatrix = float4x4.makePerspectiveViewAngle(
            float4x4.degrees(toRad: 85.0),
            aspectRatio: aspectRatio,
            nearZ: 0.01,
            farZ: 100.0)

        commandQueue = device.makeCommandQueue()

        initShaders()
        initBuffers()
        initTextures()
        initPipeline()
    }
    
    // MARK: State
    
    func keyChange(_ keysDown: Set<Key>) {
        keySet = keysDown
    }
    
    func updateState() {
        controls.control(keysDown: keySet)
        state.outputSize = float2(Float(viewportSize.width), Float(viewportSize.height))
        state.time += 0.01
        state.zoom = controls.zoom
        state.rotation = controls.rotation
        state.position = controls.position
        state.colorOffset = controls.colorOffset
        state.nonlinearity = controls.linearity // Float(sin(state.time))
        state.projectionMatrix = modelMatrix()
    }
    
    func modelMatrix() -> float4x4 {
        var matrix = float4x4()
        matrix.translate(positionX, y: positionY, z: positionZ)
        matrix.rotateAroundX(rotationX, y: rotationY, z: rotationZ)
        matrix.scale(scale, y: scale, z: scale)
        return matrix
    }

    
    func copyStateToBuffer() {
        state.aspectRatio = aspectRatio
        let bufferPointer = uniformsBuffer.contents()
        memcpy(bufferPointer, &state, MemoryLayout<State>.size)
    }
    
    func copyShapeToBuffer() {
        var outTriangles = [Vertex]()
        triangles.enumerated().forEach { (i, triangle) in
            let rX = Float(i) / Float(triangles.count) * Float.pi + state.time / 3.1
            let rY = Float(i) / Float(triangles.count) * Float.pi + Float.pi / 3 + state.time / 2.33
            let rZ = Float(i) / Float(triangles.count) * Float.pi + 2 * Float.pi / 3 + state.time  / 3.71
            var matrix = float4x4()
            matrix.rotateAroundX(rX, y: rY, z: rZ)
            let v1 = triangle.v1
            let v2 = triangle.v2
            let v3 = triangle.v3
            var rotated = matrix * float4(v1.x, v1.y, v1.z, 1)
            outTriangles.append(Vertex(x: rotated.x, y: rotated.y, z: rotated.z))
            rotated = matrix * float4(v2.x, v2.y, v2.z, 1)
            outTriangles.append(Vertex(x: rotated.x, y: rotated.y, z: rotated.z))
            rotated = matrix * float4(v3.x, v3.y, v3.z, 1)
            outTriangles.append(Vertex(x: rotated.x, y: rotated.y, z: rotated.z))
//            let outTriangle = Triangle(
//                v1: triangle.v1,
//                v2: triangle.v2,
//                v3: triangle.v3,
//                modelMatrix: matrix)
//            outTriangles.append(outTriangle)
        }
        let bufferPointer = shapeVertexBuffer.contents()
        let shapeBufferSize = outTriangles.count * MemoryLayout.size(ofValue: outTriangles[0])
        memcpy(bufferPointer, &outTriangles, shapeBufferSize)
    }
    
    func setAspectRatio(_ size: CGSize, _ aspect: Float) {
        print("Size!", size)
        viewportSize = size
        aspectRatio = aspect
        controls.setViewportSize(size)

        projectionMatrix = float4x4.makePerspectiveViewAngle(
            float4x4.degrees(toRad: 85.0),
            aspectRatio: aspectRatio,
            nearZ: 0.01,
            farZ: 100.0)

        // Video Recorder can't change size
        stopIfRecording()
    }
    
    func mouseMoved(_ dx: CGFloat, _ dy: CGFloat) {
        controls.mouseMoved(dx, dy)
    }
    
    func attitudeChanged(_ yaw: Double, _ pitch: Double, _ roll: Double) {
        controls.attitudeChanged(yaw, pitch, roll)
    }
    
    // MARK: Rendering

    func render(_ drawable: CAMetalDrawable) {
        // create a command buffer from the queue
        let commandBuffer = commandQueue.makeCommandBuffer()!

        updateState()
        copyStateToBuffer()
        copyShapeToBuffer()

        // Feedback
        
        // TODO: if zoom >2, JIT "MipMap" the source texture
        renderShape(commandBuffer)
        renderTexture(commandBuffer)
        renderFeedback(commandBuffer)

        // Render to screen
        renderToScreen(commandBuffer, drawableTexture: drawable.texture)

        // Screenshot?
        if keySet.contains(.Return) {
            toggleRecording()
            
            // TODO: investigate blit encoder, this no bueno
//            commandBuffer.addCompletedHandler { commandBuffer in
//                self.writeFrame(forTexture: self.mainTexture)
//            }
            keySet.remove(.Return)
        }

        if let rec = recorder {
            if rec.isRecording {
                let texture = drawable.texture
                commandBuffer.addCompletedHandler { commandBuffer in
                    rec.writeFrame(forTexture: texture)
                }
            }
        }

        // present & commit
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        if (!cleared) { cleared = true }

    }

    private func renderTexture(_ commandBuffer: MTLCommandBuffer) {
        // render pass 1: zoomRot main texture -> tempTexture
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = tempTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        // encode this render to the command buffer
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.label = "Feedback render encoder"
        renderEncoder.pushDebugGroup("Feedback render pass")

        renderEncoder.setRenderPipelineState(texturePipelineState)
        renderEncoder.setVertexBuffer(textureVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
        if let samplerState = getSampler() {
            renderEncoder.setFragmentSamplerState(samplerState, index: 0)
            renderEncoder.setFragmentTexture(mainTexture, index: 0)
        }
        // triangles: every 3 vertices is a shape; there will be 3 total
        renderEncoder.drawPrimitives(type: .triangle,
                                     vertexStart: 0,
                                     vertexCount: 6)

        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }
    
    private func getSampler() -> MTLSamplerState? {
        if (fabs(state.zoom) > 2) {
            return nearestSamplerState
        } else {
            return samplerState
        }
    }

    private func renderShape(_ commandBuffer: MTLCommandBuffer) {
        // render pass 2: draw shape on tempTexture
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = mainTexture
        renderPassDescriptor.colorAttachments[0].loadAction = cleared ? .load : .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor =
            MTLClearColor.init(red: 0, green: 0, blue: 0, alpha: 1.0)
        
        // encode this render to the command buffer
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.label = "Shape render encoder"
        renderEncoder.pushDebugGroup("Shape render pass")
        
        renderEncoder.setRenderPipelineState(shapePipelineState)
        renderEncoder.setVertexBuffer(shapeVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
//        renderEncoder.setTriangleFillMode(.lines)
        // triangles: every 3 vertices is a shape; there will be 3 total
        renderEncoder.drawPrimitives(type: .triangle,
                                     vertexStart: 0,
                                     vertexCount: shapeVertexBuffer.length / MemoryLayout<Float>.size / 3)
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }
    

    private func renderFeedback(_ commandBuffer: MTLCommandBuffer) {
        // render pass 3: feedback temp texture -> main texture
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = mainTexture
        renderPassDescriptor.colorAttachments[0].loadAction = cleared ? .load : .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor =
            MTLClearColor.init(red: 0, green: 0, blue: 0, alpha: 0)

        // encode this render to the command buffer
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.label = "Feedback render encoder"
        renderEncoder.pushDebugGroup("Feedback render pass")
        
        renderEncoder.setRenderPipelineState(feedbackPipelineState)
        renderEncoder.setVertexBuffer(textureVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        if let samplerState = getSampler() {
            renderEncoder.setFragmentSamplerState(samplerState, index: 0)
            renderEncoder.setFragmentTexture(tempTexture, index: 0)
        }
        // triangles: every 3 vertices is a shape; there will be 3 total
        renderEncoder.drawPrimitives(type: .triangle,
                                     vertexStart: 0,
                                     vertexCount: 6)
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }

    private func renderToScreen(_ commandBuffer: MTLCommandBuffer, drawableTexture: MTLTexture) {
        // render pass 4: render to screen
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawableTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        // encode this render to the command buffer
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.pushDebugGroup("Screen render pass")
        
        renderEncoder.setRenderPipelineState(finalPipelineState)
        renderEncoder.setVertexBuffer(textureVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        if let samplerState = getSampler() {
            renderEncoder.setFragmentSamplerState(samplerState, index: 0)
            renderEncoder.setFragmentTexture(mainTexture, index: 0)
        }
        // triangles: every 3 vertices is a shape; there will be 3 total
        renderEncoder.drawPrimitives(type: .triangle,
                                     vertexStart: 0,
                                     vertexCount: 6)
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }

    
    // MARK: Metal initialization
    
    private func initShaders() {
        // load the shaders into a library
        let defaultLibrary = device.makeDefaultLibrary()!
        
        shapeFragment = defaultLibrary.makeFunction(name: "shape_fragment")
        shapeVertex = defaultLibrary.makeFunction(name: "shape_vertex")

        textureFragment = defaultLibrary.makeFunction(name: "texture_fragment")
        textureVertex = defaultLibrary.makeFunction(name: "texture_vertex")

        feedbackVertex = defaultLibrary.makeFunction(name: "feedback_vertex")

        finalFragment = defaultLibrary.makeFunction(name: "final_fragment")
        finalVertex = defaultLibrary.makeFunction(name: "final_vertex")
    }
    
    private func initTextures() {
        // descriptor is used to create each texture; some settings are changed for tempTexture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: SIZE,
            height: SIZE,
            mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        
        // This will be the main texture for drawing the feedback
        mainTexture = device.makeTexture(descriptor: descriptor)
        mainTexture.label = "Main texture"

        // Configure descriptor for temp texture
        descriptor.storageMode = .private
        tempTexture = device.makeTexture(descriptor: descriptor)
        tempTexture.label = "Temp texture"
    }
    
    private func initBuffers() {
        // create the vertex buffers
        let textureVertexData:[Float] = [
            // Bottom-left
            -1.0, -1.0, 0.0, 0.0, 0.0,
             1.0, -1.0, 0.0, 1.0, 0.0,
            -1.0,  1.0, 0.0, 0.0, 1.0,
            
            // Top-right
             1.0, -1.0, 0.0, 1.0, 0.0,
             1.0,  1.0, 0.0, 1.0, 1.0,
            -1.0,  1.0, 0.0, 0.0, 1.0,
            ]
        let textureDataSize = textureVertexData.count * MemoryLayout.size(ofValue: textureVertexData[0])
        textureVertexBuffer = device.makeBuffer(bytes: textureVertexData,
                                                length: textureDataSize,
                                                options: MTLResourceOptions())
        textureVertexBuffer.label = "Texture vertBuffer"
        
        makeShape()
        
        let shapeDataSize = triangles.count * 3 * MemoryLayout<Vertex>.size
        shapeVertexBuffer = device.makeBuffer(bytes: triangles,
                                              length: shapeDataSize,
                                              options: MTLResourceOptions())
        shapeVertexBuffer.label = "Shape vertBuffer"
        
        uniformsBuffer = device.makeBuffer(length: MemoryLayout.size(ofValue: state),
                                           options: MTLResourceOptions())
        uniformsBuffer.label = "Uniforms"
    }
    
    private func makeShape() {

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
    }
    
    // MARK: Screenshots & recording    
    func toggleRecording() {
        if recorder?.isRecording == true {
            stopRecording(recorder)
        } else {
            if let fileUrl = newFileUrl("m4v") {
                recorder = MetalVideoRecorder(outputURL: fileUrl, size: viewportSize)
                recorder.startRecording()
            }
        }
    }
    
    private func stopIfRecording() {
        if let currentRecorder = recorder {
            if currentRecorder.isRecording {
                stopRecording(currentRecorder)
                recorder = nil
            }
        }
    }
    
    private func stopRecording(_ metalVideoRecorder: MetalVideoRecorder) {
        metalVideoRecorder.endRecording {
            print("Finished recording at \(metalVideoRecorder.recordingUrl.description)")
        }

    }
    
    private func newFileUrl(_ suffix: String) -> URL? {
        return outputDir?.appendingPathComponent("\(Date().description).\(suffix)")
    }
    
    private var outputDir: URL? {
        get {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let feedbackURL = documentsURL.appendingPathComponent("feedback", isDirectory: true)
            do {
                try FileManager.default.createDirectory(
                    at: feedbackURL,
                    withIntermediateDirectories: true,
                    attributes: nil)
                return feedbackURL
            } catch {
                return nil
            }
        }
    }
    
    // MARK: Initialization

    private func initPipeline() {
        do {
            // shape pipeline
            let shapePipelineStateDescriptor = MTLRenderPipelineDescriptor()
            shapePipelineStateDescriptor.vertexFunction = shapeVertex
            shapePipelineStateDescriptor.fragmentFunction = shapeFragment
            shapePipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            shapePipelineStateDescriptor.label = "Shape pipeline"
            shapePipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
            shapePipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperation.add;
            shapePipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperation.add;
            shapePipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactor.sourceAlpha;
            shapePipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactor.sourceAlpha;
            shapePipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactor.oneMinusSourceAlpha
            shapePipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactor.oneMinusSourceAlpha;
            try shapePipelineState = device.makeRenderPipelineState(descriptor: shapePipelineStateDescriptor)

            // texture pipeline
            let texturePipelineStateDescriptor = MTLRenderPipelineDescriptor()
            texturePipelineStateDescriptor.vertexFunction = textureVertex
            texturePipelineStateDescriptor.fragmentFunction = textureFragment
            texturePipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            texturePipelineStateDescriptor.label = "Texture pipeline"
            try texturePipelineState = device.makeRenderPipelineState(descriptor: texturePipelineStateDescriptor)

            // feedback pipeline
            let feedbackPipelineStateDescriptor = MTLRenderPipelineDescriptor()
            feedbackPipelineStateDescriptor.vertexFunction = feedbackVertex
            feedbackPipelineStateDescriptor.fragmentFunction = finalFragment
            feedbackPipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            feedbackPipelineStateDescriptor.label = "feedback pipeline"
            try feedbackPipelineState = device.makeRenderPipelineState(descriptor: feedbackPipelineStateDescriptor)

            // final pipeline
            let finalPipelineStateDescriptor = MTLRenderPipelineDescriptor()
            finalPipelineStateDescriptor.vertexFunction = finalVertex
            finalPipelineStateDescriptor.fragmentFunction = finalFragment
            finalPipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            finalPipelineStateDescriptor.label = "Final pipeline"
            try finalPipelineState = device.makeRenderPipelineState(descriptor: finalPipelineStateDescriptor)
        } catch let error {
            print("Unable to create pipeline state(s): \(error)")
        }
    }
    
    class func defaultSampler(_ device: MTLDevice) -> MTLSamplerState {
        let pSamplerDescriptor:MTLSamplerDescriptor? = MTLSamplerDescriptor();
        
        if let sampler = pSamplerDescriptor {
            sampler.minFilter             = MTLSamplerMinMagFilter.linear
            sampler.magFilter             = MTLSamplerMinMagFilter.linear
            sampler.mipFilter             = MTLSamplerMipFilter.nearest
            sampler.maxAnisotropy         = 1
            sampler.sAddressMode          = MTLSamplerAddressMode.mirrorRepeat
            sampler.tAddressMode          = MTLSamplerAddressMode.mirrorRepeat
            sampler.rAddressMode          = MTLSamplerAddressMode.mirrorRepeat
            sampler.normalizedCoordinates = true
            sampler.lodMinClamp           = 0
            sampler.lodMaxClamp           = Float.greatestFiniteMagnitude
        }
        else {
            print(">> ERROR: Failed creating a sampler descriptor!")
        }
        return device.makeSamplerState(descriptor: pSamplerDescriptor!)!
    }

    class func nearestSampler(_ device: MTLDevice) -> MTLSamplerState {
        let pSamplerDescriptor:MTLSamplerDescriptor? = MTLSamplerDescriptor();
        
        if let sampler = pSamplerDescriptor {
            sampler.minFilter             = MTLSamplerMinMagFilter.linear
            sampler.magFilter             = MTLSamplerMinMagFilter.linear
            sampler.mipFilter             = MTLSamplerMipFilter.nearest
            sampler.maxAnisotropy         = 1
            sampler.sAddressMode          = MTLSamplerAddressMode.mirrorRepeat
            sampler.tAddressMode          = MTLSamplerAddressMode.mirrorRepeat
            sampler.rAddressMode          = MTLSamplerAddressMode.mirrorRepeat
            sampler.normalizedCoordinates = true
            sampler.lodMinClamp           = 0
            sampler.lodMaxClamp           = Float.greatestFiniteMagnitude
        }
        else {
            print(">> ERROR: Failed creating a sampler descriptor!")
        }
        return device.makeSamplerState(descriptor: pSamplerDescriptor!)!
    }

}

extension CGSize {
    func wide() -> Bool {
        return width >= height
    }

    func tall() -> Bool {
        return height > width
    }
}


extension Date {
    func asString() -> String {
        return DateFormatter.sharedDateFormatter.string(from: self)
    }
}

extension DateFormatter {
    static var sharedDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        // Add your formatter configuration here
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter
    }()
}
