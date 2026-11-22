### What's New

- [x] Space Lens: disk usage map (treemap and sunburst) for any folder or the whole disk, with breadcrumb drill-down, hover tooltips, and Move to Trash from the map
- [x] Protected system paths (System, Library, Applications, usr, private) render view-only, never deletable from Space Lens
- [x] Rescan through the privileged helper when a scan hits unreadable folders; falls back to the existing Enable Helper flow when the helper is not installed
- [x] Partial results stream in while scanning, with cancel; treemap rebalances in place after trashing items
- [x] Treemap tiles nest inside a parent band so containment reads visually; children inherit the parent hue, and .app-style packages stay single atomic tiles at any depth
- [x] Backspace (delete) steps back one level from the focused folder
- [x] Setting for the default Space Lens chart style (Settings > Interface), and the scan runs once and survives page switches; both treemap and sunburst read the same tree
- [x] Development Environments catalog now covers 50+ tools with kind tags (cache, logs, sessions, packages, VM disks, toolchains) and composable rule filters
- [x] Sort path rows in the Development view by name, size, age or folder; sort VM/container rows by size, name or status
- [x] Age sorting for Leftover and Orphaned lists (oldest first)
- [x] Stop action for running docker containers and VMs (colima, lima, OrbStack, minikube, Docker Desktop)
- [x] Orphan confidence score sorting
- [x] App coverage: Docker Desktop, Godot, JetBrains Toolbox, OrbStack, Qt, Rancher Desktop, Sublime Text, Unity, VirtualBox
- [x] AI agent cleanup: Codex, Claude, opencode, jcode, Gemini caches and sessions
- [x] Minimum macOS raised to 14.0; 26.x and 27.x supported
- [x] Ability to hide unused utility pages from global menu in Settings > Interface > Startup View - #476
- [x] "Update All" button now shows progress in toolbar for Updater view
- [x] Add pinyin sorting to homebrew view and updater view - #479
- [x] Warn if updating MAS app with a different source as it can break MAS connection - #484

### Fixes

- [x] Fix pear list-orphaned cli command - #472
- [x] Fix owner of receipt to root:wheel for installd workaround - #475
- [x] Add contentShape around sidebar toggle icons - #485
- [x] Fix computed property not refreshing action buttons in some cases for Updater view
- [x] Reorder some layout components in Updater view
- [x] Translations
