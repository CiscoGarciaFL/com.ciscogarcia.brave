/*
 * SPDX-FileCopyrightText: 2024 CiscoGarciaFL <me@ciscogarcia.com>
 * SPDX-License-Identifier: Apache-2.0
 */

import QtQuick 2.3
import QtQuick.Layouts 1.0
import QtQuick.Controls 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.19 as Kirigami

Item {
    id: root

    // ── Quick Links state ────────────────────────────────────────────────
    property var bkList: []

    property bool pendingReposition: false

    property bool inEditMode: plasmoid.containment ? !!plasmoid.containment.editMode : false
    onInEditModeChanged: {
        if (!inEditMode) editModeSettleTimer.start()
    }

    Timer {
        id: editModeSettleTimer
        interval: 800
        repeat: false
        onTriggered: widCheckSource.run("cat /tmp/brave-widget-wid.txt 2>/dev/null | tr -d '\\n'")
    }

    PlasmaCore.DataSource {
        id: widCheckSource
        engine: "executable"
        connectedSources: []
        onNewData: {
            if (data["stdout"].trim().length > 0) {
                root.pendingReposition = true
                plasmoid.expanded = true
            }
            disconnectSource(sourceName)
        }
        function run(cmd) { connectSource(cmd) }
    }

    Component.onCompleted: {
        _bkReload()
        checkBravePath()
        startupCheckSource.run(
            "DISPLAY=:0; WID=$(cat /tmp/brave-widget-wid.txt 2>/dev/null | tr -d '\\n'); " +
            "[ -n \"$WID\" ] && xdotool getwindowgeometry \"$WID\" >/dev/null 2>&1 && echo ok || true"
        )
    }

    Connections {
        target: plasmoid.configuration
        function onBookmarksChanged() { _bkReload() }
        function onBravePathChanged() { root.checkBravePath() }
    }

    function _bkReload() {
        try {
            var raw = plasmoid.configuration.bookmarks
            bkList = (raw && raw.length > 2) ? JSON.parse(raw) : []
        } catch(e) { bkList = [] }
    }

    function _bkSave() {
        plasmoid.configuration.bookmarks = JSON.stringify(bkList)
    }

    function removeBookmarkAt(idx) {
        var list = JSON.parse(JSON.stringify(bkList))
        list.splice(idx, 1)
        bkList = list
        _bkSave()
    }

    // ── Process / session state ───────────────────────────────────────────

    property bool hasKnownWindow: false

    // Session-only — bar always shows on popup open; auto-hides per config after embed
    property bool sessionShowAddressBar: true
    property bool sessionHideDecorations: plasmoid.configuration.hideDecorations
    property string currentUrl: plasmoid.configuration.homePage

    // Brave executable check
    property bool braveFound: false
    property bool braveCheckDone: false

    // ── DataSources ───────────────────────────────────────────────────────

    PlasmaCore.DataSource {
        id: exeSource
        engine: "executable"
        connectedSources: []
        onNewData: disconnectSource(sourceName)
        function run(cmd) { connectSource(cmd) }
    }

    PlasmaCore.DataSource {
        id: widsSource
        engine: "executable"
        connectedSources: []
        onNewData: {
            var wids = data["stdout"].trim()
            exeSource.run("echo '" + wids + "' | tr ',' '\\n' | grep -v '^$' > /tmp/brave-before-wids.txt")
            disconnectSource(sourceName)
        }
        function run(cmd) { connectSource(cmd) }
    }

    PlasmaCore.DataSource {
        id: startupCheckSource
        engine: "executable"
        connectedSources: []
        onNewData: {
            if (data["stdout"].trim() === "ok") root.hasKnownWindow = true
            disconnectSource(sourceName)
        }
        function run(cmd) { connectSource(cmd) }
    }

    PlasmaCore.DataSource {
        id: braveCheckSource
        engine: "executable"
        connectedSources: []
        onNewData: {
            root.braveFound = (data["stdout"].trim() === "ok")
            root.braveCheckDone = true
            disconnectSource(sourceName)
        }
        function run(cmd) { connectSource(cmd) }
    }

    PlasmaCore.DataSource {
        id: closeWindowSource
        engine: "executable"
        connectedSources: []
        onNewData: {
            root.hasKnownWindow = false
            root.sessionShowAddressBar = true
            disconnectSource(sourceName)
        }
        function run(cmd) { connectSource(cmd) }
    }

    PlasmaCore.DataSource {
        id: repositionSource
        engine: "executable"
        connectedSources: []
        property int wx: 0
        property int wy: 0
        property int ww: 400
        property int wh: 600
        onNewData: {
            if (data["stdout"].trim() !== "ok") {
                root._freshLaunch(wx, wy, ww, wh)
            } else {
                root.hasKnownWindow = true
                // Auto-hide bar after re-embed if config requests it
                if (!plasmoid.configuration.showAddressBar) {
                    root.sessionShowAddressBar = false
                }
            }
            disconnectSource(sourceName)
        }
        function run(cmd) { connectSource(cmd) }
    }

    // ── Window positioning ────────────────────────────────────────────────

    Timer {
        id: positionTimer
        interval: 1800
        repeat: false
        property int wx: 0
        property int wy: 0
        property int ww: 400
        property int wh: 600
        onTriggered: {
            var noBorderVal = root.sessionHideDecorations ? "true" : "false"
            var decorCmd =
                "echo \"var cl=workspace.clientList(),i;for(i=0;i<cl.length;i++){if(String(cl[i].windowId)==='$WID'){cl[i].noBorder=" + noBorderVal + ";break;}}\" > /tmp/brave_nodecor.js 2>/dev/null; " +
                "SID=$(qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript /tmp/brave_nodecor.js \"brave_nodecor_$$\" 2>/dev/null); " +
                "qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null 2>&1; " +
                "sleep 0.3; " +
                "[ -n \"$SID\" ] && qdbus org.kde.KWin /\"$SID\" org.kde.kwin.Script.stop >/dev/null 2>&1; "
            var cmd =
                "DISPLAY=:0; " +
                "WID=$(xdotool search --class Brave 2>/dev/null " +
                    "| grep -vFxf /tmp/brave-before-wids.txt | sort -n | tail -1); " +
                "[ -n \"$WID\" ] || exit 0; " +
                "echo $WID > /tmp/brave-widget-wid.txt; " +
                decorCmd +
                "wmctrl -i -r \"$WID\" -b remove,maximized_vert,maximized_horz; " +
                "xdotool set_desktop_for_window \"$WID\" 4294967295 2>/dev/null; " +
                "wmctrl -i -r \"$WID\" -e 0," + wx + "," + wy + "," + ww + "," + wh + "; " +
                "TOP=$(xprop -id \"$WID\" _NET_FRAME_EXTENTS 2>/dev/null | grep -oP '[0-9]+' | awk 'NR==3'); " +
                "TOP=${TOP:-0}; " +
                "wmctrl -i -r \"$WID\" -e 0," + wx + ",$((TOP+" + wy + "))," + ww + ",$(("+wh+"-TOP))"
            exeSource.run(cmd)
            root.hasKnownWindow = true
            // Auto-hide bar after fresh embed if config requests it
            if (!plasmoid.configuration.showAddressBar) {
                root.sessionShowAddressBar = false
            }
        }
    }

    function launch(wx, wy, ww, wh) {
        repositionSource.wx = wx
        repositionSource.wy = wy
        repositionSource.ww = ww
        repositionSource.wh = wh
        var noBorderVal = root.sessionHideDecorations ? "true" : "false"
        var decorCmd =
            "echo \"var cl=workspace.clientList(),i;for(i=0;i<cl.length;i++){if(String(cl[i].windowId)==='$WID'){cl[i].noBorder=" + noBorderVal + ";break;}}\" > /tmp/brave_nodecor.js 2>/dev/null; " +
            "SID=$(qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript /tmp/brave_nodecor.js \"brave_nodecor_$$\" 2>/dev/null); " +
            "qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null 2>&1; " +
            "sleep 0.3; " +
            "[ -n \"$SID\" ] && qdbus org.kde.KWin /\"$SID\" org.kde.kwin.Script.stop >/dev/null 2>&1; "
        repositionSource.run(
            "DISPLAY=:0; " +
            "WID=$(cat /tmp/brave-widget-wid.txt 2>/dev/null | tr -d '\\n'); " +
            "[ -n \"$WID\" ] || exit 0; " +
            "xdotool getwindowgeometry \"$WID\" >/dev/null 2>&1 || exit 0; " +
            decorCmd +
            "wmctrl -i -r \"$WID\" -b remove,maximized_vert,maximized_horz 2>/dev/null; " +
            "xdotool set_desktop_for_window \"$WID\" 4294967295 2>/dev/null; " +
            "wmctrl -i -r \"$WID\" -e 0," + wx + "," + wy + "," + ww + "," + wh + " 2>/dev/null; " +
            "TOP=$(xprop -id \"$WID\" _NET_FRAME_EXTENTS 2>/dev/null | grep -oP '[0-9]+' | awk 'NR==3'); " +
            "TOP=${TOP:-0}; " +
            "wmctrl -i -r \"$WID\" -e 0," + wx + ",$((TOP+" + wy + "))," + ww + ",$(("+wh+"-TOP)) 2>/dev/null; " +
            "echo ok"
        )
    }

    function _freshLaunch(wx, wy, ww, wh) {
        exeSource.run("rm -f /tmp/brave-widget-wid.txt")
        widsSource.run("DISPLAY=:0 xdotool search --class Brave 2>/dev/null | sort -n | tr '\\n' ','")
        exeSource.run(
            plasmoid.configuration.bravePath +
            " --app=\"" + root.currentUrl + "\" &"
        )
        positionTimer.wx = wx
        positionTimer.wy = wy
        positionTimer.ww = ww
        positionTimer.wh = wh
        positionTimer.restart()
        root.hasKnownWindow = true
    }

    function launchQuickLink(url) {
        exeSource.run(
            plasmoid.configuration.bravePath + " --app=\"" + url + "\" &"
        )
    }

    function navigateTo(url) {
        root.currentUrl = url
        var safe = url.replace(/\\/g, "\\\\").replace(/"/g, '\\"')
                      .replace(/\$/g, "\\$").replace(/`/g, "\\`")
        exeSource.run(
            "DISPLAY=:0; WID=$(cat /tmp/brave-widget-wid.txt 2>/dev/null | tr -d '\\n'); " +
            "[ -n \"$WID\" ] || exit 0; " +
            "xdotool windowfocus --sync \"$WID\" 2>/dev/null; " +
            "xdotool key --window \"$WID\" ctrl+l 2>/dev/null; " +
            "sleep 0.3; " +
            "xdotool type --window \"$WID\" --clearmodifiers \"" + safe + "\" 2>/dev/null; " +
            "xdotool key --window \"$WID\" Return 2>/dev/null"
        )
    }

    function toggleDecorations() {
        root.sessionHideDecorations = !root.sessionHideDecorations
        var noBorderVal = root.sessionHideDecorations ? "true" : "false"
        exeSource.run(
            "DISPLAY=:0; WID=$(cat /tmp/brave-widget-wid.txt 2>/dev/null | tr -d '\\n'); " +
            "[ -n \"$WID\" ] || exit 0; " +
            "echo \"var cl=workspace.clientList(),i;for(i=0;i<cl.length;i++){if(String(cl[i].windowId)==='$WID'){cl[i].noBorder=" + noBorderVal + ";break;}}\" > /tmp/brave_nodecor.js 2>/dev/null; " +
            "SID=$(qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript /tmp/brave_nodecor.js \"brave_nodecor_$$\" 2>/dev/null); " +
            "qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null 2>&1; " +
            "sleep 0.3; " +
            "[ -n \"$SID\" ] && qdbus org.kde.KWin /\"$SID\" org.kde.kwin.Script.stop >/dev/null 2>&1"
        )
    }

    function checkBravePath() {
        var p = plasmoid.configuration.bravePath
        var safe = p.replace(/'/g, "'\\''")
        braveCheckSource.run(
            "([ -x '" + safe + "' ] || command -v '" + safe + "' >/dev/null 2>&1) && echo ok || echo fail"
        )
    }

    function addBookmark(url) {
        if (!url || url.trim().length === 0) return
        var name = url.replace(/^https?:\/\//, "").replace(/\/$/, "").split("/")[0].split("?")[0]
        if (name.length === 0) name = url
        var list = JSON.parse(JSON.stringify(bkList))
        list.push({ name: name, url: url })
        bkList = list
        _bkSave()
    }

    // ── Compact representation ─────────────────────────────────────────────
    Plasmoid.compactRepresentation: Item {
        anchors.fill: parent

        PlasmaCore.SvgItem {
            anchors.centerIn: parent
            width:  Math.min(parent.width, parent.height)
            height: width
            svg: PlasmaCore.Svg {
                imagePath: Qt.resolvedUrl("assets/logo.svg")
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: plasmoid.expanded = !plasmoid.expanded
        }
    }

    // ── Full representation ────────────────────────────────────────────────
    Plasmoid.fullRepresentation: ColumnLayout {
        id: fullRep
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Layout.minimumWidth:  260 * PlasmaCore.Units.devicePixelRatio
        Layout.minimumHeight: 180 * PlasmaCore.Units.devicePixelRatio
        Layout.preferredWidth:  340 * PlasmaCore.Units.devicePixelRatio
        Layout.preferredHeight: 420 * PlasmaCore.Units.devicePixelRatio

        // When bar is visible: offset Brave window below it.
        // When bar is hidden: Brave covers the full popup area.
        // +4 accounts for the 2px top/bottom margin on addressHeader.
        property real barOffset: root.sessionShowAddressBar
            ? (addressHeader.height + 4 + fullRep.spacing)
            : 0

        Binding {
            target: plasmoid
            property: "hideOnWindowDeactivate"
            value: !plasmoid.configuration.pin
        }

        Connections {
            target: plasmoid
            function onExpandedChanged() {
                if (plasmoid.expanded) {
                    // Bar always re-appears when popup opens so user can interact
                    root.sessionShowAddressBar = true
                    if (root.pendingReposition) {
                        root.pendingReposition = false
                        autoRepositionTimer.start()
                    }
                }
            }
        }

        Timer {
            id: autoRepositionTimer
            interval: 800
            repeat: false
            onTriggered: {
                var pos = fullRep.mapToGlobal(0, 0)
                var barH = Math.round(fullRep.barOffset)
                root.launch(Math.round(pos.x), Math.round(pos.y) + barH,
                            Math.round(fullRep.width), Math.round(fullRep.height) - barH)
            }
        }

        // Reposition Brave after bar or decoration state changes
        Timer {
            id: repositionAfterChangeTimer
            interval: 400
            repeat: false
            onTriggered: {
                var pos = fullRep.mapToGlobal(0, 0)
                var barH = Math.round(fullRep.barOffset)
                root.launch(Math.round(pos.x), Math.round(pos.y) + barH,
                            Math.round(fullRep.width), Math.round(fullRep.height) - barH)
            }
        }

        Connections {
            target: root
            function onSessionShowAddressBarChanged() {
                if (root.hasKnownWindow) repositionAfterChangeTimer.start()
            }
            function onSessionHideDecorationsChanged() {
                if (root.hasKnownWindow) repositionAfterChangeTimer.start()
            }
        }

        // ── Combined address bar / header ─────────────────────────────────
        RowLayout {
            id: addressHeader
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            visible: root.sessionShowAddressBar
            spacing: Kirigami.Units.smallSpacing

            // Icon pinned to a fixed square matching the TextField height
            PlasmaCore.SvgItem {
                Layout.preferredWidth:  urlField.implicitHeight
                Layout.preferredHeight: urlField.implicitHeight
                Layout.maximumWidth:    urlField.implicitHeight
                Layout.maximumHeight:   urlField.implicitHeight
                Layout.alignment: Qt.AlignVCenter
                svg: PlasmaCore.Svg { imagePath: Qt.resolvedUrl("assets/logo.svg") }
            }

            PlasmaComponents.TextField {
                id: urlField
                Layout.fillWidth: true
                text: root.currentUrl
                placeholderText: "https://..."
                onAccepted: root.navigateTo(text)
            }

            PlasmaComponents.ToolButton {
                icon.name: "bookmark-new"
                display: PlasmaComponents.ToolButton.IconOnly
                PlasmaComponents.ToolTip.text: i18n("Save to Quick Links")
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.visible: hovered
                onClicked: root.addBookmark(urlField.text)
            }

            PlasmaComponents.ToolButton {
                icon.name: root.sessionHideDecorations ? "view-restore" : "view-fullscreen"
                display: PlasmaComponents.ToolButton.IconOnly
                PlasmaComponents.ToolTip.text: root.sessionHideDecorations
                    ? i18n("Show Title Bar") : i18n("Hide Title Bar")
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.visible: hovered
                onClicked: root.toggleDecorations()
            }

            PlasmaComponents.ToolButton {
                icon.name: "go-next"
                display: PlasmaComponents.ToolButton.IconOnly
                PlasmaComponents.ToolTip.text: i18n("Go")
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.visible: hovered
                onClicked: root.navigateTo(urlField.text)
            }

            PlasmaComponents.ToolButton {
                icon.name: "go-up"
                display: PlasmaComponents.ToolButton.IconOnly
                PlasmaComponents.ToolTip.text: i18n("Cover with Browser Window")
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.visible: hovered
                onClicked: root.sessionShowAddressBar = false
            }

            PlasmaComponents.ToolButton {
                icon.name: "window-pin"
                checkable: true
                checked: plasmoid.configuration.pin
                display: PlasmaComponents.ToolButton.IconOnly
                PlasmaComponents.ToolTip.text: i18n("Keep Open")
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.visible: hovered
                onToggled: plasmoid.configuration.pin = checked
            }
        }

        // ── Brave executable status ───────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            visible: root.braveCheckDone
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: root.braveFound ? "#4caf50" : "#f44336"
            }

            PlasmaComponents.Label {
                text: root.braveFound
                    ? i18n("Brave executable located")
                    : i18n("Brave browser not located")
                font.pixelSize: 11
                color: root.braveFound ? "#4caf50" : "#f44336"
                Layout.fillWidth: true
            }
        }

        // ── Launch / Close buttons ────────────────────────────────────────
        PlasmaComponents.Button {
            Layout.fillWidth: true
            text: i18n("Embed Brave")
            icon.name: "media-playback-start"
            onClicked: {
                root.currentUrl = urlField.text
                var pos = fullRep.mapToGlobal(0, 0)
                var barH = Math.round(fullRep.barOffset)
                root.launch(Math.round(pos.x), Math.round(pos.y) + barH,
                            Math.round(fullRep.width), Math.round(fullRep.height) - barH)
            }
        }

        PlasmaComponents.Button {
            Layout.fillWidth: true
            visible: root.hasKnownWindow
            text: i18n("Close Window")
            icon.name: "window-close"
            onClicked: closeWindowSource.run(
                "DISPLAY=:0; WID=$(cat /tmp/brave-widget-wid.txt 2>/dev/null | tr -d '\\n'); " +
                "[ -n \"$WID\" ] && xdotool windowclose \"$WID\" 2>/dev/null; " +
                "rm -f /tmp/brave-widget-wid.txt"
            )
        }

        // ── Quick Links ───────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.bkList.length > 0
            spacing: Kirigami.Units.smallSpacing

            PlasmaCore.SvgItem {
                Layout.fillWidth: true
                height: 1
                svg: PlasmaCore.Svg { imagePath: "widgets/line" }
                elementId: "horizontal-line"
            }

            PlasmaComponents.Label {
                text: i18n("Quick Links")
                font.bold: true
            }

            Repeater {
                model: root.bkList

                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    PlasmaComponents.ToolButton {
                        Layout.fillWidth: true
                        display: PlasmaComponents.ToolButton.TextOnly

                        contentItem: PlasmaComponents.Label {
                            text: modelData.name
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignLeft
                        }

                        PlasmaComponents.ToolTip.text: modelData.url
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                        PlasmaComponents.ToolTip.visible: hovered
                        onClicked: root.launchQuickLink(modelData.url)
                    }

                    PlasmaComponents.ToolButton {
                        icon.name: "edit-delete-remove"
                        display: PlasmaComponents.ToolButton.IconOnly
                        PlasmaComponents.ToolTip.text: i18n("Remove")
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                        PlasmaComponents.ToolTip.visible: hovered
                        onClicked: root.removeBookmarkAt(index)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
