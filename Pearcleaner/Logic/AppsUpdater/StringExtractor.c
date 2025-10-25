//
//  StringExtractor.c
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/25/25.
//

#include "StringExtractor.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define MAX_URLS 50
#define MAX_URL_LENGTH 2048

// Appcast-related keywords to search for in URLs
static const char *appcast_keywords[] = {
    "appcast",
    "update",
    "updates",
    "sparkle",
    "release",
    "releases",
    "version",
    "versions",
    "feed",
    "rss",
    "changelog",
    "download",
    "downloads",
    NULL  // Sentinel
};

// Pre-release keywords (lower priority)
static const char *prerelease_keywords[] = {
    "beta",
    "alpha",
    "nightly",
    "dev",
    "tip",
    "test",
    "rc",
    "preview",
    NULL
};

// Release/production keywords (highest priority)
static const char *release_keywords[] = {
    "release",
    "prod",
    "stable",
    NULL
};

// Structure to hold URL with priority
typedef struct {
    char url[MAX_URL_LENGTH];
    int priority;  // 1 = release/prod, 2 = standard, 3 = pre-release
} URLEntry;

// Convert string to lowercase (in-place, temporary buffer)
static void to_lower(char *dest, const char *src, int len) {
    for (int i = 0; i < len && i < MAX_URL_LENGTH - 1; i++) {
        dest[i] = tolower(src[i]);
    }
    dest[len < MAX_URL_LENGTH - 1 ? len : MAX_URL_LENGTH - 1] = '\0';
}

// Check if string ends with given suffix (case-insensitive)
static int ends_with_ci(const char *str, int str_len, const char *suffix) {
    int suffix_len = (int)strlen(suffix);
    if (str_len < suffix_len) return 0;

    for (int i = 0; i < suffix_len; i++) {
        if (tolower(str[str_len - suffix_len + i]) != tolower(suffix[i])) {
            return 0;
        }
    }
    return 1;
}

// Check if string starts with prefix
static int starts_with(const char *str, int str_len, const char *prefix) {
    int prefix_len = (int)strlen(prefix);
    if (str_len < prefix_len) return 0;
    return memcmp(str, prefix, prefix_len) == 0;
}

// Check if URL contains any appcast-related keywords
static int contains_appcast_keyword(const char *str, int str_len) {
    char lowercase[MAX_URL_LENGTH];
    to_lower(lowercase, str, str_len);

    for (int i = 0; appcast_keywords[i] != NULL; i++) {
        if (strstr(lowercase, appcast_keywords[i]) != NULL) {
            return 1;
        }
    }

    return 0;
}

// Determine URL priority (0 = XML+release, 1 = XML, 2 = XML+prerelease, 3 = non-XML+release, 4 = non-XML, 5 = non-XML+prerelease)
static int get_url_priority(const char *str, int str_len) {
    char lowercase[MAX_URL_LENGTH];
    to_lower(lowercase, str, str_len);

    // Find the path end (before query parameters '?' or fragments '#')
    int path_end = str_len;
    for (int i = 0; i < str_len; i++) {
        if (str[i] == '?' || str[i] == '#') {
            path_end = i;
            break;
        }
    }

    // Check if URL path ends with .xml or .appcast (before query/fragment)
    int is_xml = ends_with_ci(str, path_end, ".xml") || ends_with_ci(str, path_end, ".appcast");

    // Check for release/prod/stable keywords
    int has_release = 0;
    for (int i = 0; release_keywords[i] != NULL; i++) {
        if (strstr(lowercase, release_keywords[i]) != NULL) {
            has_release = 1;
            break;
        }
    }

    // Check for pre-release keywords
    int has_prerelease = 0;
    for (int i = 0; prerelease_keywords[i] != NULL; i++) {
        if (strstr(lowercase, prerelease_keywords[i]) != NULL) {
            has_prerelease = 1;
            break;
        }
    }

    // Assign priority based on XML status and keywords
    if (is_xml) {
        if (has_release) return 0;           // XML + release = highest priority
        if (has_prerelease) return 2;        // XML + pre-release
        return 1;                            // XML without special keywords
    } else {
        if (has_release) return 3;           // Non-XML + release
        if (has_prerelease) return 5;        // Non-XML + pre-release = lowest priority
        return 4;                            // Non-XML without special keywords
    }
}

// Check if this is an appcast URL (two-tier matching)
static int is_appcast_url(const char *str, int str_len) {
    // Must start with http:// or https://
    if (!starts_with(str, str_len, "http://") &&
        !starts_with(str, str_len, "https://")) {
        return 0;
    }

    // Must be reasonable URL length (not too short)
    if (str_len < 15) {  // "https://a.co/x" is min reasonable URL
        return 0;
    }

    // Find end of URL (before whitespace)
    int url_end = str_len;
    for (int i = 0; i < str_len; i++) {
        if (str[i] == ' ' || str[i] == '\t' || str[i] == '\r' || str[i] == '\n') {
            url_end = i;
            break;
        }
    }

    // Find path end (before query parameters or fragments)
    int path_end = url_end;
    for (int i = 0; i < url_end; i++) {
        if (str[i] == '?' || str[i] == '#') {
            path_end = i;
            break;
        }
    }

    // TIER 1: Check for explicit appcast file extensions (before query/fragment)
    if (ends_with_ci(str, path_end, ".xml") ||
        ends_with_ci(str, path_end, ".appcast")) {
        return 1;
    }

    // TIER 2: Check for appcast-related keywords in URL
    if (contains_appcast_keyword(str, url_end)) {
        return 1;
    }

    return 0;
}

// Compare function for qsort (sort by priority ascending)
static int compare_urls(const void *a, const void *b) {
    const URLEntry *url_a = (const URLEntry *)a;
    const URLEntry *url_b = (const URLEntry *)b;

    // Sort by priority (0 = highest, 5 = lowest)
    if (url_a->priority != url_b->priority) {
        return url_a->priority - url_b->priority;
    }

    // If same priority, maintain original order (stable sort by comparing strings)
    return strcmp(url_a->url, url_b->url);
}

// Check if URL already exists in array (for deduplication)
static int url_exists(URLEntry *urls, int count, const char *url) {
    for (int i = 0; i < count; i++) {
        if (strcmp(urls[i].url, url) == 0) {
            return 1;
        }
    }
    return 0;
}

int extract_appcast_urls(const char *filepath, char **output, size_t *output_len) {
    FILE *fp = fopen(filepath, "rb");
    if (!fp) return -1;

    // Array to store found URLs with priority
    URLEntry urls[MAX_URLS];
    int url_count = 0;

    // Current string being built
    char current_string[MAX_URL_LENGTH];
    int string_len = 0;
    int c;

    while ((c = fgetc(fp)) != EOF) {
        // Check if printable ASCII (32-126) or tab (9)
        if ((c >= 32 && c <= 126) || c == 9) {
            // Add to current string
            if (string_len < MAX_URL_LENGTH - 1) {
                current_string[string_len++] = c;
            }
        } else {
            // Non-printable byte - end of string
            if (string_len > 0) {
                current_string[string_len] = '\0';

                // Check if this string is an appcast URL
                if (is_appcast_url(current_string, string_len)) {
                    // Check for duplicates
                    if (!url_exists(urls, url_count, current_string)) {
                        // Add URL with priority
                        if (url_count < MAX_URLS) {
                            strncpy(urls[url_count].url, current_string, MAX_URL_LENGTH - 1);
                            urls[url_count].url[MAX_URL_LENGTH - 1] = '\0';
                            urls[url_count].priority = get_url_priority(current_string, string_len);
                            url_count++;
                        }
                    }
                }
            }
            string_len = 0;
        }
    }

    // Handle last string if file ends with printable chars
    if (string_len > 0) {
        current_string[string_len] = '\0';
        if (is_appcast_url(current_string, string_len)) {
            if (!url_exists(urls, url_count, current_string)) {
                if (url_count < MAX_URLS) {
                    strncpy(urls[url_count].url, current_string, MAX_URL_LENGTH - 1);
                    urls[url_count].url[MAX_URL_LENGTH - 1] = '\0';
                    urls[url_count].priority = get_url_priority(current_string, string_len);
                    url_count++;
                }
            }
        }
    }

    fclose(fp);

    // Sort URLs by priority (release/prod first, pre-release last)
    if (url_count > 1) {
        qsort(urls, url_count, sizeof(URLEntry), compare_urls);
    }

    // Build output string (newline-separated URLs)
    char *buffer = malloc(10240);
    if (!buffer) return -1;

    size_t buffer_pos = 0;
    for (int i = 0; i < url_count; i++) {
        size_t url_len = strlen(urls[i].url);
        if (buffer_pos + url_len + 1 < 10240) {
            memcpy(buffer + buffer_pos, urls[i].url, url_len);
            buffer_pos += url_len;
            buffer[buffer_pos++] = '\n';
        }
    }

    // Add null terminator
    if (buffer_pos < 10240) {
        buffer[buffer_pos] = '\0';
    }

    *output = buffer;
    *output_len = buffer_pos;
    return 0;
}
