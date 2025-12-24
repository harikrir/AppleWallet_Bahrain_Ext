import Foundation

// MARK: - Data Models
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

// MARK: - API Functions
func fetchCardDetails(baseURL: String, completion: @escaping (Result<[CardDetailsResponse], Error>) -> Void) {
    let urlString = "\(baseURL)KFHEBC/rest/CardDetails/CardDetails"
    guard let url = URL(string: urlString) else {
        completion(.failure(NSError(domain: "Invalid URL", code: -1)))
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
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

func postPayloadDetails(
    baseURL: String,
    body: [String: String],
    completion: @escaping (Result<PayloadDetailsResponse, Error>) -> Void
) {
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