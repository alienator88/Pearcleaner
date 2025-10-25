//
//  StringExtractor.h
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/25/25.
//

#ifndef StringExtractor_h
#define StringExtractor_h

#include <stddef.h>

/// Extract appcast URLs from binary file with intelligent detection and priority sorting
///
/// DETECTION STRATEGY:
/// - Tier 1: URLs ending with .xml or .appcast (high confidence matches)
/// - Tier 2: URLs containing appcast-related keywords (update, release, sparkle, changelog, etc.)
///
/// PRIORITY SORTING (URLs returned in priority order, highest first):
/// - Priority 1: URLs containing release/production keywords ("release", "prod", "stable")
/// - Priority 2: Standard appcast URLs without special keywords
/// - Priority 3: URLs containing pre-release keywords ("beta", "alpha", "nightly", "tip", "dev", etc.)
///
/// APPCAST KEYWORDS DETECTED:
/// - appcast, update, updates, sparkle, release, releases, version, versions,
///   feed, rss, changelog, download, downloads
///
/// @param filepath Path to binary file to scan
/// @param output Pointer to receive allocated buffer containing newline-separated URLs (caller must free())
/// @param output_len Pointer to receive output buffer length
/// @return 0 on success, -1 on error (file not found, allocation failure, etc.)
///
/// @note The output buffer is dynamically allocated and must be freed by the caller using free()
/// @note URLs are automatically deduplicated - each unique URL appears only once
/// @note Maximum 50 URLs can be returned per binary
/// @note Maximum URL length is 2048 characters
int extract_appcast_urls(const char *filepath, char **output, size_t *output_len);

#endif /* StringExtractor_h */
