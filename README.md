# Pearcleaner
<p align="center">
<!--    <img src="https://github.com/alienator88/Pearcleaner/assets/91337119/165f6961-f4fc-4199-bc68-580bacff6eaf" align="center" width="128" height="128" /> -->
   <img src="https://github.com/user-attachments/assets/62cd5fcb-92d3-4d3a-9664-161a7deabd46" align="center" width="160" height="160" />

   <br />
   <strong>Status: </strong>Maintained
   <br />
   <strong>Version: </strong>4.5.0
   <br />
   <a href="https://github.com/alienator88/Pearcleaner/releases"><strong>Download</strong></a>
    · 
   <a href="https://github.com/alienator88/Pearcleaner/commits">Commits</a>
   <br />
   <br />
   <a href="https://www.producthunt.com/posts/pearcleaner?utm_source=badge-featured&utm_medium=badge&utm_souce=badge-pearcleaner" target="_blank"><img src="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=439875&theme=neutral" alt="Pearcleaner - An&#0032;open&#0045;source&#0032;mac&#0032;app&#0032;cleaner | Product Hunt" style="width: 250px; height: 54px;" width="250" height="54" /></a>
   <br />
   <a href="https://hellogithub.com/repository/7d671653eec144ea99bd2317db267e06" target="_blank"><img src="https://abroad.hellogithub.com/v1/widgets/recommend.svg?rid=7d671653eec144ea99bd2317db267e06&claim_uid=stBZ5iURuDKgFbV" alt="Featured｜HelloGitHub" style="width: 250px; height: 54px;" width="250" height="54" /></a>
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
- Prune unused translation files from app bundles keeping only the preferred language set on macOS
- Sentinel monitor helper that can be enabled to watch Trash folder for deleted apps to cleanup after the fact(Extremely small (210KB) and uses ~2mb of ram to run in the background and file watch)
- Mini mode which can be enabled from Settings
- Menubar icon option
- CLI support
- Drag/drop applications support
- Deep link support for automation, see [wiki guide](https://github.com/alienator88/Pearcleaner/wiki/Deep-Link-Guide) for instructions
- Optional Finder Extension which allows you to uninstall an app directly from Finder by `right click > Pearcleaner Uninstall`
- Theme System available with custom color selector
- Differentiate between regular, Safari web-apps and mobile apps with badges like **web** and **iOS**
- Has clean uninstall menu option for the Pearcleaner app itself if you want to stop using it and get rid of all files and launch items
- Export app bundles for migrating apps and their cache to a new system
- Export app file list search results
- Optional Homebrew cleanup
- Include extra directories to search for apps in
- Exclude files/folders from the orphaned file search
- Custom auto-updater that pulls latest release notes and binaries from GitHub Releases (Pearcleaner should run from `/Applications` folder to avoid permission issues)


## Screenshots

<img src="https://github.com/user-attachments/assets/e2e16378-dbed-4cd4-a20b-23dd0d806fdf" align="left" width="400" />

<img src="https://github.com/user-attachments/assets/4221d3ce-6190-45da-9a35-f9554196b2bf" align="center" width="400" />
<p></p>
<img src="https://github.com/user-attachments/assets/fc2f6d24-d6c9-4aec-91da-3d0adc05df48" align="left" width="400" />

<img src="https://github.com/user-attachments/assets/d8e43558-071f-4ff8-8557-b0508c063c1c" align="center" width="400" />
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
brew install pearcleaner
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
