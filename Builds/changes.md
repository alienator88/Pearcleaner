### What's New

- [x] NEW: iOS apps can now be updated without opening AppStore. This can fail for some apps if the certificate on Apple's server is expired since Pearcleaner can't renew certificates the way macOS can.
- [x] Homebrew console will persists logs between actions
- [x] Increase brew console drag handle click area, remember size and if left open/closed
- [x] Grab adamID from metadata if exists for MAS apps
- [x] Make Finder extension use a unique bundle id to try and prevent some issues caused by updating via homebrew


### Fixes

- [x] Fix formulae to work with revision versions
- [x] Fix App Store API lookup for wrapped/non-wrapped apps
- [x] Fix veracrypt, google-drive casks
- [x] Fix updating pinned formulae - #457
- [x] Clear any /tmp/pearcleaner files during MAS update functions
- [x] Translations
