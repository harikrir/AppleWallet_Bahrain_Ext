import Intents
import UIKit 
import Foundation
import PassKit
import LocalAuthentication
import Security

struct CardDetailsResponse: Codable {
    let cardId: String
    let cardTitle: String
    let maskedCardNumber: String
    let artUrl: String
    let cardType: String
    let holderName: String
    
    enum CodingKeys: String, CodingKey {
        case cardId = "cardId"
        case cardTitle = "cardTitle"
        case maskedCardNumber = "maskedCardNumber"
        case artUrl = "artUrl"
        case cardType = "cardType"
        case holderName = "HolderName"
    }
}

struct PayloadDetailsResponse: Codable {
    let activationData: String?
    let encryptedData: String?
    let ephermeralPublicKey: String?

    enum CodingKeys: String, CodingKey {
        case activationData = "ActivationData"
        case encryptedData = "EncryptedData"
        case ephermeralPublicKey = "EphermeralPublicKey"
    }
}

class IntentHandler: PKIssuerProvisioningExtensionHandler {
    
    let passLibrary = PKPassLibrary()
    
    // MARK: - Required Methods
    func authorize(completion: @escaping (PKIssuerProvisioningExtensionAuthorizationResult) -> Void) {
        completion(.authorized)
    }
    
    override func status(completion: @escaping (PKIssuerProvisioningExtensionStatus) -> Void) {
        let status = PKIssuerProvisioningExtensionStatus()
        
        do {
            guard let walletStatus = try getWalletStatus() else {
                completion(status)
                return
            }
            
            guard !walletStatus.sessionToken.isEmpty, walletStatus.hasEligibleCards else {
                completion(status)
                return
            }
            
            status.requiresAuthentication = true
            status.passEntriesAvailable = walletStatus.hasEligibleCards
            status.remotePassEntriesAvailable = true
            
            completion(status)
        } catch {
            status.requiresAuthentication = false
            status.passEntriesAvailable = true
            status.remotePassEntriesAvailable = false
            
            completion(status)
        }
    }
    
    override func passEntries(completion: @escaping ([PKIssuerProvisioningExtensionPassEntry]) -> Void) {
        
        do {
            guard let walletStatus = try getWalletStatus() else {
                completion([])
                return
            }
            
            fetchCardDetails(baseURL: walletStatus.baseURL) { result in
                switch result {
                case .success(let cards):
                    Task {
                        var passEntries: [PKIssuerProvisioningExtensionPassEntry] = []
                        for card in cards {
                            if let entry = await self.getPaymentPassEntry(card: card, baseURL: walletStatus.baseURL) {
                                passEntries.append(entry)
                            }
                        }
                        completion(passEntries)
                    }
                case .failure(_):
                    completion([])
                }
            }
        } catch {
            completion([])
        }
    }
    
    override func remotePassEntries(completion: @escaping ([PKIssuerProvisioningExtensionPassEntry]) -> Void) {
        do {
            guard let walletStatus = try getWalletStatus() else {
                completion([])
                return
            }
            
            fetchCardDetails(baseURL: walletStatus.baseURL) { result in
                switch result {
                case .success(let cards):
                    Task {
                        var passEntries: [PKIssuerProvisioningExtensionPassEntry] = []
                        for card in cards {
                            if let entry = await self.getPaymentPassEntry(card: card, baseURL: walletStatus.baseURL) {
                                passEntries.append(entry)
                            }
                        }
                        completion(passEntries)
                    }
                case .failure(_):
                    completion([])
                }
            }
        } catch {
            completion([])
        }
    }
    
    override func generateAddPaymentPassRequestForPassEntryWithIdentifier(
        _ identifier: String,
        configuration: PKAddPaymentPassRequestConfiguration,
        certificateChain certificates: [Data],
        nonce: Data,
        nonceSignature: Data,
        completionHandler completion: @escaping (PKAddPaymentPassRequest?) -> Void
    ) {
        let request = PKAddPaymentPassRequest()
        
        do {
            guard let walletStatus = try getWalletStatus(),
                  certificates.count > 0 else {
                completion(request)
                return
            }
            
            let requestBody: [String: String] = [
                "certificatepem": certificates[0].base64EncodedString(),
                "nonce": nonce.base64EncodedString(),
                "nonceSignature": nonceSignature.base64EncodedString(),
                "pan": "4197545012002043",
                "expiryDate": "1128",
                "datetime": "20251218062132",
                "authcode": "957043",
                "keySetIdentifier": "434179.1",
                "EncryptionKey": "E39B F146 C12F 0152 E661 F429 979B E3D6",
                "cardHolderName": "Afifa Semaan Asaad Abdelsayed",
                "productType": "AF9EF1FE9C72472799C23AD8307E8D2E",
                "Version": "1",
                "ExpiryWithSegregation": "11/28",
                "networkName": "Visa"
            ]
            
            postPayloadDetails(baseURL: walletStatus.baseURL, body: requestBody) { result in
                switch result {
                case .success(let data):
                    request.activationData = Data(base64Encoded: data.activationData ?? "")
                    request.encryptedPassData = Data(base64Encoded: data.encryptedData ?? "")
                    request.ephemeralPublicKey = Data(base64Encoded: data.ephermeralPublicKey ?? "")
                    completion(request)
                case .failure(_):
                    completion(request)
                }
            }
        } catch {
            completion(request)
        }
    }
    
    // MARK: - Helper Methods
    private func getPaymentPassEntry(card: CardDetailsResponse, baseURL: String) async -> PKIssuerProvisioningExtensionPaymentPassEntry? {
        guard let requestConfig = PKAddPaymentPassRequestConfiguration(encryptionScheme: .ECC_V2) else {
            return nil
        }
        
        guard let fallbackArt = getEntryArt(image: UIImage(named: "card") ?? UIImage()) else {
            return nil
        }
        
        requestConfig.primaryAccountIdentifier = card.cardId
        requestConfig.paymentNetwork = .masterCard // Update based on cardType if needed
        requestConfig.cardholderName = card.holderName
        requestConfig.localizedDescription = card.cardTitle
        requestConfig.primaryAccountSuffix = String(card.maskedCardNumber.suffix(4))
        requestConfig.style = .payment
        
        let url = "\(baseURL)\(card.artUrl)"
        
        do {
            let cgImage = try await cgImage(from: url)
            return PKIssuerProvisioningExtensionPaymentPassEntry(
                identifier: card.cardId,
                title: card.cardTitle,
                art: cgImage,
                addRequestConfiguration: requestConfig
            )
        } catch {
            return PKIssuerProvisioningExtensionPaymentPassEntry(
                identifier: card.cardId,
                title: card.cardTitle,
                art: fallbackArt,
                addRequestConfiguration: requestConfig
            )
        }
    }
    
    private func cgImage(from urlString: String) async throws -> CGImage {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else {
            throw NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image"])
        }
        
        return cgImage
    }
    
    private func getEntryArt(image: UIImage) -> CGImage? {
        guard let ciImage = CIImage(image: image) else {
            return nil
        }
        
        let ciContext = CIContext(options: nil)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
    
    // MARK: - Missing Helper Methods
    // You need to implement these or ensure they exist elsewhere
    private func getWalletStatus() throws -> WalletStatus? {
        // Implement this method or ensure it's available
        // This should fetch wallet status from your app/user defaults
       
        let sessionToken = "HARDCODED_SESSION_TOKEN_12345"
        let hasEligibleCards = true
        let baseURL = "https://personal-lionaii7.outsystemscloud.com/"
         
        return WalletStatus(
            sessionToken: sessionToken,
            hasEligibleCards: hasEligibleCards,
            baseURL: baseURL
        )
    }
    
    private func fetchCardDetails(baseURL: String, completion: @escaping (Result<[CardDetailsResponse], Error>) -> Void) {
        // Implement network call to fetch card details
        
        let urlString = "\(baseURL)KFHEBC/rest/CardDetails/CardDetails"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // IMPORTANT: Body is plain text, not JSON
        request.httpBody = "KFH".data(using: .utf8)

        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: -1)))
                return
            }

            do {
                let cards = try JSONDecoder().decode([CardDetailsResponse].self, from: data)
                completion(.success(cards))
            } catch {
                completion(.failure(error))
            }

        }.resume()
    }
    
    private func postPayloadDetails(baseURL: String, body: [String: String], completion: @escaping (Result<PayloadDetailsResponse, Error>) -> Void) {
        // Implement network call to post payload
        
        let urlString = "\(baseURL)KFHEBC/rest/CardDetails/PayloadDetails"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: [body])
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: -1)))
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(PayloadDetailsResponse.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}


// MARK: - Model Definitions
// Add these if they don't exist
struct WalletStatus {
    let sessionToken: String
    let hasEligibleCards: Bool
    let baseURL: String
}
