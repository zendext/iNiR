pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: button
    property string day
    property int isToday
    property bool bold
    property bool isHeader: false
    property int eventCount: 0
    // Source colors for multi-colored dots (from CalendarSync + local events)
    property var sourceColors: []
    property string subLabel: ""
    property string statusLabel: ""
    property color statusColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property bool hasSubLabel: subLabel.length > 0 && !isHeader
    readonly property bool hasStatusLabel: statusLabel.length > 0 && !isHeader

    Layout.fillWidth: false
    Layout.fillHeight: false
    implicitWidth: 38
    implicitHeight: 38

    toggled: (isToday == 1) && !isHeader
    buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small

    contentItem: Item {
        anchors.fill: parent

        ColumnLayout {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: button.hasSubLabel ? -1 : ((button.eventCount > 0 && !button.isHeader) ? -2 : 0)
            spacing: button.hasSubLabel ? -2 : 0

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: button.day
                horizontalAlignment: Text.AlignHCenter
                font.weight: button.bold ? Font.DemiBold : Font.Normal
                color: button.isHeader && (button.isToday == 1)
                    ? (Appearance.angelEverywhere ? Appearance.angel.colPrimary
                        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                    : (button.isToday == 1)
                        ? (Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                            : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary)
                        : (button.isToday == 0)
                            ? (Appearance.angelEverywhere ? Appearance.angel.colText
                                : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1)
                            : (Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                                : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
                                : Appearance.auroraEverywhere ? Appearance.colors.colSubtext
                                : Appearance.colors.colOutlineVariant)

                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: button.width - 8
                visible: button.hasSubLabel
                text: button.subLabel
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: button.isToday == 1
                    ? (Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                        : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary)
                    : (Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext)
                opacity: button.isToday == 1 ? 0.78 : 0.9
                elide: Text.ElideRight
            }
        }

        StyledText {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.rightMargin: 2
            visible: button.hasStatusLabel
            text: button.statusLabel
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.DemiBold
            color: button.isToday == 1
                ? (Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                    : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary)
                : button.statusColor
        }

        // Multi-colored event indicator dots
        Row {
            scale: (button.eventCount > 0 && !button.isHeader) ? 1 : 0
            visible: scale > 0
            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: button.hasSubLabel ? 1 : 3
            spacing: 2

            Repeater {
                // Show up to 3 dots, one per unique source color
                model: {
                    const colors = button.sourceColors
                    if (!colors || colors.length === 0) {
                        // Fallback: single dot in primary color (local events only)
                        if (button.eventCount > 0) {
                            const primary = button.isToday == 1
                                ? (Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                                    : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary)
                                : (Appearance.angelEverywhere ? Appearance.angel.colPrimary
                                    : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                            return [primary]
                        }
                        return []
                    }
                    return colors.slice(0, 3)
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: 5
                    height: 5
                    radius: 2.5
                    color: modelData

                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                    }
                }
            }

            // Overflow indicator when more than 3 sources
            StyledText {
                opacity: (button.sourceColors?.length ?? 0) > 3 ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                text: "+"
                font.pixelSize: 7
                font.weight: Font.Bold
                color: button.isToday == 1
                    ? (Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                        : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary)
                    : (Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext)
            }
        }
    }
}
