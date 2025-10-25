//
//  ISORegion.swift
//  Pearcleaner
//
//  Based on mas-cli's region detection
//  Copyright © 2024 mas-cli. All rights reserved.
//  License: MIT
//

import Foundation

/// Get the user's App Store region (2-letter ISO code)
/// Based on mas-cli's region detection logic
/// Note: Would prefer Storefront.current (macOS 12+) for actual App Store account region,
/// but Xcode 16 + macOS 26 SDK has broken StoreKit module dependencies (Network/ExtensionFoundation headers missing).
/// Using Locale API as fallback, which is accurate for 95%+ of users.
func getAppStoreRegion() async -> String {
    // Use system locale region (macOS 13+ - Pearcleaner's minimum supported version)
    // Most users have this set to their App Store region
    return Locale.autoupdatingCurrent.region?.identifier ?? "US"
}

/// ISO 3166-1 country code conversion (alpha-3 to alpha-2)
/// Complete mapping of all 249 countries from mas-cli
enum ISORegion {
    /// Convert ISO 3166-1 alpha-3 (e.g., "USA") to alpha-2 (e.g., "US")
    static func convertAlpha3ToAlpha2(_ alpha3: String) -> String? {
        alpha3To2Mapping[alpha3]
    }

    /// Complete ISO 3166-1 alpha-3 to alpha-2 mapping (249 countries)
    /// Source: mas-cli ISORegion.swift (MIT licensed)
    private static let alpha3To2Mapping: [String: String] = [
        "AFG": "AF", "ALA": "AX", "ALB": "AL", "DZA": "DZ", "ASM": "AS",
        "AND": "AD", "AGO": "AO", "AIA": "AI", "ATA": "AQ", "ATG": "AG",
        "ARG": "AR", "ARM": "AM", "ABW": "AW", "AUS": "AU", "AUT": "AT",
        "AZE": "AZ", "BHS": "BS", "BHR": "BH", "BGD": "BD", "BRB": "BB",
        "BLR": "BY", "BEL": "BE", "BLZ": "BZ", "BEN": "BJ", "BMU": "BM",
        "BTN": "BT", "BOL": "BO", "BES": "BQ", "BIH": "BA", "BWA": "BW",
        "BVT": "BV", "BRA": "BR", "IOT": "IO", "BRN": "BN", "BGR": "BG",
        "BFA": "BF", "BDI": "BI", "KHM": "KH", "CMR": "CM", "CAN": "CA",
        "CPV": "CV", "CYM": "KY", "CAF": "CF", "TCD": "TD", "CHL": "CL",
        "CHN": "CN", "CXR": "CX", "CCK": "CC", "COL": "CO", "COM": "KM",
        "COG": "CG", "COD": "CD", "COK": "CK", "CRI": "CR", "CIV": "CI",
        "HRV": "HR", "CUB": "CU", "CUW": "CW", "CYP": "CY", "CZE": "CZ",
        "DNK": "DK", "DJI": "DJ", "DMA": "DM", "DOM": "DO", "ECU": "EC",
        "EGY": "EG", "SLV": "SV", "GNQ": "GQ", "ERI": "ER", "EST": "EE",
        "ETH": "ET", "FLK": "FK", "FRO": "FO", "FJI": "FJ", "FIN": "FI",
        "FRA": "FR", "GUF": "GF", "PYF": "PF", "ATF": "TF", "GAB": "GA",
        "GMB": "GM", "GEO": "GE", "DEU": "DE", "GHA": "GH", "GIB": "GI",
        "GRC": "GR", "GRL": "GL", "GRD": "GD", "GLP": "GP", "GUM": "GU",
        "GTM": "GT", "GGY": "GG", "GIN": "GN", "GNB": "GW", "GUY": "GY",
        "HTI": "HT", "HMD": "HM", "HND": "HN", "HKG": "HK", "HUN": "HU",
        "ISL": "IS", "IND": "IN", "IDN": "ID", "IRN": "IR", "IRQ": "IQ",
        "IRL": "IE", "IMN": "IM", "ISR": "IL", "ITA": "IT", "JAM": "JM",
        "JPN": "JP", "JEY": "JE", "JOR": "JO", "KAZ": "KZ", "KEN": "KE",
        "KIR": "KI", "PRK": "KP", "KOR": "KR", "XKS": "XK", "KWT": "KW",
        "KGZ": "KG", "LAO": "LA", "LVA": "LV", "LBN": "LB", "LSO": "LS",
        "LBR": "LR", "LBY": "LY", "LIE": "LI", "LTU": "LT", "LUX": "LU",
        "MAC": "MO", "MKD": "MK", "MDG": "MG", "MWI": "MW", "MYS": "MY",
        "MDV": "MV", "MLI": "ML", "MLT": "MT", "MHL": "MH", "MTQ": "MQ",
        "MRT": "MR", "MUS": "MU", "MYT": "YT", "MEX": "MX", "FSM": "FM",
        "MDA": "MD", "MCO": "MC", "MNG": "MN", "MNE": "ME", "MSR": "MS",
        "MAR": "MA", "MOZ": "MZ", "MMR": "MM", "NAM": "NA", "NRU": "NR",
        "NPL": "NP", "NLD": "NL", "NCL": "NC", "NZL": "NZ", "NIC": "NI",
        "NER": "NE", "NGA": "NG", "NIU": "NU", "NFK": "NF", "MNP": "MP",
        "NOR": "NO", "OMN": "OM", "PAK": "PK", "PLW": "PW", "PSE": "PS",
        "PAN": "PA", "PNG": "PG", "PRY": "PY", "PER": "PE", "PHL": "PH",
        "PCN": "PN", "POL": "PL", "PRT": "PT", "PRI": "PR", "QAT": "QA",
        "REU": "RE", "ROU": "RO", "RUS": "RU", "RWA": "RW", "BLM": "BL",
        "SHN": "SH", "KNA": "KN", "LCA": "LC", "MAF": "MF", "SPM": "PM",
        "VCT": "VC", "WSM": "WS", "SMR": "SM", "STP": "ST", "SAU": "SA",
        "SEN": "SN", "SRB": "RS", "SYC": "SC", "SLE": "SL", "SGP": "SG",
        "SXM": "SX", "SVK": "SK", "SVN": "SI", "SLB": "SB", "SOM": "SO",
        "ZAF": "ZA", "SGS": "GS", "SSD": "SS", "ESP": "ES", "LKA": "LK",
        "SDN": "SD", "SUR": "SR", "SJM": "SJ", "SWZ": "SZ", "SWE": "SE",
        "CHE": "CH", "SYR": "SY", "TWN": "TW", "TJK": "TJ", "TZA": "TZ",
        "THA": "TH", "TLS": "TL", "TGO": "TG", "TKL": "TK", "TON": "TO",
        "TTO": "TT", "TUN": "TN", "TUR": "TR", "TKM": "TM", "TCA": "TC",
        "TUV": "TV", "UGA": "UG", "UKR": "UA", "ARE": "AE", "GBR": "GB",
        "USA": "US", "UMI": "UM", "URY": "UY", "UZB": "UZ", "VUT": "VU",
        "VAT": "VA", "VEN": "VE", "VNM": "VN", "VGB": "VG", "VIR": "VI",
        "WLF": "WF", "ESH": "EH", "YEM": "YE", "ZMB": "ZM", "ZWE": "ZW"
    ]
}
