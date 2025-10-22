### What's New

- [x] Remove Ifrit Fuse package, replace with custom fuzzy search algorithm for app name filtering
- [x] Remove SemanticVersion package, replace with Sparkle framework version checking logic
- [x] Use greedy flag on outdated casks with auto_updates bool in Updater view
- [x] Add formulae/CLI apps to Updater view
- [x] Remove SwiftyJSON and use Foundation's JSON
- [x] Fix unable to remove tap that has installed packages, use --force to bypass homebrew restriction
- [x] Fix Settings Helper tab toolbar buttons not showing when launching straight into the tab
- [x] Show “no results” text when filtering apps list via search and there's no valid options to show
- [x] Optimize app refresh functions to await for Updater/Homebrew views
- [x] Simplify sensitivity levels to 3 and always use supplemental spotlight search. Strict(searches for exact matches), Smart(default, searches for exact and contains matches), Deep(searches within file contents, finder comments and metadata as well)
- [x] Translations
