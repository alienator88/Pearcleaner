### What's New

- [x] Add homebrew catch when install/uninstall fail for some reason - #461
- [x] Add Homebrew/Sparkle deduplication logic when auto_updates is enabled.
- [x] Add OS version/arch check in homebrew controller
- [x] Add app name digit stripping
- [x] Add nested bundle scan
- [x] Speed up initial app list load with a partial AppInfo object, get the rest in the background
- [x] Add category view option to Files view and Orphans view - #462
- [x] Add 2 level depth search for Library folders excluding OS directories
- [x] Add 2 phase loading model to app startup to speed up loading apps while offloading unneeded data to lower priority queue
- [x] Stream apps into list instead of waiting for all to load

### Fixes

- [x] Fix teamIdentifier function failing on some apps
- [x] Translations
