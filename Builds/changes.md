### What's New

- [x] NEW: You can now select what page Pearcleaner opens on at launch in Settings > Interface tab - #410
- [x] Flush bundle cache after homebrew cask update
- [x] Load JWS API data on Homebrew view appear
- [x] Ignore stale brew record version when app is updated to higher version than API externally
- [x] To cut down on complexity, formulae from Updater view as it will be for serving GUI apps only. Homebrew view for CLI packages.
- [x] Add smart thread chunking for app update checking based on CPU


### Fixes

- [x] Fix homebrew underscore versions only cleaned locally, missed the API version which caused showing updates as 1.2.3 > 1.2.3 incorrectly
- [x] Fix unsupported category toggle shouldn’t refresh apps list
- [x] Fix leaf logic to show actual installed on request packages only
- [x] Fix hidden updates section duplicating on refresh - #381
- [x] Fix showing PWA apps in unsupported section
- [x] Slim pearcleaner crashing app on close, disable feature for now - #405
- [x] Translations
