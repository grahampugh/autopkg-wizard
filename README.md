# AutoPkg Wizard

A modern macOS SwiftUI application for managing [AutoPkg](https://github.com/autopkg/autopkg). AutoPkg Wizard provides a graphical interface for common AutoPkg tasks, serving as a modern alternative to [AutoPkgr](https://github.com/lindegroup/autopkgr).

## Requirements

- macOS 15.0 (Sequoia) or later
- [AutoPkg](https://github.com/autopkg/autopkg/releases) installed at `/usr/local/bin/autopkg` (configurable in Settings)

## Features

### Repos
- View all installed AutoPkg recipe repos
- Add repos by short name (e.g. `grahampugh-recipes`) or full GitHub URL
- Delete repos with swipe-to-delete or context menu
- Update all repos with real-time streaming output

### Recipes
- Manage a recipe list file (default: `~/Library/AutoPkg/recipe-list.txt`)
- Add recipes from locally available recipes, GitHub search, or manual entry
- Reorder and remove recipes from the list
- Run all recipes with real-time streaming log output
- Visual recipe type indicators (`.jamf`, `.munki`, `.download`, `.pkg`, `.install`)

### Overrides
- Browse existing recipe overrides from `~/Library/AutoPkg/RecipeOverrides/`
- Create new recipe overrides
- View override file contents in a detail pane
- Verify and update trust info per override with status indicators
- Delete overrides

### Schedule
- Schedule automatic AutoPkg recipe runs using macOS `launchd`
- Configure run time (hour/minute) and days of the week
- Quick presets for "Every Day" and "Weekdays Only"
- Enable/disable the schedule with automatic LaunchAgent management
- View next scheduled run time and agent status

### Settings
- Configure the path to the `autopkg` binary
- Configure the recipe list file location
- Configure the recipe overrides directory
- Version display and installation status

## Building

```bash
swift build
```

## Running

```bash
swift run
```

Or open in Xcode and run from there.

## Architecture

The app follows an MVVM pattern:

- **Models** — Data types for repos, recipes, overrides, and navigation
- **Services** — `AutoPkgCLI` wraps the autopkg binary with async/streaming support; `LaunchAgentManager` handles launchd scheduling
- **ViewModels** — `@Observable` classes that bridge services to views
- **Views** — SwiftUI views for each section of the app

All autopkg operations are performed by shelling out to the `autopkg` CLI binary. Long-running commands (repo update, recipe runs) stream output in real-time using `AsyncStream` and `FileHandle.readabilityHandler`.

## License

MIT
