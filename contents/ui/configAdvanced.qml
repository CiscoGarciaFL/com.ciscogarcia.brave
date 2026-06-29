import QtQuick 2.3
import QtQuick.Layouts 1.0
import QtQuick.Controls 2.5 as QQC2
import org.kde.kirigami 2.4 as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_debugConsole:          debugConsole.checked
    property alias cfg_userAgent:             userAgentField.text
    property alias cfg_grantMediaPermissions: grantMediaPermissions.checked

    // ── User-Agent ────────────────────────────────────────────────────────

    QQC2.TextField {
        id: userAgentField
        Kirigami.FormData.label: i18n("User-Agent:")
        Layout.fillWidth: true
    }
    QQC2.Label {
        font.pixelSize: 11
        font.italic: true
        text: i18n("Sent to every page. The default spoofs Edge on Linux so sites like Microsoft Teams accept the browser.")
    }
    QQC2.Button {
        text: i18n("Reset to default")
        onClicked: userAgentField.text = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0"
    }

    Item { height: Kirigami.Units.largeSpacing }

    // ── Permissions ───────────────────────────────────────────────────────

    QQC2.CheckBox {
        id: grantMediaPermissions
        text: i18n("Auto-grant camera, microphone, screen-share and notification permissions")
    }
    QQC2.Label {
        font.pixelSize: 11
        font.italic: true
        text: i18n("Required for Teams (and similar apps) to use audio/video calls without permission prompts.")
    }

    Item { height: Kirigami.Units.largeSpacing }

    // ── Developer console ─────────────────────────────────────────────────

    QQC2.CheckBox {
        id: debugConsole
        text: i18n("Show developer console toggle in toolbar")
    }
    QQC2.Label {
        font.pixelSize: 11
        font.italic: true
        text: i18n("Enables the WebEngine inspector panel (always visible in plasmoidviewer).")
    }
}
