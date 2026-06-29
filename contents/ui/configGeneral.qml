import QtQuick 2.3
import QtQuick.Layouts 1.0
import QtQuick.Controls 2.5 as QQC2
import org.kde.kirigami 2.4 as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_homePage: appUrlField.text
    property alias cfg_pin: pinByDefault.checked

    QQC2.TextField {
        id: appUrlField
        Kirigami.FormData.label: i18n("App URL:")
        placeholderText: "https://teams.microsoft.com"
        Layout.fillWidth: true
    }
    QQC2.Label {
        font.pixelSize: 11
        font.italic: true
        text: i18n("Brave opens this URL in app mode (no tabs, no address bar).")
    }

    Item { height: Kirigami.Units.largeSpacing }

    QQC2.CheckBox {
        id: pinByDefault
        text: i18n("Pin widget open by default")
    }
    QQC2.Label {
        font.pixelSize: 11
        font.italic: true
        text: i18n("When enabled the widget stays open after losing focus.")
    }
}
