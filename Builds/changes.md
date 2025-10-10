### What's New

- [x] Make cask uninstall and brew cleanup much faster by reading install receipts instead of the huge(15MB) json cache homebrew uses
- [x] Make formula uninstall more performant as well by offloading cleanup to background task after formula removal
- [x] Show uninstall button for brew packages with update available - #369
- [x] Merge Formulae/Casks tabs into one Available tab with collapsible sections like Installed tab
- [x] Show more details in info drawer for homebrew packages
- [x] Make cask lookup table more efficient by using install receipts instead of recursive directory scans
- [x] Fix flash of text “There are no files to remove” for a second after brew cleanup finishes
- [x] Update translations (Added Italian , thanks @Roccobot)
