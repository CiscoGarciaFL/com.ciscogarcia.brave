# Brave Widget Browser — KDE Plasma Widget

A KDE Plasma 5 widget that snaps a Brave Browser app-mode window to the widget popup position,
giving any web app a native-feeling panel launcher with a configurable home page.

## Features

- Launches any web app in **Brave app mode** — no tabs, no address bar, looks like a native app
- Configurable **App URL** (defaults to `https://kde.org`)
- **Embed Brave** button — snaps the Brave window to the widget popup position
- **Close Window** button — cleanly closes the tracked Brave window from within the widget
- **Hide title bar** option — removes window decorations via KWin scripting (Advanced settings)
- **Quick Links** — saved URLs that each open their own Brave app window
- **Pin toggle** — keep the widget open after losing focus
- Widget icon shows in the Add Widgets dialog (no snap icon-theme dependency)

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

- KDE Plasma 5.24+
- Brave Browser installed (snap: `/snap/bin/brave`, or system package)
- `wmctrl`, `xdotool` — used for window positioning

On Debian/Ubuntu: `sudo apt install wmctrl xdotool`

## Configuration

Right-click the widget → **Configure…**

| Setting | Tab | Description |
|---------|-----|-------------|
| App URL | General | Home page opened when the widget launches Brave |
| Pin widget open | General | Keep the widget visible after losing focus |
| Add / remove quick links | Links | Saved URLs, each opens its own Brave app window |
| Hide window title bar | Advanced | Removes decorations via KWin scripting for a cleaner look |
| Brave executable | Advanced | Full path to Brave (`/snap/bin/brave`, `brave-browser`, etc.) |

## Contributing

Pull requests are welcome — please open a PR against `main`.

## Changelog

### v2.2.0
- **Hide title bar** — new Advanced option removes window decorations via KWin DBus scripting API
  (`workspace.clientList()` → `noBorder = true/false`); survives repeated calls via unique script names
- **Close Window button** — visible in the widget when a Brave window is tracked; cleanly closes
  it and clears state
- **Startup window detection** — widget restores its "window known" state across plasmashell restarts
- **Follows across virtual desktops** — Brave window is set to All Desktops so it stays visible
  no matter which virtual desktop you switch to
- **Smart Embed Brave button** — realigns an existing Brave window back over the widget popup if
  one is already open; launches a new window if none exists
- **Widget icon** — now shows correctly in Add Widgets dialog for snap-installed Brave (icon no
  longer depends on the system icon theme; bundled `logo.svg` used instead)
- Default App URL changed to `https://kde.org`

### v2.1.0
- Window snaps to the widget popup position on launch
- Brave window is set sticky (visible on all virtual desktops)
- Title-bar height measured via `_NET_FRAME_EXTENTS` for precise vertical alignment

### v2.0.0
- **Complete rewrite** — replaced embedded QtWebEngine with a Brave app-mode launcher
- Fixes Teams, Outlook, and other modern web apps that require a current Chromium version
- Launch, Focus Window, and Close controls in the full widget view
- Quick Links panel: each saved link opens its own Brave app window
- Simplified config: App URL (General), Quick Links (Links), Brave path (Advanced)

### v1.3.0
- **User-Agent spoofing** — defaults to Microsoft Edge on Linux so sites like Teams, Office 365,
  and other Microsoft/enterprise apps accept the browser
- **Auto-grant permissions** — camera, microphone, screen-share and notifications granted
  automatically (toggle in Advanced settings)

### v1.2.2
- Logo updated: official Brave lion composited inside a KDE Plasma Breeze-style widget frame

### v1.2.1
- Switched license from GPL-3.0 to **Apache 2.0**

### v1.2.0
- **Quick Links** — bookmark URLs by name; each opens its own Brave app window
- Links config tab for managing saved URLs

### v1.1.0
- Renamed product to **Brave Widget Browser**
- Default home page changed to `https://kde.org`

### v1.0.0
- Initial release

## License

Apache-2.0 © CiscoGarciaFL
