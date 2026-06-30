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

    // Set when edit-mode exit is detected; cleared once reposition fires
    property bool pendingReposition: false

    // Watches plasmoid.containment.editMode — no-op if containment is unavailable
    // (Plasma versions that expose this API will get automatic reposition on edit-mode exit)
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
        startupCheckSource.run(
            "DISPLAY=:0; WID=$(cat /tmp/brave-widget-wid.txt 2>/dev/null | tr -d '\\n'); " +
            "[ -n \"$WID\" ] && xdotool getwindowgeometry \"$WID\" >/dev/null 2>&1 && echo ok || true"
        )
    }

    Connections {
        target: plasmoid.configuration
        function onBookmarksChanged() { _bkReload() }
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

    // ── Process management ────────────────────────────────────────────────

    property bool hasKnownWindow: false

    // Fire-and-forget command runner
    PlasmaCore.DataSource {
        id: exeSource
        engine: "executable"
        connectedSources: []
        onNewData: disconnectSource(sourceName)
        function run(cmd) { connectSource(cmd) }
    }

    // Snapshots Brave window IDs before a fresh launch
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

    // Checks at startup whether a previously embedded window is still alive
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

    // Closes the embedded window and clears the tracked window ID
    PlasmaCore.DataSource {
        id: closeWindowSource
        engine: "executable"
        connectedSources: []
        onNewData: {
            root.hasKnownWindow = false
            disconnectSource(sourceName)
        }
        function run(cmd) { connectSource(cmd) }
    }

    // Tries to reposition a known existing window; outputs "ok" if it worked
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
            }
            disconnectSource(sourceName)
        }
        function run(cmd) { connectSource(cmd) }
    }

    // Snaps a newly launched window: unmaximize → move → read title bar → re-move
    Timer {
        id: positionTimer
        interval: 1800
        repeat: false
        property int wx: 0
        property int wy: 0
        property int ww: 400
        property int wh: 600
        onTriggered: {
            var noBorderVal = plasmoid.configuration.hideDecorations ? "true" : "false"
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
        }
    }

    // Called by the Launch button with geometry captured inside fullRep's scope
    function launch(wx, wy, ww, wh) {
        repositionSource.wx = wx
        repositionSource.wy = wy
        repositionSource.ww = ww
        repositionSource.wh = wh
        var noBorderVal = plasmoid.configuration.hideDecorations ? "true" : "false"
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

    // Fresh launch path — called by repositionSource when no known window exists
    function _freshLaunch(wx, wy, ww, wh) {
        exeSource.run("rm -f /tmp/brave-widget-wid.txt")
        widsSource.run("DISPLAY=:0 xdotool search --class Brave 2>/dev/null | sort -n | tr '\\n' ','")
        exeSource.run(
            plasmoid.configuration.bravePath +
            " --app=\"" + plasmoid.configuration.homePage + "\" &"
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
        spacing: Kirigami.Units.largeSpacing

        Layout.minimumWidth:  260 * PlasmaCore.Units.devicePixelRatio
        Layout.minimumHeight: 180 * PlasmaCore.Units.devicePixelRatio
        Layout.preferredWidth:  340 * PlasmaCore.Units.devicePixelRatio
        Layout.preferredHeight: 420 * PlasmaCore.Units.devicePixelRatio

        Binding {
            target: plasmoid
            property: "hideOnWindowDeactivate"
            value: !plasmoid.configuration.pin
        }

        // Fires when popup opens after an edit-mode exit (future Plasma versions)
        Connections {
            target: plasmoid
            function onExpandedChanged() {
                if (plasmoid.expanded && root.pendingReposition) {
                    root.pendingReposition = false
                    autoRepositionTimer.start()
                }
            }
        }

        Timer {
            id: autoRepositionTimer
            interval: 800
            repeat: false
            onTriggered: {
                var pos = fullRep.mapToGlobal(0, 0)
                root.launch(Math.round(pos.x), Math.round(pos.y),
                            Math.round(fullRep.width), Math.round(fullRep.height))
            }
        }

        // ── Header ──────────────────────────────────────────────────────
        PlasmaExtras.PlasmoidHeading {
            Layout.fillWidth: true

            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                PlasmaCore.SvgItem {
                    width:  Kirigami.Units.iconSizes.medium
                    height: width
                    svg: PlasmaCore.Svg { imagePath: Qt.resolvedUrl("assets/logo.svg") }
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: "Brave Widget Browser"
                    font.bold: true
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
        }

        // ── URL label ────────────────────────────────────────────────────
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: plasmoid.configuration.homePage
            elide: Text.ElideMiddle
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 11
            opacity: 0.65
        }

        // ── Launch button ─────────────────────────────────────────────────
        PlasmaComponents.Button {
            Layout.fillWidth: true
            text: i18n("Embed Brave")
            icon.name: "media-playback-start"
            onClicked: {
                var pos = fullRep.mapToGlobal(0, 0)
                root.launch(Math.round(pos.x), Math.round(pos.y),
                            Math.round(fullRep.width), Math.round(fullRep.height))
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
