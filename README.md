# Pearcleaner

<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/6f22c4fa-fb3a-43aa-82ad-70f043b8fc88" align="left" width="128" height="128" />
</br>
<p align="center">
   <strong>Status: </strong>Maintained
   <br />
   <strong>Version: </strong>1.3
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
- Super small app size (Under 2MB currently)
- Quick file search
- Optional Sentinel monitor helper that can be enabled to watch Trash folder for deleted apps
- Sentinel monitor is extremely small (210KB) and uses ~2mb of ram to run in the background and file watch. Communicates to app via custom url scheme instead of xpc to keep things even lighter
- Mini mode which can be enabled from Settings
- Can drop apps to uninstall directly on the App Icon itself or the drop target in the app window
- Requires Full Disk permission to search for files and also Accessibility to delete/restore files
- Built-in auto-updater that pulls latest release notes and binaries from GitHub Releases

## Screenshots
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/aa48fd55-df2f-450c-a0c0-bf9507d7a465" align="left" width="400" />
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/036eae34-a9f0-4126-943a-376074e95067" align="center" width="400" />
<p></p>
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/230674bf-9f16-4b84-9b7f-e0113b4a8358" align="left" width="400" />
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/fc2b9568-cbb1-4a94-991c-0491252d7c02" align="center" width="400" />
<p></p>
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/42ba2555-be33-4161-8d08-b22519a7a353" align="left" width="400" />
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/afc61501-15e9-4db7-9f39-c8f46e27e01a" align="center" width="400" />
<p></p>
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/a01357bf-75e8-4d2b-95b4-c6f306ed1dc4" align="left" width="400" />
<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/d2fa920f-474b-4007-b54d-04ad31b994e4" align="center" width="400" />

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
