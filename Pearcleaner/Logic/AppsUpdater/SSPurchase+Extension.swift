//
//  SSPurchase+Extension.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//  Based on mas-cli implementation
//

import Foundation
import StoreFoundation

typealias ADAMID = UInt64

extension SSPurchase {
    convenience init(adamID: ADAMID, purchasing: Bool) async {
        self.init(
            buyParameters: """
                productType=C&price=0&pg=default&appExtVrsId=0&pricingParameters=\
                \(purchasing ? "STDQ&macappinstalledconfirmed=1" : "STDRDL")&salableAdamId=\(adamID)
                """
        )

        // Possibly unnecessary…
        isRedownload = !purchasing

        itemIdentifier = adamID

        let downloadMetadata = SSDownloadMetadata(kind: "software")
        downloadMetadata.itemIdentifier = adamID
        self.downloadMetadata = downloadMetadata

        // Try to get Apple account info (may not be needed on macOS 12+)
        do {
            if let account = try await getAppleAccount() {
                accountIdentifier = NSNumber(value: account.dsID)
                appleID = account.emailAddress
            }
        } catch {
            // Do nothing - not required on modern macOS
        }
    }

    private func getAppleAccount() async throws -> (dsID: UInt64, emailAddress: String)? {
        // This is optional - macOS 12+ doesn't require account info for redownloads
        return nil
    }
}
