/*
 * SPDX-FileCopyrightText: 2024 CiscoGarciaFL <me@ciscogarcia.com>
 * SPDX-License-Identifier: GPL-3.0-or-later
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

        // ── Row 1: Navigation buttons ────────────────────────────────────────
        PlasmaExtras.PlasmoidHeading {
            Layout.fillWidth: true

            ColumnLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

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

                // ── Row 2: Address bar ───────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.TextField {
                        id: urlBar
                        Layout.fillWidth: true
                        placeholderText: i18n("Enter URL…")
                        text: webView.url

                        onAccepted: {
                            var raw = text.trim()
                            if (raw.length === 0) return
                            if (!raw.startsWith("http://") && !raw.startsWith("https://") && !raw.startsWith("file://")) {
                                raw = "https://" + raw
                            }
                            webView.url = raw
                        }
                    }
                }
            }
        }

        // ── Main WebView ─────────────────────────────────────────────────────
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

            onUrlChanged: urlBar.text = webView.url
        }

        // ── Developer Inspector ──────────────────────────────────────────────
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
