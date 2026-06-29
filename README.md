# Brave Widget Browser — KDE Plasma Widget

A KDE Plasma widget that embeds a full Chromium-based browser (via Qt WebEngine) with a
dedicated address bar and a configurable home page.

## Features

- Launches any web app in **Brave app mode** — no tabs, no address bar, looks like a native app
- Configurable App URL (defaults to `https://teams.microsoft.com`)
- **Status indicator** — green dot when running, grey when stopped (on panel icon and full widget)
- **Launch / Focus / Close** controls — one click to open, bring to front, or kill the app
- **Quick Links** — saved URLs that each open their own Brave app window
- Manage Quick Links from **Configure → Links**
- Pin toggle to keep the widget open after losing focus

> **Why Brave app mode?** Embedded browser engines (QtWebEngine) use Chromium 87 which Microsoft
> Teams and other modern web apps no longer support. Brave ships a current Chromium and passes
> all site compatibility checks that embedded engines fail.

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
| App URL | General | URL opened in Brave app mode |
| Pin widget open | General | Keep the widget visible after losing focus |
| Add / remove quick links | Links | Saved URLs, each opens its own Brave app window |
| Brave executable | Advanced | Command/path to Brave (`brave-browser`, `brave`, etc.) |

## Contributing

Pull requests are welcome — please open a PR against `main`.
Direct pushes to `main` are disabled; all changes go through PRs.

## Changelog

### v2.0.0
- **Complete rewrite** — replaced embedded QtWebEngine with a Brave app-mode launcher
- Fixes Teams, Outlook, and other modern web apps that require a current Chromium version
- Panel icon shows a live status dot (green = running, grey = stopped)
- Click panel icon when running → focuses the Brave window; when stopped → opens widget
- Launch, Focus Window, and Close controls in the full widget view
- Quick Links panel: each saved link opens its own Brave app window
- Simplified config: App URL (General), Quick Links (Links), Brave path (Advanced)

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
