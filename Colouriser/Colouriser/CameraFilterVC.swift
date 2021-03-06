//
//  CameraFilterVC.swift
//  Colouriser
//
//  Created by Vitaliy Krynytskyy on 20/02/2018.
//  Copyright © 2018 Vitaliy Krynytskyy. All rights reserved.
//

import AVFoundation
import UIKit

class CameraFilterVC: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // live camera filter
    var captureSession = AVCaptureSession()
    var backCamera: AVCaptureDevice?
    var frontCamera: AVCaptureDevice?
    var currentCamera: AVCaptureDevice?
    var photoOutput: AVCapturePhotoOutput?
    var orientation: AVCaptureVideoOrientation = .portrait
    let context = CIContext()
    
    var previouslySetColourblindness: String = ""
    
    let concurrentQueue = DispatchQueue(label: "cameraFilterQueue", attributes: .concurrent)

    @IBOutlet weak var filteredImage: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.concurrentQueue.async {
            self.setupDevice()
            self.setupInputOutput()
        }
        
        // check if the value was correctly set
        if (UserDefaults.standard.value(forKey: "typeOfColourblindness") as? String) != nil {
            
            print("Using: \(UserDefaults.standard.value(forKey: "typeOfColourblindness") as! String)")
            
            if (UserDefaults.standard.value(forKey: "typeOfColourblindness") as! String != "Select type of colourblindness: ") {
                previouslySetColourblindness = UserDefaults.standard.value(forKey: "typeOfColourblindness") as! String
            } else {
                previouslySetColourblindness = "protanopia"
            }
        } else {  // default to a value
            previouslySetColourblindness = "protanopia"
        }
        
        
    }
    
    func setupDevice() {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
        let devices = deviceDiscoverySession.devices
        
        for device in devices {
            if device.position == AVCaptureDevice.Position.back {
                backCamera = device
            }
            else if device.position == AVCaptureDevice.Position.front {
                frontCamera = device
            }
        }
        
        currentCamera = backCamera
    }
    
    func setupInputOutput() {
        do {
            //setupCorrectFramerate(currentCamera: currentCamera!)
            let captureDeviceInput = try AVCaptureDeviceInput(device: currentCamera!)
            //depending what format you choose, the speed at which the pixels get filtered increases
            captureSession.sessionPreset = AVCaptureSession.Preset.low

            if captureSession.canAddInput(captureDeviceInput) {
                captureSession.addInput(captureDeviceInput)
            }
            let videoOutput = AVCaptureVideoDataOutput()
            
            videoOutput.setSampleBufferDelegate(self, queue: self.concurrentQueue)
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
            captureSession.startRunning()
        } catch {
            print(error)
        }
    }
    
    func setupCorrectFramerate(currentCamera: AVCaptureDevice) {
        for vFormat in currentCamera.formats {
            //see available types
            //print("\(vFormat) \n")
            
            var ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
            let frameRates = ranges[0]
            
            do {
                //set to 240fps - available types are: 30, 60, 120 and 240 and custom
                // lower framerates cause major stuttering
                if frameRates.maxFrameRate == 60 {
                    try currentCamera.lockForConfiguration()
                    currentCamera.activeFormat = vFormat as AVCaptureDevice.Format
                    //for custom framerate set min max activeVideoFrameDuration to whatever you like, e.g. 1 and 180
                    currentCamera.activeVideoMinFrameDuration = frameRates.minFrameDuration
                    currentCamera.activeVideoMaxFrameDuration = frameRates.maxFrameDuration
                }
            }
            catch {
                print("Could not set active format")
                print(error)
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        connection.videoOrientation = orientation
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: self.concurrentQueue)
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let cameraImage = CIImage(cvImageBuffer: pixelBuffer!)
        
        
        DispatchQueue.main.async {
            
            self.filteredImage.image = self.doStuffWithGGBAImage(givenImage: cameraImage)
            
            // Show default camera image
            //self.filteredImage.image = UIImage(ciImage: cameraImage)
        }
    }
    
    func doStuffWithGGBAImage(givenImage: CIImage) -> UIImage {
        
        let captureImage = convert(cmage: givenImage)
        
        let rgbaImage = RGBAImage(image: captureImage)
        
        let returnedImage = ImageProcess.setRGB(rgbaImage!, colourBlindness: previouslySetColourblindness).toUIImage()
        
        return returnedImage!
    }
    
    func convert(cmage:CIImage) -> UIImage {
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        return image
    }
    
    @IBAction func toggleFlashlight(_ sender: UISwitch) {
        
        switch sender.isOn {
            
        case true:
            print("turn on flashlight")
            
            do {
                try currentCamera?.lockForConfiguration()
                currentCamera?.torchMode = .on
                currentCamera?.unlockForConfiguration()
            }
            catch {
                print("Cannot enable flashlight")
            }
            
            break
            
        default:
            print("turn off flashlight")
            do {
                try currentCamera?.lockForConfiguration()
                currentCamera?.torchMode = .off
                currentCamera?.unlockForConfiguration()
            }
            catch {
                print("Cannot enable flashlight")
            }
            
            break
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if AVCaptureDevice.authorizationStatus(for: AVMediaType.video) != .authorized {
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: {
                (authorized) in
                
                self.concurrentQueue.async {
                    if authorized {
                        self.setupInputOutput()
                    }
                }
            })
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.concurrentQueue.async {
            self.captureSession.stopRunning()
        }
        
        print("stopping captureSession")
    }
}
