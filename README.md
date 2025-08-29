# Pearcleaner
<p align="center">
<!--    <img src="https://github.com/alienator88/Pearcleaner/assets/91337119/165f6961-f4fc-4199-bc68-580bacff6eaf" align="center" width="128" height="128" /> -->
   <img src="https://github.com/user-attachments/assets/62cd5fcb-92d3-4d3a-9664-161a7deabd46" align="center" width="160" height="160" />

   <br />
   <strong>Status: </strong>Maintained
   <br />
   <strong>Version: </strong>5.0.4
   <br />
   <a href="https://github.com/alienator88/Pearcleaner/releases"><strong>Download</strong></a>
    · 
   <a href="https://github.com/alienator88/Pearcleaner/commits">Commits</a>
  </p>
</p>
</br>


A free, source-available and fair-code licensed Mac app cleaner inspired by [Freemacsoft's AppCleaner](https://freemacsoft.net/appcleaner/) and [Sun Knudsen's Privacy Guides](https://github.com/sunknudsen/guides/tree/main/archive/how-to-clean-uninstall-macos-apps-using-appcleaner-open-source-alternative) post on his app-cleaner script.
This project was born out of wanting to learn more on how macOS deals with app installation/uninstallation and getting more Swift experience. If you have suggestions I'm open to hearing them, submit a feature request!


### Table of Contents:
[Translations](#translations) | [License](#license) | [Features](#features) | [Screenshots](#screenshots) | [Issues](#issues) | [Requirements](#requirements) | [Download](#getting-pearcleaner) | [Thanks](#thanks) | [Other Apps](#other-apps)

<br>

## Translations
If you are able to contribute to translations for the app, please see this discussion: https://github.com/alienator88/Pearcleaner/discussions/137

## License
> [!IMPORTANT]
> Pearcleaner is licensed under Apache 2.0 with [Commons Clause](https://commonsclause.com/). This means that you can do anything you'd like with the source, modify it, contribute to it, etc., but the license explicitly prohibits any form of monetization for Pearcleaner or any modified versions of it. See full license [HERE](https://github.com/alienator88/Pearcleaner/blob/main/LICENSE.md)

## Features
- Orphaned file search for finding remaining files from previously uninstalled applications
- Development environments file/cache cleaning
- App Lipo to strip unneeded architectures from universal apps. No dependency on the lipo tool so no need to install xcode or command line tools
- Launch Agent/Daemon management view
- PKG Installer management view
- Prune unused translation files from app bundles keeping only the preferred language set on macOS
- Sentinel monitor helper that can be enabled to watch Trash folder for deleted apps to cleanup after the fact(Extremely small (210KB) and uses ~2mb of ram to run in the background and file watch)
- CLI support
- Basic Steam games support
- Drag/drop applications support
- Deep link support for automation, see [wiki guide](https://github.com/alienator88/Pearcleaner/wiki/Deep-Link-Guide) for instructions
- Optional Finder Extension which allows you to uninstall an app directly from Finder by `right click > Pearcleaner Uninstall`
- Theme System available with custom colors selector
- Differentiate between regular, Safari web-apps and mobile apps with badges like **web** and **iOS**
- Has clean uninstall menu option for the Pearcleaner app itself if you want to stop using it and get rid of all files and launch items
- Export app bundles for migrating apps and their cache to a new system
- Export app file list search results
- Optional Homebrew cleanup
- Include extra directories to search for apps in
- Exclude files/folders from the orphaned file search
- Custom auto-updater that pulls latest release notes and binaries from GitHub Releases (Pearcleaner should run from `/Applications` folder to avoid permission issues)


## Screenshots

<img src="https://github.com/user-attachments/assets/743f170b-a80e-43f7-9626-3d1acd004396" align="left" width="400" />
<img src="https://github.com/user-attachments/assets/eaa7d326-6eaa-4702-a3bf-9ad56cbba832" align="center" width="400" />
<p></p>


## Issues
> [!WARNING]
> - When submitting issues, please use the appropriate issue template corresponding with your problem [HERE](https://github.com/alienator88/Pearcleaner/issues/new/choose)
> - Beta versions of macOS will not be supported until general release


## Requirements
> [!NOTE]
> - MacOS 13.0+ [Non-beta releases]
> - Full Disk permission to search for files


## Getting Pearcleaner

<details>
  <summary>Releases</summary>

Pre-compiled, always up-to-date versions are available from my [releases](https://github.com/alienator88/Pearcleaner/releases) page.
</details>

<details>
  <summary>Homebrew</summary>

You can add the app via Homebrew:
```
brew install --cask pearcleaner
```
</details>

## Thanks

- Much appreciation to [Freemacsoft's AppCleaner](https://freemacsoft.net/appcleaner/) and [Sun Knudsen's app-cleaner script](https://sunknudsen.com/privacy-guides/how-to-clean-uninstall-macos-apps-using-appcleaner-open-source-alternative)
- [DharsanB](https://github.com/dharsanb) for sponsoring my Apple Developer account

## Other Apps

[Pearcleaner](https://github.com/alienator88/Pearcleaner) - An opensource app cleaner with privacy in mind

[Sentinel](https://github.com/alienator88/Sentinel) - A GUI for controlling gatekeeper status on your Mac

[Viz](https://github.com/alienator88/Viz) - Utility for extracting text from images, videos, qr/barcodes

[PearHID](https://github.com/alienator88/PearHID) - Remap your macOS keyboard with a simple SwiftUI frontend
