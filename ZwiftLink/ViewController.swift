//
//  ViewController.swift
//  ZwiftLink
//
//  Created by Hani Ebrahimi on 4/18/18.
//


//todo: check for wifi connection before getting all these data???

import UIKit
import Alamofire
import Reachability

class ViewController: UIViewController {
    @IBOutlet var powerLabel: UILabel!
    @IBOutlet var speedLabel: UILabel!
    let timeInterval: Double = 1.0
    //login parameters
    var userName: String? = nil
    var userPassword: String? = nil
    var playerStatus: PlayerState? = nil
    var errorResult: String? = nil
    var timer : Timer?
    //for checking wifi connection - declare this property where it won't go out of scope relative to your listener
    let reachability = Reachability()!
    override func viewDidLoad() {
        super.viewDidLoad()
        if (userName == nil || userPassword == nil)  {
            //todo: prompt for user Name and Password
            //todo: check for valid accesstoken
            userName = ProcessInfo.processInfo.environment["HaniUserName"]
            userPassword = ProcessInfo.processInfo.environment["HaniPassword"]
        }
        do{
            try reachability.startNotifier()
        }catch{
            print("could not start reachability notifier")
        }
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilityChanged , object: reachability)
    }
    @objc func reachabilityChanged(note: Notification) {
        let reachability = note.object as! Reachability
        switch reachability.connection {
        case .wifi:
            //-- Start timer (or use some other trigger for getStatusAndUpdateDisplay)
            if timer == nil {
                timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(ViewController.LoginAndGetStatus), userInfo: nil, repeats: true)
            }
        default:
            if timer != nil {
                timer?.invalidate()
                timer = nil
                if self.presentedViewController == nil {
                    let alert = UIAlertController(title: "Connection lost!", message: "Please connect to Wifi", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    @objc func LoginAndGetStatus() {
        if (!ZwiftService.defaultManager.has_valid_access_token() && !ZwiftService.defaultManager.has_valid_refresh_token()) {
            if (ZwiftService.defaultManager.has_valid_refresh_token()) {
                //get new access token with the valid refresh token
                
            } else {
                //need to ask user to login because both the access token and the refresh token have expired
                if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ZLLoginView") as? ZLLoginViewController
                {
                    self.present(vc, animated: true, completion: nil)
                }
            }
        }
        else {
            //token is valid so just get status
            getStatus()
        }
    }
    func getStatus() {
        // get player stats
        ZwiftService.defaultManager.getRiderStatus() {
            response in
            switch response {
            case .success(let playerState):
                //display stats
                self.playerStatus = playerState
                self.updateDisplay()
            case .failure( _):
                //report error
                self.errorResult = "Unable to get rider status"
            }
        }
    }
    func updateDisplay() {
        guard self.errorResult == nil else {
            //---  HANDLE ERRORS HERE  ---
            if self.presentedViewController == nil {
                let alert = UIAlertController(title: "Something went wrong!", message: self.errorResult, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Try again", style: .default, handler: nil))
                alert.addAction(UIAlertAction(title: "Cencel", style: .cancel, handler: {action in
                    if self.timer != nil {
                        self.timer?.invalidate()
                        self.timer = nil
                    }
                }))
                self.present(alert, animated: true)
            }
            return
        }
        //---  HANDLE RECEIVED DATA HERE  ---
        if let speed = self.playerStatus?.speed {
            let normalizedSpeed = (Float(speed) / 1000000).rounded()
            self.speedLabel.text = "\(normalizedSpeed) km/h"
        } else {
            self.speedLabel.text = "0 km/h"
        }
        if let cadence = self.playerStatus?.cadenceUhz {
            //calculate cadende but now displaying it for now
            let _ = (Float(cadence * 60) / 1000000).rounded()
        }
        self.powerLabel.text = "\(self.playerStatus?.power ?? 0)"
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}
