import QtQuick 2.3
import QtQuick.Layouts 1.0
import QtQuick.Controls 2.5 as QQC2
import org.kde.kirigami 2.4 as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_bravePath: bravePathField.text
    property alias cfg_hideDecorations: hideDecorationsCheck.checked

    QQC2.CheckBox {
        id: hideDecorationsCheck
        text: i18n("Hide window title bar")
    }
    QQC2.Label {
        font.pixelSize: 11
        font.italic: true
        text: i18n("Removes the title bar from the embedded Brave window. Use the 'Close Window' button in the widget to close it.")
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
}
