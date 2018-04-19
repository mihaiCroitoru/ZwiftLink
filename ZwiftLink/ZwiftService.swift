//
//  ZwiftService.swift
//  ZwiftLink
//
//  Created by Hani Ebrahimi on 4/18/18.
//

import Foundation
import Alamofire

class ZwiftService {
    //--- Zwift end-points (pulled from the existing zwift-mobile-api on github) ---
    let loginURL = "https://secure.zwift.com/auth/realms/zwift/tokens/access/codes"
    let myProfileURL = "https://us-or-rly101.zwift.com/api/profiles/me"
    let riderStatusURL = "https://us-or-rly101.zwift.com/relay/worlds/1/players/"
    //I think replacing the "me" in the profile URL with any player Id should return their profile
    //todo: check if the current world is always 1 for the current player
    //---
    var loggingIn: Bool = false
    var gettingUserId: Bool = false
    //--- variables from the API response (use the access token and the returned myPlayerId for the subsequent calls)
    var access_token: NSMutableString? = nil
    var expires_in: NSNumber? = nil
    var id_token: NSMutableString? = nil
    var not_before_policy: NSObject? = nil
    var refresh_token: NSString? = nil
    var refresh_expires_in: NSNumber? = nil
    var session_state: AnyObject? = nil
    var token_type: NSString? = nil
    var myPlayerId: NSNumber? = nil
    // absolute expire times of the access and refresh tokens
    var access_token_expiration: Double? = nil
    var refresh_token_expiration: Double? = nil
    //---
    static let defaultManager = ZwiftService()
    enum SignInResult {
        case success(String?)
        case failure(Error)
    }
    enum ProfileResult {
        case success(NSNumber)
        case failure(Error)
    }
    enum RideStatusResult {
        case success(PlayerState)
        case failure(Error)
    }
    func has_valid_access_token() -> Bool {
        if  self.access_token != nil && Date().timeIntervalSince1970 < self.access_token_expiration! {
            return true
        }
        return false;
    }
    func has_valid_refresh_token() -> Bool {
        if  self.access_token != nil && Date().timeIntervalSince1970 < self.refresh_token_expiration! {
            return true
        }
        return false;
    }
    // Networking: communicating server
    func signin(username: String?, password: String?, completion: @escaping (SignInResult) -> ()) {
        guard loggingIn == false else {
            return
        }
        loggingIn = true
        var parameters: [String: String] = [
            "client_id": "Zwift_Mobile_Link"
        ]
        if let _username = username, let _password = password {
            parameters.updateValue(_username, forKey: "username")
            parameters.updateValue(_password, forKey: "password")
            parameters.updateValue("password", forKey: "grant_type")
        }
        else if self.has_valid_refresh_token() {
            parameters.updateValue("refresh_token", forKey: "grant_type")
            parameters.updateValue(self.refresh_token! as String, forKey: "refresh_token")
        }
        Alamofire.request(self.loginURL, method: HTTPMethod.post, parameters: parameters, encoding: URLEncoding.default)
            .responseJSON { response in
                self.loggingIn = false
                switch response.result {
                case .success(let JSON):
                    let response = JSON as! NSDictionary
                    if response["error"] == nil {
                        //values return from Zwift
                        self.access_token = response.value(forKey: "access_token") as? NSMutableString
                        self.expires_in = response.value(forKey: "expires_in") as? NSNumber
                        self.id_token = response.value(forKey: "id_token") as? NSMutableString
                        self.not_before_policy = response.value(forKey: "not_before_policy") as? NSObject
                        self.refresh_token = response.value(forKey: "refresh_token") as? NSString
                        self.refresh_expires_in = response.value(forKey: "refresh_expires_in") as? NSNumber
                        self.token_type = response.value(forKey: "token_type") as? NSString
                        self.access_token_expiration = Date().timeIntervalSince1970 + ((self.expires_in?.doubleValue)! - 5)
                        self.refresh_token_expiration = Date().timeIntervalSince1970 + ((self.refresh_expires_in?.doubleValue)! - 5)
                    }
                    completion(SignInResult.success(response["error"] as? String))
                case .failure(let error):
                     completion(SignInResult.failure(error))
                }
        }
    }
    func getProfileAndSetPlayerId(completion: @escaping (ProfileResult) -> ()) {
        guard gettingUserId == false && loggingIn == false else {
            return
        }
        
        gettingUserId = true
        let headers: HTTPHeaders = [
            "Accept": "application/json",
            "Authorization": "Bearer " + (self.access_token as String?)!,
            "User-Agent": "Zwift/115 CFNetwork/758.0.2 Darwin/15.0.0"
        ]
        Alamofire.request(self.myProfileURL, headers: headers).responseJSON { response in
            self.gettingUserId = false
            switch response.result {
            case .success(let JSON):
                let response = JSON as! NSDictionary
                if let id = response.value(forKey: "id") as? NSNumber {
                    self.myPlayerId = id
                    completion(ProfileResult.success(id))
                }
                else {
                    completion(ProfileResult.success(0))
                }
            case .failure(let error):
                completion(ProfileResult.failure(error))
            }
        }
    
    }
    
    
    func getRiderStatus(completion: @escaping (RideStatusResult) -> ())
    {
        let newHeaders: HTTPHeaders = [
            "Accept": "application/x-protobuf-lite",
            "Authorization": "Bearer " + (self.access_token as String?)!,
            "User-Agent": "Zwift/115 CFNetwork/758.0.2 Darwin/15.0.0"
        ]
        Alamofire.request(riderStatusURL+"\(self.myPlayerId ?? 0)", headers: newHeaders).responseData { response in
            switch response.result {
            case .success(let _data):
                if let riderStatus = try? PlayerState.parseFrom(data: _data ) {
                    //key values will be nil or false if rider is not riding
                    completion(.success(riderStatus))
                } else {
                    //return empty status
                    completion(.success(PlayerState()))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    func stringFromTimeInterval(interval: TimeInterval) -> NSString {
        let ti = NSInteger(interval)
        let ms = Int((interval.truncatingRemainder(dividingBy: 1)) * 1000)
        let seconds = ti % 60
        let minutes = (ti / 60) % 60
        let hours = (ti / 3600)
        return NSString(format: "%0.2d:%0.2d:%0.2d.%0.3d",hours,minutes,seconds,ms)
    }
    
    private init() { }
}



extension String {
    
    /// Create `Data` from hexadecimal string representation
    ///
    /// This takes a hexadecimal representation and creates a `Data` object. Note, if the string has any spaces or non-hex characters (e.g. starts with '<' and with a '>'), those are ignored and only hex characters are processed.
    ///
    /// - returns: Data represented by this hexadecimal string.
    
    func hexadecimal() -> Data? {
        var data = Data(capacity: count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSMakeRange(0, utf16.count)) { match, flags, stop in
            let byteString = (self as NSString).substring(with: match!.range)
            var num = UInt8(byteString, radix: 16)!
            data.append(&num, count: 1)
        }
        
        guard data.count > 0 else { return nil }
        
        return data
    }
    
}
