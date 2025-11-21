### What's New

- [x] NEW: I finally finished v2 of the Updater page view that I've been working on for a bit
- [x] NEW: You can now adopt apps into homebrew from Updater page and also from FilesView sidebar > options menu - #464
- [x] NEW: You can now swap between category view and simple list view from Files view and Orphans view toolbar buttons - #462
- [x] App updates are checked during Pearcleaner launch, can be disabled in Settings > General to opt out and check for updates only when navigating to the Updater view. This allows to show a count of how many updates are available in the global toolbar menu.
- [x] Merge ignore/skip functionality into one mechanism for Updater view to allow fully skipping an app from checking for updates or only one version
- [x] Add failure catch in Homebrew when install/uninstall action fail for some reason, shows Alert with action buttons to bypass or ignore - #461
- [x] Add Homebrew/Sparkle deduplication logic when auto_updates is enabled.
- [x] Add OS version/arch check in homebrew controller
- [x] Add app name digit stripping during related files scan
- [x] Scan nested bundles inside applications for related file details
- [x] Add 2 level depth search for Library folders excluding OS directories
- [x] Add two phase loading model to app startup to speed up loading app list while offloading unneeded data to lower priority background queue
- [x] Add uninstall with Pearcleaner service to the system-wide services menu - #444
- [x] Add pinyin sorting for chinese apps - #468

### Fixes

- [x] Fix teamIdentifier function failing on some apps
- [x] Fix file size gathering function to be slightly more performant
- [x] Fix warp-cli brew package version/size checking
- [x] Fix tap icon/info button logic
- [x] Fix homebrew auto-update tab not being able to create plist file if LaunchAgents folder is not present - #469
- [x] Fix homebrew auto-update schedule hiccup with deleted schedules coming back from appstorage
- [x] Fix notification observers for undo actions on some pages
- [x] Add electron keyword to skipped binaries during scans as it finds too many unrelated files - #471
- [x] Translations
