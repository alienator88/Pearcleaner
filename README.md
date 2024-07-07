# Pearcleaner
<p align="center">
   <img src="https://github.com/alienator88/Pearcleaner/assets/91337119/165f6961-f4fc-4199-bc68-580bacff6eaf" align="center" width="128" height="128" />
   <br />
   <strong>Status: </strong>Maintained 
   <br />
   <strong>Version: </strong>3.7.8
   <br />
   <a href="https://github.com/alienator88/Pearcleaner/releases"><strong>Download</strong></a>
    · 
   <a href="https://github.com/alienator88/Pearcleaner/commits">Commits</a>
   <br />
   <br />
   <a href="https://www.producthunt.com/posts/pearcleaner?utm_source=badge-featured&utm_medium=badge&utm_souce=badge-pearcleaner" target="_blank"><img src="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=439875&theme=neutral" alt="Pearcleaner - An&#0032;open&#0045;source&#0032;mac&#0032;app&#0032;cleaner | Product Hunt" style="width: 250px; height: 54px;" width="250" height="54" /></a>
  </p>
</p>
</br>

> [!NOTE]
> Pearcleaner is now signed/notarized with an Apple Developer account. Updating from the older unsigned version `(v3.7.6 and below)` of the app to the signed version `(v3.7.7 and up)`, you will need to fully remove and re-add Pearcleaner in the Accessibility and Full Disk Access permissions panes using the -/+ buttons. Toggling the permission off and on doesn't register unfortunately as macOS sees these as two separate apps now since the certificates are different. Use the permissions checker in the Pearcleaner general settings tab to navigate to these locations quickly.


A free, source-available and fair-code licensed mac app cleaner inspired by [Freemacsoft's AppCleaner](https://freemacsoft.net/appcleaner/) and [Sun Knudsen's Privacy Guides](https://sunknudsen.com/privacy-guides/how-to-clean-uninstall-macos-apps-using-appcleaner-open-source-alternative) post on his app-cleaner script.
This project was born out of wanting to learn more on how macOS deals with app installation/uninstallation and getting more Swift experience. If you have suggestions I'm open to hearing them, submit a feature request!


### Table of Contents:
[License](#license) | [Features](#features) | [Screenshots](#screenshots) | [Issues](#issues) | [Requirements](#requirements) | [Download](#getting-pearcleaner) | [Thanks](#thanks) | [Other Apps](#other-apps)

<br>

## License
> [!IMPORTANT]
> Pearcleaner is licensed under Apache 2.0 with [Commons Clause](https://commonsclause.com/). This means that you can do anything you'd like with the source, modify it, contribute to it, etc., but the license explicitly prohibits any form of monetization for Pearcleaner or any modified versions of it. See full license [HERE](https://github.com/alienator88/Pearcleaner/blob/main/LICENSE.md)

## Features
- Signed/notarized
- Swift/SwiftUI
- Small app size (~3MB)
- Leftover file search for finding remaining files from previously uninstalled applications
- Sentinel monitor helper that can be enabled to watch Trash folder for deleted apps to cleanup after the fact(Extremely small (210KB) and uses ~2mb of ram to run in the background and file watch)
- Mini mode which can be enabled from Settings
- Menubar icon option
- One-Shot Mode
- Can drop apps to uninstall directly on the Pearcleaner Dock icon or the app window
- Optional Finder Extension which allows you to uninstall an app directly from Finder by `right click > Pearcleaner Uninstall`
- Theme System available with custom color selector
- Differentiate between regular, Safari web-apps and mobile apps with badges like **web** and **iOS**
- Has clean uninstall menu option for the Pearcleaner app itself if you want to stop using it and get rid of all files and launch items
- New feature alert on app startup
- Condition builder to easily include or exclude files from searches when file names don't match the app name/bundle id very well
- Export app file list search results
- Optional Homebrew cleanup
- Include extra directories to search for apps in
- Exclude files/folders from the leftover file search
- Custom auto-updater that pulls latest release notes and binaries from GitHub Releases (Pearcleaner should run from `/Applications` folder to avoid permission issues)


## Screenshots

<img src="https://github.com/alienator88/Pearcleaner/assets/91337119/64f581a6-47b7-4ad1-acd3-24d585407aa7" align="left" width="400" />

<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/3cfe64c2-eba9-4aa0-8250-1f318d3f624c" align="center" width="400" />
<p></p>
<img src="https://github.com/alienator88/Pearcleaner/assets/91337119/327388d9-e043-40ba-b473-4a7c255b1cdf" align="left" width="400" />

<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/e6cc2708-35ed-4084-aa0b-c789a85c6324" align="center" width="400" />
<p></p>


<details open>
  <summary>Themes</summary>
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/e3178f02-785d-48b9-b9ac-20f4e94550ff" align="left" width="400" />

<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/d65bc6b4-23b1-47de-b461-f24581aae149" align="center" width="400" />
</details>


<details>
  <summary>Mini Mode</summary>
<img src="https://github.com/alienator88/Pearcleaner/assets/91337119/0bcfbbee-7d43-4f14-9657-d3d62da72d88" align="left" width="400" />

<img src="https://github.com/alienator88/Pearcleaner/assets/91337119/3724094f-f160-4e07-8162-ff8e5e850596" align="center" width="400" />
<p></p>
<img src="https://github.com/alienator88/Pearcleaner/assets/91337119/9f713923-2eca-41c0-95da-3d35ce546f93" align="left" width="400" />

<img src="https://github.com/alienator88/Pearcleaner/assets/91337119/52cec03b-9b5c-40c0-865d-669466713c18" align="center" width="400" />
<p></p>
</details>

<details>
  <summary>Finder Extension</summary>
   <img src="https://github.com/alienator88/Pearcleaner/assets/6263626/098d58a4-bc2b-4bb3-958f-b1456dd7cb84" align="center" width="400" />
</details>

<details>
  <summary>Leftover File Search</summary>
<img src="https://github.com/alienator88/Pearcleaner/assets/91337119/7f0bb69c-67ef-488b-b7ea-43e9215b3065" align="left" width="400" />

<img src="https://github.com/alienator88/Pearcleaner/assets/91337119/a1d815cd-7118-4817-80f7-e568c6357d19" align="center" width="400" />

</details>

<details>
  <summary>Condition Builder</summary>
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/07ee866a-e872-472e-b4af-94d7fafe1c4f" align="center" width="400" />
   
</details>

<details>
  <summary>Settings</summary>
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/dda6c134-57f1-4a37-95e7-a053d7bab62b" align="left" width="400" />

<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/dd483175-65ad-44de-a742-2bbfffbf124e" align="center" width="400" />

</details>

<p></p>


## Issues
> [!WARNING]
> - When submitting issues, please use the appropriate issue template corresponding with your problem [HERE](https://github.com/alienator88/Pearcleaner/issues/new/choose)
> - For issues with unrelated files being found or not enough files being found, try the new Condition Builder (Hammer icon next to uninstall button) before submitting an APP bug
> - Templates not filled out with the requested details will be closed. Unfortunately I don't have the time to act as help desk support asking for all the missing information. Help me help you 🙂


## Requirements
> [!NOTE]
> - MacOS 13.0+ (Most functions might work on a Beta OS, but I will not support bugs for these until they are out of Beta channel.)
> - Full Disk permission to search for files and also Accessibility permission to delete/restore files



## Getting Pearcleaner

<details>
  <summary>Releases</summary>

Pre-compiled, always up-to-date versions are available from my [releases](https://github.com/alienator88/Pearcleaner/releases) page.
</details>

<details>
  <summary>Homebrew</summary>

You can add the app via Homebrew by tapping my homebrew repo directly:
```
brew install alienator88/homebrew-cask/pearcleaner
```
</details>

## Thanks

- Much appreciation to [Freemacsoft's AppCleaner](https://freemacsoft.net/appcleaner/) and [Sun Knudsen's app-cleaner script](https://sunknudsen.com/privacy-guides/how-to-clean-uninstall-macos-apps-using-appcleaner-open-source-alternative)
- [DharsanB](https://github.com/dharsanb) for sponsoring my apple developer account

## Other Apps

[Pearcleaner](https://github.com/alienator88/Pearcleaner) - An opensource app cleaner with privacy in mind

[Sentinel](https://github.com/alienator88/Sentinel) - A GUI for controlling gatekeeper status on your mac

[Viz](https://github.com/alienator88/Viz) - Utility for extracting text from images, videos, qr/barcodes
