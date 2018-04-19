//
//  ZLLoginViewController.swift
//  ZwiftLink
//
//  Created by Hani Ebrahimi on 4/19/18.
//

import UIKit

class ZLLoginViewController: UIViewController {

    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var signinButton: UIButton!
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var errorLabelForWrongPassword: UILabel!
    @IBAction func signinTapped(_ sender: Any) {
        //hide the error label
        signinButton.isEnabled = false
        usernameTextField.isEnabled = false
        passwordTextField.isEnabled = false
        activityIndicator.startAnimating()
        self.errorLabelForWrongPassword.isHidden = true
        guard usernameTextField.text != nil && passwordTextField != nil else {
            return
        }
        ZwiftService.defaultManager.signin(username: usernameTextField.text!, password: passwordTextField.text!, completion: {response in
            self.activityIndicator.stopAnimating()
            self.signinButton.isEnabled = true
            self.usernameTextField.isEnabled = true
            self.passwordTextField.isEnabled = true
            switch response {
            case .success(let signinError):
                if (signinError == nil) {
                    //signin was successful. Get RiderId
                    self.activityIndicator.startAnimating()
                    ZwiftService.defaultManager.getProfileAndSetPlayerId() {
                        response in
                        self.activityIndicator.stopAnimating()
                        switch response {
                        case .success(let id):
                            if (id.intValue > 0) {
                                if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ZLDataViewController") as? ViewController
                                {
                                    self.present(vc, animated: true, completion: nil)
                                }
                                return
                            }
                            else {
                                //no user id present
                                if self.presentedViewController == nil {
                                    let alert = UIAlertController(title: "Error!", message: "Unable to get Rider Id. Try again.", preferredStyle: .alert)
                                    alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                                    self.present(alert, animated: true)
                                }
                            }
                        case .failure( _):
                            //error getting user id
                            if self.presentedViewController == nil {
                                let alert = UIAlertController(title: "Error!", message: "Something went wront.", preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                                self.present(alert, animated: true)
                            }
                        }
                    }
                } else {
                     self.errorLabelForWrongPassword.isHidden = false
                }
            case .failure( _):
                //show the error label
                if self.presentedViewController == nil {
                    let alert = UIAlertController(title: "Error!", message: "Something went wront. Check connection and try again.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                    self.present(alert, animated: true)
                }
            }
        })
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
