### What's New

- [x] NEW: ✨ Sparkle apps can now be updated directly in Pearcleaner! Had to add Sparkle framework for this which increased app size by ~2.8MB 😔
- [x] NEW: 🍺 Homebrew view now has a new Auto Update tab to allow scheduling update/upgrade/cleanup actions for brew
- [x] 🍐 Show Pearcleaner update available in Updater view as well
- [x] Add Sparkle appcast URL checks for apps that don’t expose the SUFeedURL in Info.plist. This should find some apps that Latest won't (Ex. Ghostty). This isn't a 100% sure mechanism as I have to look inside the app binary strings for the appcast URLs. Some apps(ex. ChatGPT) build the URLs at runtime and it's impossible to extract - #381
- [x] New debugging command in Updater view to capture issues with false positives/negatives easier - Access from menubar Help > Export Updater Debug Log...
- [x] Speed up Homebrew and Updater package/app loading considerably
- [x] Show app icons for casks in Homebrew and Updater views
- [x] Add app store reset button in Updater sidebar next to app store source
- [x] Add CLI toggle alert if helper is not enabled - #395
- [x] Add CLI 'helper' command to check status and enable/disable helper - #395
- [x] Allow Remove action for homebrew/core taps and fix icon - #396
- [x] Show selected files size on uninstall button - #398


### Fixes

- [x] Fix removing wrapped iOS app bundle leaving file rows/view behind and missing icon for wrapped app bundle in file list
- [x] Translations
