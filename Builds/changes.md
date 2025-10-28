### What's New

- [x] Add SUDO_ASKPASS prompt for homebrew auto update script to prompt user for password for privileged app updates
- [x] Add leaves toggle in Formula category header on Installed tab (shows only formulae you installed directly, no dependencies)
- [x] Use homebrew API jws file for Installed/Available packages information gathering
- [x] Move FDA permission check outside of AF package to local scope to avoid race condition
- [x] In Updater tab > Sidebar, added toggle to show/hide auto_updates apps. If app exists in Homebrew and Sparkle, only show Sparkle version unless auto_updates bool is on.
- [x] Add debug lines to the log when updating a sparkle app in case it fails for some reason
- [x] Show unsupported apps category in updater view, can hide it using Sidebar settings - #406
- [x] Disable auto-slimming setting temporarily, causing some hangs on app exit - #405


### Fixes

- [x] Fix cask icon reloading in Installed view
- [x] Fix homebrew issues mentioned in pinned homebrew issue, hopefully..probably not 😪
- [x] Fix Brew Auto Update toggle enabling - #401
- [x] Translations
