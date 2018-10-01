//
//  MetalVideoRecorder.swift
//  metalrefresh
//
//  Created by Eric O'Connell on 5/28/18.
//  Copyright © 2018 compassing. All rights reserved.
//

import Foundation
import AVKit

import os.log

// Thanks warrenm: https://stackoverflow.com/a/43860229/4021735
class MetalVideoRecorder {
    var isRecording = false
    var recordingUrl: URL! = nil
    
    private var frameCount = 0
    
    private var assetWriter: AVAssetWriter
    private var assetWriterVideoInput: AVAssetWriterInput
    private var assetWriterPixelBufferInput: AVAssetWriterInputPixelBufferAdaptor
    
    init?(outputURL url: URL, size: CGSize) {
        do {
            os_log("attempting to init at url %{public}@ size %@", url.absoluteString, size.debugDescription)
            recordingUrl = url
            assetWriter = try AVAssetWriter(outputURL: url, fileType: AVFileType.m4v)
        } catch {
            os_log("Failed to initialize %{public}@", error.localizedDescription)
            return nil
        }
        
        let outputSettings: [String: Any] = [ AVVideoCodecKey : AVVideoCodecType.h264,
                                              AVVideoWidthKey : size.width,
                                              AVVideoHeightKey : size.height ]
        
        assetWriterVideoInput = AVAssetWriterInput(
            mediaType: AVMediaType.video,
            outputSettings: outputSettings)
        assetWriterVideoInput.expectsMediaDataInRealTime = true
        
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String : size.width,
            kCVPixelBufferHeightKey as String : size.height ]
        
        assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: assetWriterVideoInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes)
        
        assetWriter.add(assetWriterVideoInput)
        os_log("completed initialization")
    }
    
    func startRecording() {
        os_log("beginning recording")
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: kCMTimeZero)

        os_log("recording has begun")

        isRecording = true
    }
    
    func endRecording(_ completionHandler: @escaping () -> ()) {
        os_log("ending recording")
        isRecording = false
        
        assetWriterVideoInput.markAsFinished()
        assetWriter.finishWriting(completionHandler: completionHandler)
        os_log("recording completed")
    }
    
    func writeFrame(forTexture texture: MTLTexture) {
        os_log("attempting to write frame for texture %{public}@ (%{public}@)",
               texture.debugDescription ?? texture.label ?? "tex",
               isRecording.description)
        if !isRecording {
            return
        }
        
        while !assetWriterVideoInput.isReadyForMoreMediaData {}

        guard let pixelBufferPool = assetWriterPixelBufferInput.pixelBufferPool else {
            os_log("Pixel buffer asset writer input did not have a pixel buffer pool available; cannot retrieve frame")
            return
        }
        
        var maybePixelBuffer: CVPixelBuffer? = nil
        let status  = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &maybePixelBuffer)
        if status != kCVReturnSuccess {
            os_log("Could not get pixel buffer from asset writer input; dropping frame...")
            return
        }
        
        guard let pixelBuffer = maybePixelBuffer else {
            os_log("failed to get pixel buffer")
            return
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let pixelBufferBytes = CVPixelBufferGetBaseAddress(pixelBuffer)!
        
        // Use the bytes per row value from the pixel buffer since its stride may be rounded up to be 16-byte aligned
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        
        texture.getBytes(pixelBufferBytes,
                         bytesPerRow: bytesPerRow,
                         from: region,
                         mipmapLevel: 0)
        
        let presentationTime = CMTimeMakeWithSeconds(Double(frameCount) / 30, 240)
        assetWriterPixelBufferInput.append(pixelBuffer, withPresentationTime: presentationTime)
        frameCount += 1
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    }
}
