//
//  TCCModels.swift
//  Pearcleaner
//
//  TCC (Transparency, Consent, and Control) data models for privacy permissions
//

import Foundation
import SwiftUI

// MARK: - TCC Permission

/// Represents a single TCC permission entry from the database
struct TCCPermission: Identifiable, Equatable {
    let id = UUID()
    let service: String
    let authValue: Int
    let authReason: Int?
    let lastModified: Date?
    let source: PermissionSource

    enum PermissionSource: String {
        case user = "USER"
        case system = "SYSTEM"
    }

    var displayName: String {
        TCCServiceMapper.friendlyName(for: service)
    }

    var sourceColor: Color {
        switch source {
        case .user: return .blue
        case .system: return .purple
        }
    }

    var statusText: String {
        switch authValue {
        case 0: return "Denied"
        case 1: return "Allowed"
        case 2: return "Allowed (Limited)"
        case 3: return "Allowed (One Time)"
        case 4: return "Denied (System)"
        case 5: return "Allowed (System)"
        default: return "Unknown (\(authValue))"
        }
    }

    var statusColor: Color {
        switch authValue {
        case 0: return .red
        case 1: return .green
        case 2: return .orange
        case 3: return .blue
        case 4: return .red
        case 5: return .green
        default: return .gray
        }
    }

    var reasonText: String? {
        guard let reason = authReason else { return nil }
        return TCCReasonMapper.friendlyReason(for: reason)
    }
}

// MARK: - TCC Query Result

/// Results from querying both User and System TCC databases
struct TCCQueryResult {
    var userPermissions: [TCCPermission] = []
    var systemPermissions: [TCCPermission] = []
    var userError: String?
    var systemError: String?

    var hasUserPermissions: Bool { !userPermissions.isEmpty }
    var hasSystemPermissions: Bool { !systemPermissions.isEmpty }
    var hasAnyPermissions: Bool { hasUserPermissions || hasSystemPermissions }

    var allPermissions: [TCCPermission] {
        let combined = userPermissions + systemPermissions
        return combined.sorted { $0.displayName < $1.displayName }
    }
}

// MARK: - Service Name Mapper

/// Maps TCC service identifiers to user-friendly names
enum TCCServiceMapper {
    static func friendlyName(for service: String) -> String {
        let mapping: [String: String] = [
            // System Policies
            "kTCCServiceSystemPolicyAllFiles": "Full Disk Access",
            "kTCCServiceSystemPolicyAppBundles": "App Management",
            "kTCCServiceSystemPolicyAppData": "App Data",
            "kTCCServiceSystemPolicyDesktopFolder": "Desktop Folder",
            "kTCCServiceSystemPolicyDocumentsFolder": "Documents Folder",
            "kTCCServiceSystemPolicyDownloadsFolder": "Downloads Folder",
            "kTCCServiceSystemPolicyNetworkVolumes": "Network Volumes",
            "kTCCServiceSystemPolicyRemovableVolumes": "Removable Volumes",

            // Security & Monitoring
            "kTCCServiceAccessibility": "Accessibility",
            "kTCCServicePostEvent": "Input Monitoring",
            "kTCCServiceListenEvent": "Input Monitoring",
            "kTCCServiceEndpointSecurityClient": "Endpoint Security",
            "kTCCServiceScreenCapture": "Screen Recording",

            // Hardware & Sensors
            "kTCCServiceCamera": "Camera",
            "kTCCServiceMicrophone": "Microphone",
            "kTCCServiceLocation": "Location Services",

            // Personal Data
            "kTCCServiceAddressBook": "Contacts",
            "kTCCServiceCalendar": "Calendar",
            "kTCCServiceReminders": "Reminders",
            "kTCCServicePhotos": "Photos",
            "kTCCServiceMediaLibrary": "Apple Music",

            // Communication
            "kTCCServiceBluetoothAlways": "Bluetooth",
            "kTCCServiceWillow": "Home",

            // Other
            "kTCCServiceAppleEvents": "Automation",
            "kTCCServiceFileProviderPresence": "File Provider Presence"
        ]

        return mapping[service] ?? service
    }
}

// MARK: - Reason Code Mapper

/// Maps TCC auth_reason codes to user-friendly explanations
enum TCCReasonMapper {
    static func friendlyReason(for reason: Int) -> String {
        switch reason {
        case 1: return "User consent"
        case 2: return "User denied"
        case 3: return "Service policy"
        case 4: return "MDM policy"
        case 5: return "Override"
        case 6: return "Missing usage string"
        case 7: return "Prompt timeout"
        case 8: return "Preflight unknown"
        case 9: return "Entitled"
        case 10: return "App type policy"
        default: return "Reason \(reason)"
        }
    }
}
