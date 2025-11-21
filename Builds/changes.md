### What's New

- [x] NEW: Updater view has been completely redesigned to use the main page sidebar
- [x] NEW: Adopt apps into homebrew from Updater page and also from FilesView sidebar options menu - #464
- [x] NEW: Add category view option to Files view and Orphans view toolbar - #462
- [x] App updates are checked during Pearcleaner launch, can be disabled in Settings > General to opt out and check for updates only when navigating to the Updater view. This allows to show a count of how many updates are available in the global toolbar menu.
- [x] Merge ignore/skip functionality into one mechanism for Updater view
- [x] Add homebrew catch when install/uninstall fail for some reason - #461
- [x] Add Homebrew/Sparkle deduplication logic when auto_updates is enabled.
- [x] Add OS version/arch check in homebrew controller
- [x] Add app name digit stripping
- [x] Add nested bundle scan
- [x] Speed up initial app list load with a partial AppInfo object, get the rest in the background
- [x] Add 2 level depth search for Library folders excluding OS directories
- [x] Add 2 phase loading model to app startup to speed up loading apps while offloading unneeded data to lower priority queue
- [x] Stream apps into list instead of waiting for all to load on Pearcleaner launch
- [x] Add uninstall with Pearcleaner service to the system-wide services menu - #444
- [x] Add pinyin sorting for chinese apps - #468

### Fixes

- [x] Fix teamIdentifier function failing on some apps
- [x] Fix file size gathering function to be slightly more efficient
- [x] Fix warp-cli version/size checking
- [x] Fix tap icon/info button logic
- [x] Fix homebrew auto-update not being able to create plist file if LaunchAgents folder is not present - #469
- [x] Fix homebrew auto-update schedule hiccup with deleted schedules coming back from appstorage
- [x] Fix notification observers for undo actions on some pages
- [x] Add electron keyword to skipped binaries during scans - #471
- [x] Translations
