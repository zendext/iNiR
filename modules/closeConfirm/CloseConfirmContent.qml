import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import org.kde.kirigami as Kirigami
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    focus: true

    required property var targetWindow
    signal confirm()
    signal cancel()

    readonly property string appId: targetWindow?.app_id ?? ""
    readonly property string appTitle: targetWindow?.title ?? ""

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.cancel()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.confirm()
            event.accepted = true
        }
    }

    // Scrim
    Rectangle {
        id: bg
        anchors.fill: parent
        color: Appearance.colors.colScrim
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity {
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.cancel()
        }
    }

    // Mascot peering over the dialog edge; drawn first so the card overlaps her
    MascotImage {
        anchors.bottom: dialog.top
        anchors.bottomMargin: -12
        anchors.right: dialog.right
        anchors.rightMargin: 24
        width: 92
        height: 92
        pose: "warning-concerned"
        surface: "dialogs"
    }

    // Dialog using Material WindowDialog
    WindowDialog {
        id: dialog
        anchors.centerIn: parent
        backgroundWidth: 340
        zzzLabel: "CLOSE"
        zzzIndex: "APP"
        zzzGhostText: "CLOSE"
        zzzAccentColor: Appearance.zzz.tertiary
        show: false
        Component.onCompleted: show = true

        // App icon row
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Kirigami.Icon {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                source: root.appId
                fallback: "application-x-executable"
                roundToIconSize: false
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                WindowDialogTitle {
                    Layout.fillWidth: true
                    text: Translation.tr("Close this window?")
                }

                // App title
                StyledText {
                    Layout.fillWidth: true
                    text: root.appTitle || root.appId || Translation.tr("Unknown")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.colors.colOnSurface
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    elide: Text.ElideMiddle
                    maximumLineCount: 1
                }

                // App ID (if different)
                StyledText {
                    Layout.fillWidth: true
                    text: root.appId
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.zzzEverywhere ? Appearance.zzz.ghostInk : Appearance.colors.colSubtext
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    visible: root.appId !== "" && root.appId !== root.appTitle
                    elide: Text.ElideMiddle
                }
            }
        }

        // Buttons
        WindowDialogButtonRow {
            Item { Layout.fillWidth: true }

            DialogButton {
                buttonText: Translation.tr("Cancel")
                onClicked: root.cancel()
            }

            DialogButton {
                buttonText: Translation.tr("Close")
                colText: Appearance.colors.colError
                colEnabled: Appearance.colors.colError
                onClicked: root.confirm()
            }
        }
    }
}
