### What's New

- [x] Console button in Homebrew toolbar to show brew actions output in a bottom console view
- [x] Add Stop button in Homebrew toolbar for certain brew actions
- [x] Add receipt import into MAS app install process for affected macOS systems where `installd` is blocked
- [x] Move brew install/update/uninstall actions to homebrew commands fully
- [x] Add askpass credential expiry selector in settings > general (Related to item above this, when brew needs sudo permissions a popup will come up asking to input password and it will cache it securely in Keychain for as long as you have the cache setting set to.)
- [x] Add path validation logic in UndoManager to prevent altering system paths, dropping empty paths and non-standard URLs
- [x] Move every single delete action in the Pearcleaner codebase under the UndoManager. Everything (except brew as it's isolated) is safely moved to Trash folder and never permanently deleted
- [x] Add UndoManager history in the Menubar > Edit > Delete History. This will persist app restart and allow you to undo up to 10 delete actions as long as the deletion bundle is still in the Trash


### Fixes

- [x] Fix XcodesOrg app exception - #449
- [x] Fix formulae version lookup for HEAD installs
- [x] Fix cask lookup table failing for pkg installed casks and others with target names
- [x] Translations
