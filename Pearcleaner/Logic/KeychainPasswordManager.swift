//
//  KeychainPasswordManager.swift
//  Pearcleaner
//
//  Manages sudo password caching in macOS Keychain with time-based expiry
//  Created by Alin Lupascu on 11/10/24.
//

import Foundation
import Security

class KeychainPasswordManager {
    static let shared = KeychainPasswordManager()

    private let service = "com.alienator88.Pearcleaner.SudoPassword"
    private let account: String

    private init() {
        self.account = NSUserName()
    }

    enum KeychainError: Error {
        case invalidData
        case itemNotFound
        case unexpectedStatus(OSStatus)
    }


    // MARK: - Public API

    /// Saves password to keychain with expiry time stored in metadata
    func savePassword(_ password: String, expiryInterval: TimeInterval = 300) {
        // Delete existing item first
        deletePassword(service: service, account: account)

        // Calculate expiry timestamp and store as metadata
        let expiryDate = Date().addingTimeInterval(expiryInterval)
        let expiryTimestamp = expiryDate.timeIntervalSince1970
        let expiryString = "\(expiryTimestamp)"

        guard let passwordData = password.data(using: .utf8),
              let expiryData = expiryString.data(using: .utf8) else {
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: passwordData,
            kSecAttrGeneric as String: expiryData,  // Store expiry in generic attribute
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    /// Retrieves password from keychain if not expired
    func retrievePassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecReturnAttributes as String: kCFBooleanTrue!,  // Also return attributes
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let existingItem = item as? [String: Any],
              let passwordData = existingItem[kSecValueData as String] as? Data,
              let password = String(data: passwordData, encoding: .utf8),
              let expiryData = existingItem[kSecAttrGeneric as String] as? Data,
              let expiryString = String(data: expiryData, encoding: .utf8),
              let expiryTimestamp = TimeInterval(expiryString) else {
            return nil
        }

        let expiryDate = Date(timeIntervalSince1970: expiryTimestamp)

        if Date() > expiryDate {
            invalidateCache()
            return nil
        }

        return password
    }

    /// Removes password from keychain
    func invalidateCache() {
        deletePassword(service: service, account: account)
    }

    // MARK: - Private Keychain Operations

    private func deletePassword(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
