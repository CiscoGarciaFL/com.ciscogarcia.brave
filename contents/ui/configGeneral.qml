import QtQuick 2.3
import QtQuick.Layouts 1.0
import QtQuick.Controls 2.5 as QQC2
import org.kde.kirigami 2.4 as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_homePage: homePageField.text
    property alias cfg_showUrlBar: showUrlBar.checked
    property alias cfg_allowClipboardAccess: allowClipboardAccess.checked
    property alias cfg_pin: pinByDefault.checked

    QQC2.TextField {
        id: homePageField
        Kirigami.FormData.label: i18n("Home Page URL:")
        placeholderText: "https://kde.org"
        Layout.fillWidth: true
    }
    QQC2.Label {
        font.pixelSize: 11
        font.italic: true
        text: i18n("This URL loads on widget startup and when you press the Home button.")
    }

    Item { height: Kirigami.Units.largeSpacing }

    QQC2.CheckBox {
        id: showUrlBar
        text: i18n("Show address bar")
    }
    QQC2.Label {
        font.pixelSize: 11
        font.italic: true
        text: i18n("Displays the URL bar and bookmark star below the navigation buttons.")
    }

    Item { height: Kirigami.Units.largeSpacing }

    QQC2.CheckBox {
        id: allowClipboardAccess
        text: i18n("Allow clipboard access")
    }
    QQC2.Label {
        font.pixelSize: 11
        font.italic: true
        text: i18n("Allows web pages to read/write the system clipboard.")
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
