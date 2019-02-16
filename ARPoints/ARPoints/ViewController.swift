import UIKit
import ARKit
import Alamofire
import Firebase
import AVFoundation
import AVKit
import CoreLocation

var nearestDistance = 0.0

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
            nearestDistance = mindist
        }
        

    }
  
}

var storageRef = Storage.storage().reference()


var lat = 0.0
var lon = 0.0

class ViewController: UIViewController, CLLocationManagerDelegate {
    
    var locationManager: CLLocationManager!
    
    @IBAction func getDistance(_ sender: Any) {
        let utterance = AVSpeechUtterance(string: "Nearest object in current direction is " + String(Float(roundf(Float(nearestDistance * 100))/100)) + "metres away")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.5
        
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
    
    @IBAction func requestHelp(_ sender: Any) {
        let utterance = AVSpeechUtterance(string: "Requesting help now")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.5
        
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
        ARPoints.requestHelp(name: "Anukul", phoneNumber: "817027939472")
        
        let utterance2 = AVSpeechUtterance(string: "SMS sent for help")
        utterance2.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance2.rate = 0.5
        let synthesizer2 = AVSpeechSynthesizer()
        synthesizer2.speak(utterance2)

    }
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
        
        
//        let apiKey = "08b38133edmshed8c3d86747b48ep1841aajsn216945825c00"
//        var apiURL: URL {
//            return URL(string: "https://microsoft-azure-microsoft-computer-vision-v1.p.rapidapi.com/describe")!
//        }
//
        let image = augmentedRealityView.snapshot()
        sendImage(data: image.jpegData(compressionQuality: 0.05)!, timeStamp: String(IntegerLiteralType(NSDate().timeIntervalSince1970 * 1000)))

    }
    //4. Create Our Session
    let augmentedRealitySession = ARSession()
    
    //5. Create A Single SCNNode Which We Will Clone
    var sphereNode: SCNNode!
    
    //--------------------
    //MARK: View LifeCycle
    //--------------------
    
    override func viewDidLoad() {
        super.viewDidLoad()
        generateNode()
        setupARSession()
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        
        let single_tap = UITapGestureRecognizer(target: self, action: #selector(singleTapped))
        single_tap.numberOfTapsRequired = 1
        
        view.addGestureRecognizer(single_tap)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
        tap.numberOfTapsRequired = 2
        view.addGestureRecognizer(tap)
        
        single_tap.require(toFail: tap)
        
        //add long press gesture
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressed(gesture:)))
        longPressGesture.minimumPressDuration = 5
        self.view.addGestureRecognizer(longPressGesture)
        
        determineMyCurrentLocation()
        
        view.backgroundColor = UIColor.gray
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool{
        return true
    }
    @objc func doubleTapped() {
        print("double tapped")
        describeButton("double tap")
    }
    
    @objc func singleTapped() {
        print("single tapped")
        getDistance("single tap")
    }
    
    @objc func longPressed(gesture:UIGestureRecognizer) {
        
        print("long pressed")
        if gesture.state == .ended{
        requestHelp("long Pressed")
        }
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
    
    func determineMyCurrentLocation() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
            //locationManager.startUpdatingHeading()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let userLocation:CLLocation = locations[0] as CLLocation
        
        // Call stopUpdatingLocation() to stop listening for location updates,
        // other wise this function will be called every time when user location changes.
        
        //manager.stopUpdatingLocation()
        
        print("user latitude = \(userLocation.coordinate.latitude)")
        print("user longitude = \(userLocation.coordinate.longitude)")
        
        lat = userLocation.coordinate.latitude
        lon = userLocation.coordinate.longitude
        
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("Error \(error)")
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

func sendImage(data: Data, timeStamp: String) {
    let uploadTask = getImageRef(timeStamp: timeStamp).putData(data, metadata: nil)
    let observer = uploadTask.observe(.success, handler: { (snapshot) in
        getAudio(timeStamp: timeStamp)
    })
}

func getImageRef(timeStamp: String) -> StorageReference {
    return storageRef.child("images/"+timeStamp+".jpg")
}

func getAudio(timeStamp: String) {
    let url: String = "https://us-central1-kouzoh-p-anukul.cloudfunctions.net/getDescription?id=" + timeStamp
    AF.request(url).responseJSON{response in
        print(response)
        playAudio(timeStamp: timeStamp)
    }
}

var player:AVPlayer?

func playAudio(timeStamp: String) {
    let playerItem = AVPlayerItem(url: URL(string: "https://firebasestorage.googleapis.com/v0/b/kouzoh-p-anukul.appspot.com/o/audio%2F"+timeStamp+".mp3?alt=media&token=163d43d9-589e-4bc4-ac55-5237b72a5078")! )
    player = AVPlayer(playerItem: playerItem)
    player?.rate = 0.8
    player?.play()
}

func requestHelp(name: String, phoneNumber: String) {
    let url = "https://us-central1-kouzoh-p-anukul.cloudfunctions.net/sendMessage?from="+name+"&to="+phoneNumber+"&text=help" + "http://www.google.com/maps/place/" + "\(lat)" + "," + "\(lon)"
    print()
    AF.request(url).responseJSON{response in
        print(response)
    }
}
