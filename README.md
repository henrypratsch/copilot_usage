# CopilotUsage

![Swift](https://img.shields.io/badge/Swift-6-orange.svg) ![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg) [![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A native macOS menu bar app that shows whether your GitHub Copilot premium requests last until the reset.

## Features

- **Always Visible**: Status dot and usage in the menu bar, as percentage or request count
- **Pace Aware**: Compares your usage with the workdays elapsed and projects the end of the month
- **Daily Budget**: Requests per remaining workday, and how much of today's budget is left
- **History**: Sparkline of the current period with the projection until the reset
- **Stays Current**: Updates every 5 minutes, after waking from sleep, or on demand
- **Secure Token Storage**: Your GitHub token lives in the macOS keychain, never in a file
- **Lightweight**: Native Swift and SwiftUI, no dependencies, no Dock icon

## Installation

```bash
swift build -c release
.build/release/CopilotUsage
```

Prebuilt binaries for Apple Silicon are attached to each [release](../../releases).

## Usage

### Token

Open the menu, choose **Settings…** and paste a personal access token (classic) from [github.com/settings/tokens](https://github.com/settings/tokens). No scopes are needed. The token is checked against GitHub before it is saved to your login keychain. Use **Remove Token** to delete it.

CopilotUsage is not signed with an Apple Developer ID, so macOS may ask once whether it may access its keychain entry after an update — choose **Always Allow**.

### Settings

- **Menu bar**: Used or remaining, as percentage or request count
- **Monthly limit**: Overrides the limit reported by GitHub
- **Clear History…**: Deletes all recorded usage

Settings and history are stored in `~/Library/Application Support/CopilotUsage`. Workdays default to Monday to Friday and can be changed in `settings.json`.

### Uninstall

```bash
security delete-generic-password -s com.copilotusage.CopilotUsage -a github-token
rm -rf ~/Library/Application\ Support/CopilotUsage
```

## Requirements

- macOS 14 or later
- A GitHub account with a Copilot plan
- A personal access token (classic)

## How It Works

1. Reads your token from the login keychain
2. Fetches your quota from `api.github.com/copilot_internal/user` over an ephemeral, uncached connection
3. Records the usage per day to tell today's usage apart from the rest of the period
4. Derives the daily budget, pace and projection from the workdays until the reset

The endpoint is not officially documented by GitHub and may change.

## Development

```bash
swift run
swift test
swift build -c release
```

`CopilotUsageCore` contains all logic and is covered by tests, `CopilotUsage` contains the SwiftUI app.

Release a new version with `./create-release.sh <version>`.

## License

MIT — see [LICENSE](LICENSE).
