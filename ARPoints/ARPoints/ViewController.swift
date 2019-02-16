//
//  ViewController.swift
//  ARPoints
//
//  Created by Josh Robbins on 18/05/2018.
//  Copyright © 2018 BlackMirrorz. All rights reserved.
//

import UIKit
import ARKit
import Alamofire

extension ViewController: ARSCNViewDelegate{
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        //1. Check Our Frame Is Valid & That We Have Received Our Raw Feature Points
        guard let currentFrame = self.augmentedRealitySession.currentFrame,
             let featurePointsArray = currentFrame.rawFeaturePoints?.points else { return }
        
        guard let pointOfView = self.augmentedRealityView.pointOfView else {return}
        let transform = pointOfView.transform
        //let orientation = SCNVector3(-transform.m31, -transform.m32, transform.m33)
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        let currentPositionOfCamera = location
        
        //2. Visualize The Feature Points
        visualizeFeaturePointsIn(featurePointsArray,currentPositionOfCamera)
        
        //3. Update Our Status View
        DispatchQueue.main.async {
            
            //1. Update The Tracking Status
            self.statusLabel.text = self.augmentedRealitySession.sessionStatus()
            
            //2. If We Have Nothing To Report Then Hide The Status View & Shift The Settings Menu
            if let validSessionText = self.statusLabel.text{
                
                self.sessionLabelView.isHidden = validSessionText.isEmpty
            }
            
            if self.sessionLabelView.isHidden { self.settingsConstraint.constant = 26 } else { self.settingsConstraint.constant = 0 }
        }
    
    }
    
    /// Provides Visualization Of Raw Feature Points Detected In The ARSessopm
    ///
    /// - Parameter featurePointsArray: [vector_float3]
    func visualizeFeaturePointsIn(_ featurePointsArray: [vector_float3],_ currentPositionOfCamera:SCNVector3){
        
        //1. Remove Any Existing Nodes
        self.augmentedRealityView.scene.rootNode.enumerateChildNodes { (featurePoint, _) in
            
            featurePoint.geometry = nil
            featurePoint.removeFromParentNode()
        }
        //3. Loop Through The Feature Points & Add Them To The Hierachy
        var mindist = 10000.0
        featurePointsArray.forEach { (pointLocation) in
            
            //Clone The SphereNode To Reduce CPU
            
            let clone = sphereNode.clone()
            clone.position = SCNVector3(pointLocation.x, pointLocation.y, pointLocation.z)
            let distance = clone.position - currentPositionOfCamera
            let length = distance.length()
            if length <= Float(mindist){
                mindist = Double(length)
            }
            self.augmentedRealityView.scene.rootNode.addChildNode(clone)
        }
        
        //2. Update Our Label Which Displays The Count Of Feature Points
        DispatchQueue.main.async {
            self.rawFeaturesLabel.text = self.Feature_Label_Prefix + String(featurePointsArray.count)
            self.distance.text=String(mindist)
        }
        
        
//        //3. Loop Through The Feature Points & Add Them To The Hierachy
//        featurePointsArray.forEach { (pointLocation) in
//
//            //Clone The SphereNode To Reduce CPU
//
//            let clone = sphereNode.clone()
//            clone.position = SCNVector3(pointLocation.x, pointLocation.y, pointLocation.z)
//            self.augmentedRealityView.scene.rootNode.addChildNode(clone)
//        }

    }
    
    

    

  
}

class ViewController: UIViewController {

    //1. Create A Reference To Our ARSCNView In Our Storyboard Which Displays The Camera Feed
    @IBOutlet weak var augmentedRealityView: ARSCNView!
    
    @IBOutlet weak var distance: UITextView!
    //2. Create A Reference To Our ARSCNView In Our Storyboard Which Will Display The ARSession Tracking Status
    @IBOutlet weak var sessionLabelView: UIView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var rawFeaturesLabel: UILabel!
    @IBOutlet var settingsConstraint: NSLayoutConstraint!
    var Feature_Label_Prefix = "Number Of Raw Feature Points Detected = "
    

    
    //3. Create Our ARWorld Tracking Configuration
    let configuration = ARWorldTrackingConfiguration()
    
    @IBAction func describeButton(_ sender: Any) {
        
        
        let apiKey = "08b38133edmshed8c3d86747b48ep1841aajsn216945825c00"
        var apiURL: URL {
            return URL(string: "https://microsoft-azure-microsoft-computer-vision-v1.p.rapidapi.com/describe")!
        }
        
        let image = augmentedRealityView.snapshot()
        guard let base64Image = base64EncodeImage(image) else {
            print("Error while base64 encoding image")
            return
        }
        
        let parameters: Parameters = [
                    "file":base64Image ]
        let headers: HTTPHeaders = [
            "X-RapidAPI-Key": apiKey
            ]
        AF.request(
            apiURL,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers)
            .responseJSON { response in
                if response.result.isFailure {
                    return
                }
                print(response.result.debugDescription)
        }
//        let parameters: Parameters = ["file" : ?image.file]
//        let header: HTTPHeaders = [HTTPHeader(name: "X-RapidAPI-Key", value: "08b38133edmshed8c3d86747b48ep1841aajsn216945825c00"), HTT]
//        //header.add(HTTPHeader(name:"Content-Type", value: "application/json"))
//        AF.request(_url, method: .post, parameters: parameters, headers: header).responseJSON { response in
//            print("🦄")
//            print(response)
//        }
    }
    //4. Create Our Session
    let augmentedRealitySession = ARSession()
    
    //5. Create A Single SCNNode Which We Will Clone
    var sphereNode: SCNNode!
    
    //--------------------
    //MARK: View LifeCycle
    //--------------------
    
    override func viewDidLoad() {
        augmentedRealityView.snapshot()
        super.viewDidLoad()
        generateNode()
        setupARSession()
        augmentedRealityView.snapshot()

    }
    
    override var prefersStatusBarHidden: Bool { return true }

    override func didReceiveMemoryWarning() { super.didReceiveMemoryWarning() }

    //----------------------
    //MARK: SCNNode Creation
    //----------------------
    
    
    /// Generates A Spherical SCNNode
    func generateNode() {
        sphereNode = SCNNode()
        let sphereGeometry = SCNSphere(radius: 0.001)
        sphereGeometry.firstMaterial?.diffuse.contents = UIColor.cyan
        sphereNode.geometry = sphereGeometry
    }

    //---------------
    //MARK: ARSession
    //---------------
    
    /// Sets Up The ARSession
    func setupARSession(){
        
        //1. Set The AR Session
        augmentedRealityView.session = augmentedRealitySession
        augmentedRealityView.delegate = self
        
        configuration.planeDetection = [planeDetection(.None)]
        augmentedRealitySession.run(configuration, options: runOptions(.ResetAndRemove))
        
        self.rawFeaturesLabel.text = ""
       
        
    }
}

func +(lhv:SCNVector3, rhv:SCNVector3) -> SCNVector3 {
    return SCNVector3(lhv.x + rhv.x, lhv.y + rhv.y, lhv.z + rhv.z)
}

extension SCNVector3 {
    func length() -> Float {
        return sqrtf(x * x + y * y + z * z)
    }
}
func - (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(l.x - r.x, l.y - r.y, l.z - r.z)
}


func base64EncodeImage(_ image: UIImage) -> String? {
    return image.pngData()?.base64EncodedString(options: .endLineWithCarriageReturn)
}
