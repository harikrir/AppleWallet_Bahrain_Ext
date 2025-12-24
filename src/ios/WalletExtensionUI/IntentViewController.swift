import IntentsUI
import Foundation
import UIKit
import PassKit
import LocalAuthentication
import Security

class IntentViewController: UIViewController, PKIssuerProvisioningExtensionAuthorizationProviding  {
    var completionHandler:
        ((PKIssuerProvisioningExtensionAuthorizationResult) -> Void)?
    
    private let authenticateButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        // UI Setup
        configureUI()
        
        // Auto-trigger biometric auth on load (optional)
//        authenticateUser()
    }
    
    // MARK: - Configure UI
    
    private func configureUI() {

        authenticateButton.setTitle("Authenticate", for: .normal)
        authenticateButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        authenticateButton.addTarget(self, action: #selector(authButtonTapped), for: .touchUpInside)
        authenticateButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(authenticateButton)

        NSLayoutConstraint.activate([
            authenticateButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            authenticateButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            authenticateButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    // MARK: - Button Click
    @objc private func authButtonTapped() {
        authenticateUser()
    }
    
    // MARK: - Biometric Authentication
    private func authenticateUser() {
        
        let context = LAContext()
        
        var error: NSError?
        let reason = "Authenticate to allow card provisioning"
        
        // Check if biometric authentication is available
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        print("Authentication success")
                        self.completionHandler?(.authorized)
                    } else {
                        print("Authentication failed")
                        self.completionHandler?(.canceled)
                    }
                }
            }
        } else {
            // Fall back to passcode
            print("Biometric unavailable; fallback to device passcode if allowed")
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                
                DispatchQueue.main.async {
                    if success {
                        print("Passcode accepted")
                        self.completionHandler?(.authorized)
                    } else {
                        print("Authentication canceled by user")
                        self.completionHandler?(.canceled)
                    }
                }
            }
        }
    }
     
}
