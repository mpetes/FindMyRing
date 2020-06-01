//
//  CompassViewController.swift
//  compass
//
//  Created by Federico Zanetello on 05/04/2017.
//  Copyright © 2017 Kimchi Media. All rights reserved.
//

import UIKit
import CoreLocation
import Firebase

class CompassViewController: UIViewController {
    @IBOutlet weak var compassImageView: UIImageView!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    
    // -121.9920632
    // Winters: CLLocation(latitude: CLLocationDegrees(38.635495), longitude: -121.9920632)
    // Novato: CLLocation(latitude: CLLocationDegrees(38.1111799), longitude: -122.5772646)
    // Michael's apt start: CLLocation(latitude: CLLocationDegrees(37.760053), longitude: CLLocationDegrees(-122.396495))
    // Michael's apt end: CLLocation(latitude: CLLocationDegrees(37.760306), longitude: CLLocationDegrees(-122.396514))
    
    var totalDistanceToTravel: Double = 0.0
    var numLocationsInARowInZone: Int64 = 0
    var isShowingZonePhoto: Bool = false
    var canView: Bool = false
    var didFinish: Bool = false
    let kFindMyRingCompleteProgress: Float = 0.95
    
    let locationDelegate = LocationDelegate()
    var latestUserLocation: CLLocation? = nil
    let finalLocation = CLLocation(latitude: CLLocationDegrees(38.635495), longitude: -121.9920632)
    let startLocation = CLLocation(latitude: CLLocationDegrees(38.1111799), longitude: -122.5772646)
    var finalLocationBearing: CGFloat { return latestUserLocation?.bearingToLocationRadian(self.finalLocation) ?? 0 }
  
    let locationManager: CLLocationManager = {
        $0.requestWhenInUseAuthorization()
        $0.desiredAccuracy = kCLLocationAccuracyBest
        $0.startUpdatingLocation()
        $0.startUpdatingHeading()
        return $0
    }(CLLocationManager())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.delegate = locationDelegate
        
        self.setupProgressView()
        
        locationDelegate.locationCallback = { location in
            self.updateWithLatestUserLocation(location)
        }

        locationDelegate.headingCallback = { newHeading in
            UIView.animate(withDuration: 0.3) {
                let angle = self.finalLocationBearing - CGFloat(newHeading).degreesToRadians
                self.compassImageView.transform = CGAffineTransform(rotationAngle: angle)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
        self.updateViewIsHidden()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    
    // HELPERS
    func updateViewIsHidden() {
        self.view.isHidden = true

        let now = Date()
        
        // Specify date components
        var dateComponents = DateComponents()
        dateComponents.year = 2020
        dateComponents.month = 4
        dateComponents.day = 24
        dateComponents.timeZone = TimeZone(abbreviation: "PST")
        dateComponents.hour = 15
        dateComponents.minute = 0

        // Create date from components
        let userCalendar = Calendar.current // user calendar
        if let goTime = userCalendar.date(from: dateComponents) {
            if (now >= goTime) {
                self.view.isHidden = false
            }
        }
        if (self.view.isHidden) {
            self.readHiddenStatusFromFirebase()
        }
    }
    
    func setupProgressView() {
        self.progressView.layer.cornerRadius = 2
        self.progressView.layer.masksToBounds = true
        self.totalDistanceToTravel = self.startLocation.distance(from: self.finalLocation)
    }
    
    func calculateProgress(_ distanceInMeters: CLLocationDistance) -> Float {
        return 1 - Float(distanceInMeters / self.totalDistanceToTravel).clamp(low: 0, high: 1)
    }
    
    func updateProgress(_ progress: Float) {
        if (!progress.isEqual(to: self.progressView.progress)) {
            self.progressView.progress = progress
            self.progressLabel.text = String(format: "%.0f%%", round(progress * 100))
        }
        if (self.numLocationsInARowInZone >= 10 && round(progress * 100) >= 100) {
            self.progressLabel.text = "You're going to be a bride!"
            self.didFinish = true
        }
    }
    
    func readHiddenStatusFromFirebase() {
        let db = Firestore.firestore()
        db.collection("unlockables").getDocuments() { (querySnapshot, err) in
            for document in querySnapshot!.documents {
                let data = document.data()
                if let unwrappedCanView = data["canView"] {
                    self.canView = unwrappedCanView as? Bool ?? false
                }
                if let unwrappedDidFinish = data["didFinish"] {
                    self.didFinish = unwrappedDidFinish as? Bool ?? false
                    if (self.didFinish) {
                        self.progressLabel.text = "Congrats, you're a fiancée!"
                        self.progressView.progress = 1
                        self.backgroundImageView.image = UIImage(named: "WintersBitmojis")
                    }
                }
            }
            if (self.canView) {
                self.view.isHidden = false
            }
        }
    }
    
    func updateWithLatestUserLocation(_ location: CLLocation) {
        guard self.didFinish == false else { return }
        
        self.latestUserLocation = location
        let distanceInMeters = location.distance(from: self.finalLocation)
        let progress = self.calculateProgress(distanceInMeters)
        if (progress >= self.kFindMyRingCompleteProgress) {
            self.numLocationsInARowInZone += 1
        } else {
            self.numLocationsInARowInZone = 0
        }
        if (self.numLocationsInARowInZone > 10 && !self.isShowingZonePhoto) {
            UIView.transition(with: self.backgroundImageView,
            duration: 1,
            options: .transitionCrossDissolve,
            animations: { self.backgroundImageView.image = UIImage(named: "WintersBitmojis") },
            completion: nil)
            self.isShowingZonePhoto = true
        } else if (self.numLocationsInARowInZone <= 10 && self.isShowingZonePhoto) {
              UIView.transition(with: self.backgroundImageView,
                          duration: 1,
                          options: .transitionCrossDissolve,
                          animations: { self.backgroundImageView.image = UIImage(named: "Background-1") },
                          completion: nil)
            self.isShowingZonePhoto = false
        }
        self.updateProgress(progress)
    }
}

extension Comparable {
    func clamp(low: Self, high: Self) -> Self {
        if (self > high) {
            return high
        } else if (self < low) {
            return low
        }

        return self
    }
}
