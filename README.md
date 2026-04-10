# AutoPkg Wizard

A modern macOS SwiftUI application for managing [AutoPkg](https://github.com/autopkg/autopkg). AutoPkg Wizard provides a graphical interface for common AutoPkg tasks, serving as a modern alternative to [AutoPkgr](https://github.com/lindegroup/autopkgr).

![Overview](images/Overview.png)

## Requirements

- macOS 15.0 (Sequoia) or later
- [AutoPkg](https://github.com/autopkg/autopkg/releases) installed at `/usr/local/bin/autopkg`

## Features

### Overview

The landing page shows a dashboard with counts of repos, recipes, and overrides, along with the installed AutoPkg version. From here you can view and edit AutoPkg preferences stored in the `com.github.autopkg` defaults domain — add, edit, and delete key/value pairs directly.

### Repos

![Repos](images/Repos.png)

- View all installed AutoPkg recipe repos with their GitHub URLs
- Add repos by short name (e.g. `grahampugh-recipes`) or full GitHub URL
- Edit mode with multi-select for bulk removal
- Update all repos with real-time streaming output

### Recipes

![Recipes](images/Recipes.png)

- Manage a recipe list file (default: `~/Library/AutoPkg/recipe-list.txt`)
- Add recipes from locally available recipes, GitHub search, or manual entry
- When adding a recipe from search, the required repo is automatically added if not already installed
- Drag to reorder and edit mode with multi-select for bulk removal
- Run individual recipes or the entire list, with real-time streaming log output
- View detailed recipe info (parent recipes, processors, input values) via the info button
- Create recipe overrides directly from the recipe list
- Visual recipe type indicators (`.jamf`, `.munki`, `.download`, `.pkg`, `.install`)
- Automatic `MakeCatalogs.munki` management — added to the end of the list when `.munki` recipes are present, along with the required `autopkg/recipes` repo and override

### Overrides

![Overrides](images/Overrides.png)

- Browse existing recipe overrides from `~/Library/AutoPkg/RecipeOverrides/`
- View override file contents in a detail pane
- Verify and update trust info per override with status indicators
- Reveal override files in Finder
- Edit mode with multi-select for bulk deletion

### Schedule

![Schedule](images/Schedule.png)

- Schedule automatic AutoPkg recipe runs using macOS `launchd`
- Configure run time (hour/minute) and days of the week
- Quick presets for "Every Day" and "Weekdays Only"
- Enable/disable the schedule with automatic LaunchAgent management
- View next scheduled run time, agent status, and last run time

## Building

Build the `.app` bundle using the included script:

```bash
./build_app.sh           # Debug build
./build_app.sh release   # Release build
```

The app bundle is output to `.build/debug/AutoPkgWizard.app` (or `.build/release/` for release builds).

Alternatively, build with Swift Package Manager directly:

```bash
swift build
```

## Architecture

The app follows an MVVM pattern:

- **Models** — Data types for repos, recipes, overrides, recipe info, and navigation
- **Services** — `AutoPkgCLI` wraps the `autopkg` binary with async/streaming support; `LaunchAgentManager` handles launchd scheduling
- **ViewModels** — `@Observable` classes that bridge services to views
- **Views** — SwiftUI views for each section of the app

All AutoPkg operations are performed by shelling out to the `autopkg` CLI binary. Long-running commands (repo update, recipe runs) stream output in real-time using `AsyncStream` and `FileHandle.readabilityHandler`.

## License

MIT
