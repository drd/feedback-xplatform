//
//  GameViewController.swift
//  fb macOS
//
//  Created by Eric O'Connell on 7/2/18.
//  Copyright © 2018 compassing. All rights reserved.
//

import Cocoa
import MetalKit


let half720p = CGSize(width: 640, height: 360)

// Our macOS specific view controller
class FeedbackViewController: NSViewController {

    @IBOutlet weak var mtkView: MTKView! {
        didSet {
            mtkView.delegate = self
            mtkView.preferredFramesPerSecond = 30
            mtkView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
            
            if let mtlLayer = mtkView.layer as? CAMetalLayer {
                mtlLayer.framebufferOnly = false
            }
        }
    }
    
    var device: MTLDevice! = nil
    var feedbackian: Feedbackian! = nil
    
    var keysDown = Set<Key>()
    var isFullscreen = false
    
    func myKeyHandler(with e: NSEvent) {
        if (e.modifierFlags.contains(.command)) {
            return
        }

        if (e.type == .flagsChanged) {
            if (e.modifierFlags.contains(.shift)) {
                keysDown.insert(.Shift)
            } else {
                keysDown.remove(.Shift)
            }
        } else if let key = Key(rawValue: e.keyCode) {
            if (e.type == .keyDown) {
                keysDown.insert(key)
            } else {
                keysDown.remove(key)
            }
        }

        feedbackian.keyChange(keysDown)
    }
    
    override func keyUp(with event: NSEvent) {
        myKeyHandler(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        myKeyHandler(with: event)
    }
    
    override func flagsChanged(with event: NSEvent) {
        myKeyHandler(with: event)
    }
    
    override func mouseMoved(with event: NSEvent) {
        feedbackian.mouseMoved(event.deltaX, event.deltaY)
        
        if (isFullscreen) {
            CGWarpMouseCursorPosition(CGPoint(x: view.bounds.size.width/2, y: view.bounds.size.height/2))
        }
    }
    
    override func viewDidAppear() {
        if let window = mtkView.window {
            window.makeFirstResponder(self)
            window.acceptsMouseMovedEvents = true
            window.delegate = self
        }        
    }
    
    override func viewDidLoad() {
        // create device
        device = MTLCreateSystemDefaultDevice()
        mtkView.device = device
        
        feedbackian = Feedbackian(
            device: device,
            viewportSize: view.bounds.size,
            aspectRatio: Float(self.view.bounds.size.width / self.view.bounds.size.height),
            keySet: keysDown)
    }
}

extension FeedbackViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        NSLog("mtkView(view: \(view) size: \(size))")
        feedbackian.setAspectRatio(
            size,
            Float(size.width / size.height))
    }
    
    func draw(in view: MTKView) {
        if let drawable = view.currentDrawable {
            feedbackian.render(drawable)
        }
    }
}

extension FeedbackViewController: NSWindowDelegate {
    func windowDidEnterFullScreen(_ notification: Notification) {
        CGDisplayHideCursor(CGMainDisplayID())
        isFullscreen = true
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        CGDisplayShowCursor(CGMainDisplayID())
        isFullscreen = false
    }
}
