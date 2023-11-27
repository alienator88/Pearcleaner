# Pearcleaner

<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/e6829883-894e-49a1-bc75-2c4550593b98" align="left" width="128" height="128" />
</br>
<p align="center">
   <strong>Status: </strong>Maintained
   <br />
   <strong>Version: </strong>1.7
   <br />
   <a href="https://github.com/alienator88/Pearcleaner/releases"><strong>Download</strong></a>
    · 
   <a href="https://github.com/alienator88/Pearcleaner/commits">Commits</a>
  </p>
</p>
</br>

An open-source mac app cleaner inspired by [Freemacsoft's AppCleaner](https://freemacsoft.net/appcleaner/) and [Sun Knudsen's Privacy Guides](https://sunknudsen.com/privacy-guides/how-to-clean-uninstall-macos-apps-using-appcleaner-open-source-alternative) post on his app-cleaner script.
This project was born out of wanting to learn more. There's probably parts of the code that could be done better as I'm fairly new to Swift, if you have suggestions I'm open to hearing them!

## Features
- 100% Swift/SwiftUI
- Super small app size (~2MB)
- Quick file search
- Optional Sentinel monitor helper that can be enabled to watch Trash folder for deleted apps
- Sentinel monitor is extremely small (210KB) and uses ~2mb of ram to run in the background and file watch. Communicates to app via custom url scheme instead of xpc to keep things even lighter
- Mini mode which can be enabled from Settings
- Can drop apps to uninstall directly on the Pearcleaner Dock icon itself or the drop target in the app window
- Will differentiate between regular apps and Safari web-apps with a "web" label next to each item in the list
- Requires Full Disk permission to search for files and also Accessibility to delete/restore files
- Built-in auto-updater that pulls latest release notes and binaries from GitHub Releases (Might not work well if app is not in /Applications folder because of permissions)

## Regular Mode
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/db6aae06-be0d-42af-bcab-cdb8e5bda42a" align="left" width="400" />
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/70066a2a-fb33-40e5-b328-8fc2253e25ff" align="center" width="400" />
<p></p>
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/a9cec1e2-1a13-42aa-a3e5-3cb8c448dd3e" align="left" width="400" />
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/5249d735-f87b-41c7-83da-b84a21ac9552" align="center" width="400" />
<p></p>

## Mini Mode
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/62f72204-5f13-49a8-8956-cd56ef52acdf" align="center" width="400" />
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/9cf8e848-1efe-4475-8f4b-cd89a51ec10e" align="left" width="400" />
<p></p>
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/238dfeb7-2841-4ada-bbbf-35cdda46fde1" align="center" width="400" />
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/b593564b-8c7e-42a2-a25b-124a0efb6a24" align="left" width="400" />

## Requirements
- MacOS 13.0+
- Using some newer SwiftUI code which requires 13.0+

## Getting Pearcleaner

- Releases

Pre-compiled, always up-to-date versions are available from my releases page.
You might need to open this with right click-open since I don't have a paid developer account.

- Homebrew

Since I don't have a paid developer account, I can't submit to the main Homebrew cask repo.
You can still add the app via Homebrew by tapping my repo:
```
brew tap alienator88/homebrew-cask
brew install --cask pearcleaner
```

## Thanks

Much appreciation to [Freemacsoft's AppCleaner](https://freemacsoft.net/appcleaner/) and [Sun Knudsen's app-cleaner script](https://sunknudsen.com/privacy-guides/how-to-clean-uninstall-macos-apps-using-appcleaner-open-source-alternative)
