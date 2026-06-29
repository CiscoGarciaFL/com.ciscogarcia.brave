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
import QtWebEngine 1.9

Item {
    id: root

    // ── Bookmark state ───────────────────────────────────────────────────────
    property var  bkList: []
    property bool bkPanelOpen: false

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

    function isBookmarked(url) {
        for (var i = 0; i < bkList.length; i++)
            if (bkList[i].url === url) return true
        return false
    }

    function toggleBookmark(title, url) {
        var list = JSON.parse(JSON.stringify(bkList))
        for (var i = 0; i < list.length; i++) {
            if (list[i].url === url) {
                list.splice(i, 1)
                bkList = list
                _bkSave()
                return
            }
        }
        list.push({ name: (title && title.length > 0) ? title : url, url: url })
        bkList = list
        _bkSave()
    }

    function removeBookmarkAt(idx) {
        var list = JSON.parse(JSON.stringify(bkList))
        list.splice(idx, 1)
        bkList = list
        _bkSave()
    }

    // ────────────────────────────────────────────────────────────────────────

    Plasmoid.compactRepresentation: CompactRepresentation {}

    Plasmoid.fullRepresentation: ColumnLayout {
        id: fullRep
        anchors.fill: parent
        spacing: 0

        Layout.minimumWidth:  320 * PlasmaCore.Units.devicePixelRatio
        Layout.minimumHeight: 480 * PlasmaCore.Units.devicePixelRatio
        Layout.preferredWidth:  800 * PlasmaCore.Units.devicePixelRatio
        Layout.preferredHeight: 600 * PlasmaCore.Units.devicePixelRatio

        Binding {
            target: plasmoid
            property: "hideOnWindowDeactivate"
            value: !plasmoid.configuration.pin
        }

        // ── Toolbar ──────────────────────────────────────────────────────────
        PlasmaExtras.PlasmoidHeading {
            Layout.fillWidth: true

            ColumnLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                // Row 1 — navigation buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.ToolButton {
                        icon.name: "go-previous"
                        enabled: webView.canGoBack
                        display: PlasmaComponents.ToolButton.IconOnly
                        PlasmaComponents.ToolTip.text: i18n("Back")
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                        PlasmaComponents.ToolTip.visible: hovered
                        onClicked: webView.goBack()
                    }

                    PlasmaComponents.ToolButton {
                        icon.name: "go-next"
                        enabled: webView.canGoForward
                        display: PlasmaComponents.ToolButton.IconOnly
                        PlasmaComponents.ToolTip.text: i18n("Forward")
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                        PlasmaComponents.ToolTip.visible: hovered
                        onClicked: webView.goForward()
                    }

                    PlasmaComponents.ToolButton {
                        icon.name: "go-home"
                        display: PlasmaComponents.ToolButton.IconOnly
                        PlasmaComponents.ToolTip.text: i18n("Home")
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                        PlasmaComponents.ToolTip.visible: hovered
                        onClicked: webView.url = plasmoid.configuration.homePage
                    }

                    // Bookmarks panel toggle
                    PlasmaComponents.ToolButton {
                        icon.name: "bookmarks-organize"
                        checkable: true
                        checked: root.bkPanelOpen
                        display: PlasmaComponents.ToolButton.IconOnly
                        PlasmaComponents.ToolTip.text: i18n("Bookmarks")
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                        PlasmaComponents.ToolTip.visible: hovered
                        onToggled: root.bkPanelOpen = checked
                    }

                    Item { Layout.fillWidth: true }

                    // Reload / Stop
                    PlasmaComponents.ToolButton {
                        icon.name: webView.loading ? "process-stop" : "view-refresh"
                        display: PlasmaComponents.ToolButton.IconOnly
                        PlasmaComponents.ToolTip.text: webView.loading ? i18n("Stop") : i18n("Reload")
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                        PlasmaComponents.ToolTip.visible: hovered
                        onClicked: webView.loading ? webView.stop() : webView.reload()
                    }

                    // Developer inspector toggle
                    PlasmaComponents.ToolButton {
                        icon.name: "format-text-code"
                        checkable: true
                        checked: inspector.enabled
                        visible: Qt.application.arguments[0] === "plasmoidviewer" || plasmoid.configuration.debugConsole
                        enabled: visible
                        display: PlasmaComponents.ToolButton.IconOnly
                        PlasmaComponents.ToolTip.text: i18n("Developer Tools")
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                        PlasmaComponents.ToolTip.visible: hovered
                        onToggled: {
                            inspector.visible = !inspector.visible
                            inspector.enabled = inspector.visible
                        }
                    }

                    // Pin / keep-open toggle
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

                // Row 2 — address bar (visible when showUrlBar is enabled)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    visible: plasmoid.configuration.showUrlBar

                    PlasmaComponents.TextField {
                        id: urlBar
                        Layout.fillWidth: true
                        placeholderText: i18n("Enter URL…")
                        text: webView.url

                        onAccepted: {
                            var raw = text.trim()
                            if (raw.length === 0) return
                            if (!raw.startsWith("http://") && !raw.startsWith("https://") && !raw.startsWith("file://"))
                                raw = "https://" + raw
                            webView.url = raw
                        }
                    }

                    // Star — adds/removes current page from bookmarks
                    PlasmaComponents.ToolButton {
                        icon.name: root.isBookmarked(webView.url) ? "bookmarks" : "bookmark-new"
                        display: PlasmaComponents.ToolButton.IconOnly
                        PlasmaComponents.ToolTip.text: root.isBookmarked(webView.url) ? i18n("Remove Bookmark") : i18n("Add Bookmark")
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                        PlasmaComponents.ToolTip.visible: hovered
                        onClicked: root.toggleBookmark(webView.title, webView.url)
                    }
                }
            }
        }

        // ── Main content: bookmarks sidebar + webview ─────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Bookmarks sidebar
            Rectangle {
                id: bkSidebar
                visible: root.bkPanelOpen
                width: visible ? Math.round(180 * PlasmaCore.Units.devicePixelRatio) : 0
                Layout.fillHeight: true
                color: theme.backgroundColor

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Sidebar header
                    Rectangle {
                        Layout.fillWidth: true
                        height: Math.round(Kirigami.Units.gridUnit * 1.6)
                        color: theme.highlightColor

                        PlasmaComponents.Label {
                            anchors.centerIn: parent
                            text: i18n("Bookmarks")
                            color: theme.highlightedTextColor
                            font.bold: true
                        }
                    }

                    // Bookmark list
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: bkColumn.implicitHeight
                        ScrollBar.vertical: ScrollBar {}

                        Column {
                            id: bkColumn
                            width: bkSidebar.width
                            spacing: 0

                            Repeater {
                                model: root.bkList

                                delegate: RowLayout {
                                    width: bkSidebar.width
                                    spacing: 0

                                    PlasmaComponents.ToolButton {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        display: PlasmaComponents.ToolButton.TextOnly

                                        contentItem: PlasmaComponents.Label {
                                            text: modelData.name
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignLeft
                                        }

                                        PlasmaComponents.ToolTip.text: modelData.url
                                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                                        PlasmaComponents.ToolTip.visible: hovered
                                        onClicked: webView.url = modelData.url
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
                    }
                }
            }

            // Thin divider between sidebar and webview
            Rectangle {
                visible: root.bkPanelOpen
                width: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.15
            }

            // Main WebView
            WebEngineView {
                id: webView
                Layout.fillWidth: true
                Layout.fillHeight: true
                focus: true
                url: plasmoid.configuration.homePage

                profile: WebEngineProfile {
                    storageName: "BraveWidget"
                    offTheRecord: false
                    httpCacheType: WebEngineProfile.DiskHttpCache
                    persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
                }

                settings.javascriptCanAccessClipboard: plasmoid.configuration.allowClipboardAccess

                onUrlChanged: {
                    if (plasmoid.configuration.showUrlBar)
                        urlBar.text = webView.url
                }
            }
        }

        // ── Developer Inspector ───────────────────────────────────────────────
        WebEngineView {
            id: inspector
            enabled: false
            visible: false
            Layout.fillWidth: true
            height: fullRep.height / 3
            inspectedView: enabled ? webView : null
        }
    }
}
