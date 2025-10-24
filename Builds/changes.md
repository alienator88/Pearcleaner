### What's New

- [x] ✨ Sparkle apps can now be updated directly in Pearcleaner. Had to add Sparkle framework which increased app size by ~3MB.
- [x] 🍐 Pearcleaner will also show as having an update available in the Updater view now as a banner along the top.
- [x] Add Sparkle appcast URL checks for apps that don’t expose the SUFeedURL in Info.plist. This should find some apps that Latest won't (Ex. Ghostty). This isn't a solid mechanism as I have to look inside the app binary strings for the URL and it's hit or miss probably - #381
- [x] Add CLI toggle alert if helper is not enabled - #395
- [x] Allow Remove action for homebrew/core taps and fix icon - #396


### Fixes

- [x] Fix removing wrapped iOS app bundle leaving file rows/view behind and missing icon for wrapped app bundle in file list
- [x] Translations
