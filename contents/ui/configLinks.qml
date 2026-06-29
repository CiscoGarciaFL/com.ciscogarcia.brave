import QtQuick 2.3
import QtQuick.Layouts 1.0
import QtQuick.Controls 2.5 as QQC2
import org.kde.kirigami 2.4 as Kirigami

Kirigami.FormLayout {
    id: page

    property string cfg_bookmarks: "[]"
    property var _list: []

    Component.onCompleted: _parse()

    function _parse() {
        try {
            _list = (cfg_bookmarks && cfg_bookmarks.length > 2) ? JSON.parse(cfg_bookmarks) : []
        } catch(e) {
            _list = []
        }
    }

    function _flush() {
        cfg_bookmarks = JSON.stringify(_list)
    }

    function _add() {
        var name = nameField.text.trim()
        var url  = urlField.text.trim()
        if (name.length === 0 || url.length === 0) return
        if (!url.startsWith("http://") && !url.startsWith("https://") && !url.startsWith("file://"))
            url = "https://" + url
        var list = JSON.parse(JSON.stringify(_list))
        list.push({ name: name, url: url })
        _list = list
        _flush()
        nameField.text = ""
        urlField.text  = ""
    }

    function _remove(idx) {
        var list = JSON.parse(JSON.stringify(_list))
        list.splice(idx, 1)
        _list = list
        _flush()
    }

    // ── Add a bookmark ────────────────────────────────────────────────────

    Kirigami.Separator { Layout.fillWidth: true }

    QQC2.Label {
        font.bold: true
        text: i18n("Add Link")
    }

    QQC2.TextField {
        id: nameField
        Kirigami.FormData.label: i18n("Name:")
        placeholderText: i18n("e.g. KDE Homepage")
        Layout.fillWidth: true
        onAccepted: urlField.forceActiveFocus()
    }

    QQC2.TextField {
        id: urlField
        Kirigami.FormData.label: i18n("URL:")
        placeholderText: "https://kde.org"
        Layout.fillWidth: true
        onAccepted: page._add()
    }

    QQC2.Button {
        text: i18n("Add to Bookmarks")
        icon.name: "bookmark-new"
        enabled: nameField.text.trim().length > 0 && urlField.text.trim().length > 0
        onClicked: page._add()
    }

    // ── Saved links ───────────────────────────────────────────────────────

    Item { height: Kirigami.Units.largeSpacing }
    Kirigami.Separator { Layout.fillWidth: true }

    QQC2.Label {
        font.bold: true
        text: i18n("Saved Links")
    }

    QQC2.Label {
        visible: _list.length === 0
        font.italic: true
        text: i18n("No bookmarks yet. Add one above.")
    }

    Repeater {
        model: _list

        delegate: RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                QQC2.Label {
                    Layout.fillWidth: true
                    text: modelData.name
                    elide: Text.ElideRight
                    font.bold: true
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: modelData.url
                    elide: Text.ElideRight
                    font.pixelSize: 10
                    opacity: 0.7
                }
            }

            QQC2.Button {
                icon.name: "edit-delete-remove"
                text: i18n("Remove")
                display: QQC2.AbstractButton.IconOnly
                onClicked: page._remove(index)
            }
        }
    }
}
