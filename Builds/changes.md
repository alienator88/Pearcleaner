### What's New

Quick .1 update for the previous release to address a few things I missed:

- [x] Make homebrew uninstall work without terminal for Homebrew manager view
- [x] Remove the need for Terminal during brew cleanup of application files - can use newly built function
- [x] Homebrew fixes for taps
- [x] Only import SwiftData if the OS supports it via weak linking - #362

--- Previous Release ---

- [x] NEW: Add homebrew manager utility page - #356
- [x] Allow exclusion of default Applications folders in Settings > Folders tab using lock icon - #357
- [x] Add dropzone overlay when hovering apps over Pearcleaner window
- [x] Cache scanned app list and homebrew data first launch for instant loading on subsequent openings with option to disable caching in settings if desired
- [x] Fix Lipo crashing on computers with lower ram due to too many open file handles - #360
- [x] Make initial loading of app list a lot more efficient with autoreleasepools and using file handles on first 4 bytes of binaries instead of scanning the whole file
- [x] Fix utility menu icon not switching using keyboard shortcuts - #354
- [x] Fix translation pruning issues for apps with nib files in lproj folder - #355
- [x] Update Package Manager view to use private Apple frameworks for package related functions, same as UninstallPKG and EasyPKG
- [x] Add option to Slim pearcleaner app bundle in Settings > About tab (lipo/prune translations)
- [x] Update translations
