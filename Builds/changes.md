### What's New

- [x] Show App Store progress bar during updates - #430
- [x] Add App Store region fallback when checking for updates
- [x] Replace sparkle version check with custom implementation that checks both build and shortVersion strings, not just build
- [x] Ignore SetApp sparkle apps as the signatures don't match the dev since SetApp signs them - #428
- [x] Disable homebrew api call caching on network requests
- [x] Allow adding apps to Updater ignore list from sidebar even if no update is available
- [x] Add homebrew debug lines during loading/install/update/uninstall actions


### Fixes

- [x] Fix packages with 0 size from mismatched cellar version folder with revision number
- [x] Fix apps showing size 0 KB in homebrew installed view
- [x] Fix some casks missing icons/sizes in homebrew installed view
- [x] Fix homebrew size calculation crash on main thread since byteformatter isn't thread-safe
- [x] Fix iOS wrapped apps not being recognized sometimes by App Store update detection - #424
- [x] Fix search engine Opera Air/ Opera files - #312
- [x] Fix missing metadata dates on some apps - #423
- [x] Translations
