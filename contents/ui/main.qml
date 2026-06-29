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

    // ── App state ────────────────────────────────────────────────────────
    property bool appRunning: false

    // ── Quick Links state ────────────────────────────────────────────────
    property var bkList: []

    Component.onCompleted: _bkReload()

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

    // Fire-and-forget command runner
    PlasmaCore.DataSource {
        id: exeSource
        engine: "executable"
        connectedSources: []
        onNewData: disconnectSource(sourceName)
        function run(cmd) { connectSource(cmd) }
    }

    // Check-and-report runner — updates appRunning from stdout
    PlasmaCore.DataSource {
        id: checkSource
        engine: "executable"
        connectedSources: []
        onNewData: {
            root.appRunning = data["stdout"].trim().length > 0
            disconnectSource(sourceName)
        }
        function run(cmd) { connectSource(cmd) }
    }

    // Poll every 3 seconds; grep -v grep avoids self-match
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: checkSource.run(
            "ps -eo args 2>/dev/null | grep 'brave-browser.*--app' | grep -v grep | head -1"
        )
    }

    function launch() {
        exeSource.run(
            plasmoid.configuration.bravePath +
            " --app=\"" + plasmoid.configuration.homePage + "\" &"
        )
    }

    function focusApp() {
        exeSource.run(
            "wmctrl -x -a brave-browser 2>/dev/null || " +
            "xdotool search --class brave-browser windowactivate 2>/dev/null; true"
        )
    }

    function closeApp() {
        exeSource.run("pkill -f 'brave-browser.*--app' 2>/dev/null; true")
    }

    function launchQuickLink(url) {
        exeSource.run(
            plasmoid.configuration.bravePath + " --app=\"" + url + "\" &"
        )
    }

    // ── Compact representation ─────────────────────────────────────────────
    // Defined inline so it can read root.appRunning
    Plasmoid.compactRepresentation: Item {
        anchors.fill: parent

        PlasmaCore.SvgItem {
            id: compactIcon
            anchors.centerIn: parent
            width:  Math.min(parent.width, parent.height)
            height: width

            svg: PlasmaCore.Svg {
                imagePath: Qt.resolvedUrl("assets/logo.svg")
            }
        }

        // Status dot — green = running, grey = stopped
        Rectangle {
            anchors.bottom:  compactIcon.bottom
            anchors.right:   compactIcon.right
            width:  Math.max(4, Math.round(compactIcon.width * 0.28))
            height: width
            radius: width / 2
            color:  root.appRunning ? "#27ae60" : "#7f8c8d"
            border.color: theme.backgroundColor
            border.width: 1
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.appRunning)
                    root.focusApp()
                else
                    plasmoid.expanded = !plasmoid.expanded
            }
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

        // ── Status ───────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    width:  Kirigami.Units.gridUnit * 0.55
                    height: width
                    radius: width / 2
                    color:  root.appRunning ? "#27ae60" : "#7f8c8d"
                }

                PlasmaComponents.Label {
                    text:  root.appRunning ? i18n("Running") : i18n("Not running")
                    color: root.appRunning
                        ? Kirigami.Theme.positiveTextColor
                        : Kirigami.Theme.disabledTextColor
                }
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: plasmoid.configuration.homePage
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 11
                opacity: 0.65
            }
        }

        // ── Controls ─────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Button {
                Layout.fillWidth: true
                visible: !root.appRunning
                text: i18n("Launch in Brave")
                icon.name: "media-playback-start"
                onClicked: root.launch()
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.appRunning
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Button {
                    Layout.fillWidth: true
                    text: i18n("Focus Window")
                    icon.name: "window-restore"
                    onClicked: root.focusApp()
                }

                PlasmaComponents.Button {
                    text: i18n("Close")
                    icon.name: "media-playback-stop"
                    onClicked: root.closeApp()
                }
            }
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
