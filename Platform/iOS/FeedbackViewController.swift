//
//  GameViewController.swift
//  fb iOS
//
//  Created by Eric O'Connell on 7/2/18.
//  Copyright © 2018 compassing. All rights reserved.
//

import UIKit
import MetalKit
import CoreMotion

// Our iOS specific view controller
class FeedbackViewController: UIViewController {

    var mtkView: MTKView!
    var feedbackian: Feedbackian! = nil

    let motion = CMMotionManager()

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let mtkView = self.view as? MTKView else {
            print("View of Gameview controller is not an MTKView")
            return
        }

        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported")
            return
        }

        mtkView.device = defaultDevice
        mtkView.delegate = self
        mtkView.backgroundColor = UIColor.black

        feedbackian = Feedbackian(
            device: defaultDevice,
            viewportSize: view.bounds.size,
            aspectRatio: Float(self.view.bounds.size.width / self.view.bounds.size.height),
            keySet: Set())

        motion.startDeviceMotionUpdates(to: OperationQueue.current!, withHandler: {
                (deviceMotion, error) -> Void in
                
                if(error == nil) {
                    self.handleDeviceMotion(deviceMotion!)
                } else {
                    //handle the error
                }
        })
    }
    
    func handleDeviceMotion(_ deviceMotion: CMDeviceMotion) {
       feedbackian.attitudeChanged(deviceMotion.rotationRate.x,
                                   deviceMotion.rotationRate.y,
                                   deviceMotion.rotationRate.z)
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
