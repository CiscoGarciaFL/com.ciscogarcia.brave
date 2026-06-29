# Brave Browser — KDE Plasma Widget

A KDE Plasma widget that embeds a full Chromium-based browser (via Qt WebEngine) with a configurable home page.

## Features

- Configurable home page URL (defaults to `https://search.brave.com/`)
- Navigation toolbar: Back, Forward, Home, Reload/Stop
- Optional address bar (toggle in settings)
- Persistent cookies and disk cache (stays logged in across sessions)
- Pin toggle to keep the widget open after losing focus
- Developer console / WebEngine inspector

## Installation

### From KDE Store (Add Widget)

1. Right-click your desktop or panel → **Add Widgets…**
2. Click **Get New Widgets** → **Download New Plasma Widgets**
3. Search for **Brave Browser** and install.

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

| Setting | Description |
|---------|-------------|
| Home Page URL | URL loaded on start and when Home is pressed |
| Show address bar | Toggle the URL bar in the toolbar |
| Allow clipboard access | Let pages read/write the system clipboard |
| Pin widget open | Keep it visible after losing focus |
| Developer console | Show the WebEngine inspector toggle |

## Contributing

Pull requests are welcome — please open a PR against `main`.
Direct pushes to `main` are disabled; all changes go through PRs.

## License

GPL-3.0-or-later © CiscoGarciaFL
