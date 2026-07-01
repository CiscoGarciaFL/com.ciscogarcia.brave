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

    // ── Process state ─────────────────────────────────────────────────────

    property bool hasKnownWindow: false
    property bool braveFound: false
    property bool braveCheckDone: false
    property string currentUrl: plasmoid.configuration.homePage
    property bool navigating: false
    property bool _firstExpand: true

    // ── DataSources ───────────────────────────────────────────────────────

    PlasmaCore.DataSource {
        id: exeSource
        engine: "executable"
        connectedSources: []
        onNewData: disconnectSource(sourceName)
        // Salt ensures each call is a unique source name, preventing DataSource result caching
        function run(cmd) { connectSource(cmd + " #" + Math.random()) }
    }

    // widsSource captures before-window state THEN launches Brave sequentially to avoid race
    PlasmaCore.DataSource {
        id: widsSource
        engine: "executable"
        connectedSources: []
        property int wx: 0
        property int wy: 0
        property int ww: 400
        property int wh: 600
        onNewData: {
            var wids = data["stdout"].trim()
            exeSource.run("printf '%s\\n' " + (wids.length > 0 ? wids.replace(/,/g, " ") : "''") + " | grep -v '^$' > /tmp/brave-before-wids.txt")
            exeSource.run(plasmoid.configuration.bravePath + " --app=\"" + root.currentUrl + "\" &")
            positionTimer.wx = wx
            positionTimer.wy = wy
            positionTimer.ww = ww
            positionTimer.wh = wh
            positionTimer.restart()
            disconnectSource(sourceName)
        }
        function run(cmd) { connectSource(cmd + " #" + Math.random()) }
    }

    PlasmaCore.DataSource {
        id: startupCheckSource
        engine: "executable"
        connectedSources: []
        onNewData: {
            if (data["stdout"].trim() === "ok") root.hasKnownWindow = true
            disconnectSource(sourceName)
        }
        function run(cmd) { connectSource(cmd + " #" + Math.random()) }
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
        function run(cmd) { connectSource(cmd + " #" + Math.random()) }
    }

    PlasmaCore.DataSource {
        id: closeWindowSource
        engine: "executable"
        connectedSources: []
        onNewData: {
            root.hasKnownWindow = false
            disconnectSource(sourceName)
        }
        function run(cmd) { connectSource(cmd + " #" + Math.random()) }
    }

    // Kills the Brave window, waits for it to actually die, then triggers _freshLaunch
    // Sequential: no timer guessing — _freshLaunch only runs after kill completes
    PlasmaCore.DataSource {
        id: navCloseSource
        engine: "executable"
        connectedSources: []
        property int wx: 0
        property int wy: 0
        property int ww: 400
        property int wh: 600
        onNewData: {
            disconnectSource(sourceName)
            root._freshLaunch(wx, wy, ww, wh)
        }
        function run(cmd) { connectSource(cmd + " #" + Math.random()) }
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
            }
            disconnectSource(sourceName)
        }
        function run(cmd) { connectSource(cmd + " #" + Math.random()) }
    }

    // ── Window positioning ────────────────────────────────────────────────

    Timer {
        id: positionTimer
        interval: 3500
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
            root.navigating = false
            navTimeoutTimer.stop()
        }
    }

    function launch(wx, wy, ww, wh) {
        if (positionTimer.running || root.navigating) return
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
            "xprop -id \"$WID\" WM_STATE 2>/dev/null | grep -qE 'Normal|Iconic' || exit 0; " +
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
        widsSource.wx = wx
        widsSource.wy = wy
        widsSource.ww = ww
        widsSource.wh = wh
        widsSource.run("DISPLAY=:0 xdotool search --class Brave 2>/dev/null | sort -n | tr '\\n' ','")
        root.hasKnownWindow = true
    }

    function launchQuickLink(url) {
        exeSource.run(
            plasmoid.configuration.bravePath + " --app=\"" + url + "\" &"
        )
    }

    // Brave app-mode has no address bar; navigate by killing and relaunching at new URL.
    // Coordinates must be computed by the caller (inside fullRep scope) and passed in.
    function navigateTo(url, wx, wy, ww, wh) {
        root.currentUrl = url
        if (positionTimer.running || root.navigating) return
        root.navigating = true
        root.hasKnownWindow = false
        navTimeoutTimer.restart()
        navCloseSource.wx = wx
        navCloseSource.wy = wy
        navCloseSource.ww = ww
        navCloseSource.wh = wh
        navCloseSource.run(
            "DISPLAY=:0; WID=$(cat /tmp/brave-widget-wid.txt 2>/dev/null | tr -d '\\n'); " +
            "if [ -n \"$WID\" ]; then " +
                "xdotool windowclose \"$WID\" 2>/dev/null; " +
                "i=0; while [ $i -lt 30 ] && xprop -id \"$WID\" WM_STATE 2>/dev/null | grep -qE 'Normal|Iconic'; do sleep 0.1; i=$((i+1)); done; " +
            "fi; " +
            "rm -f /tmp/brave-widget-wid.txt"
        )
    }

    Timer {
        id: navTimeoutTimer
        interval: 10000
        repeat: false
        onTriggered: { root.navigating = false }
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

        // showAddressBar config controls whether Brave sits below the bar or covers it.
        // The bar is always rendered; Apply/Embed is what moves the window.
        property real barOffset: plasmoid.configuration.showAddressBar
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
                if (plasmoid.expanded && root.pendingReposition) {
                    root.pendingReposition = false
                    autoRepositionTimer.start()
                }
                if (plasmoid.expanded && root._firstExpand) {
                    root._firstExpand = false
                    if (plasmoid.configuration.autoEmbed && !root.hasKnownWindow)
                        autoEmbedTimer.start()
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

        Timer {
            id: autoEmbedTimer
            interval: 400
            repeat: false
            onTriggered: {
                var pos = fullRep.mapToGlobal(0, 0)
                var barH = Math.round(fullRep.barOffset)
                root.launch(Math.round(pos.x), Math.round(pos.y) + barH,
                            Math.round(fullRep.width), Math.round(fullRep.height) - barH)
            }
        }

        // ── Address bar ───────────────────────────────────────────────────
        RowLayout {
            id: addressHeader
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            spacing: Kirigami.Units.smallSpacing

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
                onAccepted: {
                    var pos = fullRep.mapToGlobal(0, 0)
                    var barH = Math.round(fullRep.barOffset)
                    root.navigateTo(text,
                        Math.round(pos.x), Math.round(pos.y) + barH,
                        Math.round(fullRep.width), Math.round(fullRep.height) - barH)
                }
            }

            // Save current URL to Quick Links
            PlasmaComponents.ToolButton {
                icon.name: "bookmark-new"
                display: PlasmaComponents.ToolButton.IconOnly
                PlasmaComponents.ToolTip.text: i18n("Save to Quick Links")
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.visible: hovered
                onClicked: root.addBookmark(urlField.text)
            }

            // Navigate to URL in existing Brave window (triangle, no icon.name — custom contentItem)
            PlasmaComponents.ToolButton {
                PlasmaComponents.ToolTip.text: i18n("Go")
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.visible: hovered
                onClicked: {
                    var pos = fullRep.mapToGlobal(0, 0)
                    var barH = Math.round(fullRep.barOffset)
                    root.navigateTo(urlField.text,
                        Math.round(pos.x), Math.round(pos.y) + barH,
                        Math.round(fullRep.width), Math.round(fullRep.height) - barH)
                }
                contentItem: Canvas {
                    id: goCanvas
                    implicitWidth:  Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    property color fgColor: Kirigami.Theme.textColor
                    Component.onCompleted: requestPaint()
                    onFgColorChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.fillStyle = fgColor
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.lineTo(width, height / 2)
                        ctx.lineTo(0, height)
                        ctx.closePath()
                        ctx.fill()
                    }
                }
            }

            // Toggle title bar — updates config only; Apply/Embed makes it take effect
            PlasmaComponents.ToolButton {
                icon.name: plasmoid.configuration.hideDecorations ? "view-fullscreen" : "view-restore"
                display: PlasmaComponents.ToolButton.IconOnly
                PlasmaComponents.ToolTip.text: plasmoid.configuration.hideDecorations
                    ? i18n("Show Title Bar (apply to take effect)")
                    : i18n("Hide Title Bar (apply to take effect)")
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.visible: hovered
                onClicked: plasmoid.configuration.hideDecorations = !plasmoid.configuration.hideDecorations
            }

            // Toggle cover — updates config only; Apply/Embed makes it take effect
            Item {
                implicitWidth:  coverRevealBtn.implicitWidth
                implicitHeight: coverRevealBtn.implicitHeight
                Layout.alignment: Qt.AlignVCenter

                PlasmaComponents.ToolButton {
                    id: coverRevealBtn
                    anchors.fill: parent
                    icon.name: plasmoid.configuration.showAddressBar ? "go-down" : "go-up"
                    display: PlasmaComponents.ToolButton.IconOnly
                    PlasmaComponents.ToolTip.text: plasmoid.configuration.showAddressBar
                        ? i18n("Cover Address Bar (apply to take effect)")
                        : i18n("Reveal Address Bar (apply to take effect)")
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                    PlasmaComponents.ToolTip.visible: hovered
                    onClicked: plasmoid.configuration.showAddressBar = !plasmoid.configuration.showAddressBar
                }

                Rectangle {
                    width: parent.width
                    height: 3
                    color: Kirigami.Theme.textColor
                    y: plasmoid.configuration.showAddressBar ? parent.height - height : 0
                }
            }

            // Apply/Embed — launches or repositions Brave using current config settings
            PlasmaComponents.ToolButton {
                icon.name: "dialog-ok-apply"
                display: PlasmaComponents.ToolButton.IconOnly
                PlasmaComponents.ToolTip.text: i18n("Embed Brave")
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.visible: hovered
                onClicked: {
                    root.currentUrl = urlField.text
                    var pos = fullRep.mapToGlobal(0, 0)
                    var barH = Math.round(fullRep.barOffset)
                    root.launch(Math.round(pos.x), Math.round(pos.y) + barH,
                                Math.round(fullRep.width), Math.round(fullRep.height) - barH)
                }
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

        // ── Navigating indicator ──────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            visible: root.navigating
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: "#ff9800"
            }

            PlasmaComponents.Label {
                text: i18n("Opening URL…")
                font.pixelSize: 11
                color: "#ff9800"
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
            text: i18n("Close Window  (Alt+F4)")
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
