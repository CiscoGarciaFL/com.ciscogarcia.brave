import QtQuick 2.3
import QtQuick.Layouts 1.0
import QtQuick.Controls 2.5 as QQC2
import org.kde.kirigami 2.4 as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_debugConsole: debugConsole.checked

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
