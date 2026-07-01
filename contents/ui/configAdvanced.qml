import QtQuick 2.3
import QtQuick.Layouts 1.0
import QtQuick.Controls 2.5 as QQC2
import org.kde.kirigami 2.4 as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_bravePath: bravePathField.text
    property alias cfg_hideDecorations: hideDecorationsCheck.checked
    property alias cfg_showAddressBar: showAddressBarCheck.checked

    QQC2.CheckBox {
        id: showAddressBarCheck
        text: i18n("Show address bar after embedding")
    }
    QQC2.Label {
        font.pixelSize: 11
        font.italic: true
        text: i18n("When unchecked, clicking Embed will position Brave over the full widget area. The cover/reveal icon in the address bar toggles this setting; click Embed to apply.")
    }

    Item { height: Kirigami.Units.largeSpacing }

    QQC2.CheckBox {
        id: hideDecorationsCheck
        text: i18n("Hide window title bar by default")
    }
    QQC2.Label {
        font.pixelSize: 11
        font.italic: true
        text: i18n("Removes the title bar from the embedded Brave window. The title-bar icon in the address bar toggles this setting; click Embed to apply.")
    }

    Item { height: Kirigami.Units.largeSpacing }

    QQC2.TextField {
        id: bravePathField
        Kirigami.FormData.label: i18n("Brave executable:")
        placeholderText: "/snap/bin/brave"
        Layout.fillWidth: true
    }
    QQC2.Label {
        font.pixelSize: 11
        font.italic: true
        text: i18n("Command or full path used to launch Brave. Common values: brave-browser, brave, /usr/bin/brave-browser")
    }
    QQC2.Button {
        text: i18n("Reset to default")
        onClicked: bravePathField.text = "/snap/bin/brave"
    }

    Item { height: Kirigami.Units.largeSpacing }

    QQC2.Label {
        font.pixelSize: 11
        font.italic: true
        text: i18n("Tip: You can also close the embedded Brave window with Alt+F4 while it is focused.")
    }
}
