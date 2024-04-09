# Pearcleaner
<p align="center">
   <img src="https://github.com/alienator88/Pearcleaner/assets/91337119/165f6961-f4fc-4199-bc68-580bacff6eaf" align="center" width="128" height="128" />
   <br />
   <strong>Status: </strong>Maintained 
   <br />
   <strong>Version: </strong>3.4.1
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

An open-source mac app cleaner inspired by [Freemacsoft's AppCleaner](https://freemacsoft.net/appcleaner/) and [Sun Knudsen's Privacy Guides](https://sunknudsen.com/privacy-guides/how-to-clean-uninstall-macos-apps-using-appcleaner-open-source-alternative) post on his app-cleaner script.
This project was born out of wanting to learn more on how macOS deals with app installation/uninstallation and getting more Swift experience. If you have suggestions I'm open to hearing them, submit a feature request!

## Features
- 100% Swift
- Small app size (~2MB)
- Quick file search, can be made instant by enabling Instant Search in settings which caches all the apps and files on startup
- Reverse search for finding remaining files from already uninstalled applications
- Sentinel monitor helper that can be enabled to watch Trash folder for deleted apps
- Sentinel monitor is extremely small (210KB) and uses ~2mb of ram to run in the background and file watch
- Mini mode which can be enabled from Settings
- Can drop apps to uninstall directly on the Pearcleaner Dock icon itself or the drop target in the app window
- Will differentiate between regular apps and Safari web-apps with a "web" label next to each item in the list
- Will differentiate between regular apps and wrapped iOS apps with an "iOS" label next to each item in the list
- Has clean uninstall menu option for the Pearcleaner app itself if you want to stop using it and get rid of all files and launch items
- New feature alert on app startup
- Menubar option
- Optional Homebrew cleanup
- Custom auto-updater that pulls latest release notes and binaries from GitHub Releases (Pearcleaner has to run from /Applications folder for this to work because of permissions)



## Screenshots

<img src="https://github.com/alienator88/Pearcleaner/assets/91337119/64f581a6-47b7-4ad1-acd3-24d585407aa7" align="left" width="400" />

<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/3cfe64c2-eba9-4aa0-8250-1f318d3f624c" align="center" width="400" />
<p></p>
<img src="https://github.com/alienator88/Pearcleaner/assets/91337119/327388d9-e043-40ba-b473-4a7c255b1cdf" align="left" width="400" />

<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/e6cc2708-35ed-4084-aa0b-c789a85c6324" align="center" width="400" />
<p></p>


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
  <summary>Leftover File Search</summary>
<img src="https://github.com/alienator88/Pearcleaner/assets/91337119/7f0bb69c-67ef-488b-b7ea-43e9215b3065" align="left" width="400" />

<img src="https://github.com/alienator88/Pearcleaner/assets/91337119/a1d815cd-7118-4817-80f7-e568c6357d19" align="center" width="400" />

</details>

<details>
  <summary>Settings</summary>
<img src="https://github.com/alienator88/Pearcleaner/assets/91337119/684374f0-a342-420b-b251-5e35d07e4d72" align="left" width="400" />

<img src="https://github.com/alienator88/Pearcleaner/assets/91337119/c0d0541a-c13f-47b2-a0d7-59bf6e722499" align="center" width="400" />

</details>

<p></p>


## Requirements
- MacOS 13.0+ (App uses a lot of newer SwiftUI functions/modifiers which don't work on any OS lower than 13.0)
- Open Pearcleaner first time by right clicking and selecting Open. This adds an exception to Gatekeeper so it doesn't complain about the app not being signed with an Apple Developer certificate
- Full Disk permission to search for files and also Accessibility permission to delete/restore files



## Getting Pearcleaner

<details>
  <summary>Releases</summary>

> Pre-compiled, always up-to-date versions are available from my releases page.
You might need to open this with right click-open since I don't have a paid developer account.
</details>

<details>
  <summary>Homebrew</summary>
   
> Since I don't have a paid developer account, I can't submit to the main Homebrew cask repo.
You can still add the app via Homebrew by tapping my homebrew repo:
```
brew install alienator88/homebrew-cask/pearcleaner
```
</details>

## Thanks

Much appreciation to [Freemacsoft's AppCleaner](https://freemacsoft.net/appcleaner/) and [Sun Knudsen's app-cleaner script](https://sunknudsen.com/privacy-guides/how-to-clean-uninstall-macos-apps-using-appcleaner-open-source-alternative)

## Some of my apps

[Pearcleaner](https://github.com/alienator88/Pearcleaner) - An opensource app cleaner with privacy in mind

[Sentinel](https://github.com/alienator88/Sentinel) - A GUI for controlling gatekeeper status on your mac

[Viz](https://github.com/alienator88/Viz) - Utility for extracting text from images, videos, qr/barcodes

[McBrew](https://github.com/alienator88/McBrew) - A GUI for managing your homebrew
