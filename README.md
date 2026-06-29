# Brave Widget Browser — KDE Plasma Widget

A KDE Plasma widget that embeds a full Chromium-based browser (via Qt WebEngine) with a
dedicated address bar and a configurable home page.

## Features

- Configurable home page URL (defaults to `https://kde.org`)
- Navigation toolbar: Back, Forward, Home, Bookmarks toggle, Reload/Stop
- Address bar with **bookmark star** — click to save or remove the current page
- **Bookmarks sidebar** — collapsible panel listing all saved links; click any to navigate
- Manage bookmarks from **Configure → Links** (add by name + URL, delete individually)
- Optional address bar (on by default, can be hidden in General settings)
- Persistent cookies and disk cache (stays logged in across sessions)
- Pin toggle to keep the widget open after losing focus
- Developer console / WebEngine inspector

## Installation

### From KDE Store (Add Widget)

1. Right-click your desktop or panel → **Add Widgets…**
2. Click **Get New Widgets** → **Download New Plasma Widgets**
3. Search for **Brave Widget Browser** and install.

### From release `.plasmoid` file

1. Download the latest `.plasmoid` from [Releases](../../releases).
2. Right-click desktop → **Add Widgets…** → **Install from local file…**
3. Select the downloaded `.plasmoid`.

### From source

```bash
git clone https://github.com/CiscoGarciaFL/com.ciscogarcia.brave.git
cd com.ciscogarcia.brave
kpackagetool6 --install . --type Plasma/Applet
# or for Plasma 5:
plasmapkg2 --install .
```

## Requirements

- KDE Plasma 5.24+ or Plasma 6
- Qt 5.15+ / Qt 6 with `qtwebengine` installed

On Debian/Ubuntu: `sudo apt install qml-module-qtwebengine`
On Arch: `sudo pacman -S qt5-webengine` (Plasma 5) or `qt6-webengine` (Plasma 6)

## Configuration

Right-click the widget → **Configure…**

| Setting | Tab | Description |
|---------|-----|-------------|
| Home Page URL | General | URL loaded on start and when Home is pressed |
| Show address bar | General | Toggle the URL bar and bookmark star |
| Allow clipboard access | General | Let pages read/write the system clipboard |
| Pin widget open | General | Keep it visible after losing focus |
| Add / remove bookmarks | Links | Manage saved links by name and URL |
| Developer console | Advanced | Show the WebEngine inspector toggle |

## Contributing

Pull requests are welcome — please open a PR against `main`.
Direct pushes to `main` are disabled; all changes go through PRs.

## Changelog

### v1.3.0
- **User-Agent spoofing** — defaults to Microsoft Edge on Linux so sites like Teams, Office 365, and other Microsoft/enterprise apps accept the browser
- **Auto-grant permissions** — camera, microphone, screen-share and notifications granted automatically (toggle in Advanced settings)
- **Screen capture enabled** — allows screen sharing in calls
- **WebRTC** — all network interfaces available for best call connectivity
- User-Agent and permission grant are both configurable in **Configure → Advanced**

### v1.2.2
- Logo updated: official Brave lion composited inside a KDE Plasma Breeze-style widget frame

### v1.2.1
- Switched license from GPL-3.0 to **Apache 2.0** (permissive with attribution + patent grant)

### v1.2.0
- **Bookmarks / Links** — bookmark star next to the address bar saves the current page; collapsible sidebar lists all saved bookmarks
- **Links config tab** — add bookmarks by name + URL, delete individually, from Configure → Links
- Restored **Show address bar** toggle in General settings (defaults to on)

### v1.1.0
- Renamed product to **Brave Widget Browser**
- Address bar promoted to its own dedicated row — always visible, no longer a toggle
- Default home page changed to `https://kde.org`
- Removed "Show address bar" config option (no longer needed)

### v1.0.1
- Default home page changed to `https://kde.org`

### v1.0.0
- Initial release

## License

Apache-2.0 © CiscoGarciaFL
