import Foundation
import Security

let appGroupID: String = "group.com.aub.mobilebanking"
let keychainStoreDataKey = "walletStatusToken"

func saveDictionaryToKeychain(
    _ dictionary: [String: Any],
    key: String,
    service: String = appGroupID
) throws {

    let data = try dictionaryToData(dictionary)

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: key
    ]
    
    SecItemDelete(query as CFDictionary)

    var attributes = query
    attributes[kSecValueData as String] = data
    attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    
    let status = SecItemAdd(attributes as CFDictionary, nil)
    
    guard status == errSecSuccess else {
        throw NSError(domain: "KeychainError", code: Int(status))
    }
}

func readDictionaryFromKeychain(
    key: String,
    service: String = appGroupID
) throws -> [String: Any]? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: key,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    
    guard status == errSecSuccess else { return nil }
    
    guard let data = result as? Data else { return nil }

    return try dataToDictionary(data)
}

func dictionaryToData(_ dictionary: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: dictionary, options: [])
}

func dataToDictionary(_ data: Data) throws -> [String: Any] {
    let json = try JSONSerialization.jsonObject(with: data, options: [])
    return json as? [String: Any] ?? [:]
}

// Helper to save wallet status from Cordova plugin
func saveWalletStatus(sessionToken: String, hasEligibleCards: Bool, baseURL: String) throws {
    let statusDict: [String: Any] = [
        "sessionToken": sessionToken,
        "hasEligibleCards": hasEligibleCards,
        "URL": baseURL
    ]
    try saveDictionaryToKeychain(statusDict, key: keychainStoreDataKey)
}

// Helper to get wallet status
func getWalletStatus() throws -> (sessionToken: String, hasEligibleCards: Bool, baseURL: String)? {
    guard let dict = try readDictionaryFromKeychain(key: keychainStoreDataKey) else {
        return nil
    }
    
    let sessionToken = dict["sessionToken"] as? String ?? ""
    let hasEligibleCards = dict["hasEligibleCards"] as? Bool ?? false
    let baseURL = dict["URL"] as? String ?? ""
    
    return (sessionToken, hasEligibleCards, baseURL)
}