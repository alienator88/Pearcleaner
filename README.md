# Pearcleaner

<img src="https://github.com/alienator88/Pearcleaner/assets/6263626/6f22c4fa-fb3a-43aa-82ad-70f043b8fc88" width="128" height="128" />

An open-source mac app cleaner inspired by Freemacsoft's AppCleaner and Sun Knudsen's Privacy Guides post on his app-cleaner script.
This project was born out of wanting to learn more. There's probaby parts of the code that could be done better as I'm fairly new to Swift, if you have suggestions I'm open to hearing them!

## Screenshots

![](https://github.com/alienator88/Pearcleaner/assets/6263626/aa48fd55-df2f-450c-a0c0-bf9507d7a465)
![](https://github.com/alienator88/Pearcleaner/assets/6263626/036eae34-a9f0-4126-943a-376074e95067)
![](https://github.com/alienator88/Pearcleaner/assets/6263626/230674bf-9f16-4b84-9b7f-e0113b4a8358)
![](https://github.com/alienator88/Pearcleaner/assets/6263626/fc2b9568-cbb1-4a94-991c-0491252d7c02)


## Features
- 100% Swift
- Super small app size (1.6MB)
- Quick file search
- Optional Sentinel monitor helper that can be enabled to watch Trash folder for deleted apps
- Sentinel monitor is extremely small (210KB) and uses <=5mb of ram to run in the background and file watch. Communicates to app via custom url scheme instead of xpc to keep things even lighter
- Requires Full Disk permission to search for files and also Accessibility to delete/restore files

## Requirements
- MacOS 13.0+
- At the moment, using some newer SwiftUI code which requires 13.0+
- Will try to re-work some of that to support older versions.

## Getting Pearcleaner

Pre-compiled, always up-to-date versions are available from my releases page.
You might need to open this with right click-open since I don't have a paid developer account.

## Thanks

Much appreciation to Freemacsoft's AppCleaner and Sun Knudsen's app-cleaner script
