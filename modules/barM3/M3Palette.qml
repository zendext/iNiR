pragma Singleton

import QtQuick
import qs.modules.common
import qs.modules.common.functions

QtObject {
    readonly property bool angelStyle: Appearance.angelEverywhere
    readonly property bool inirStyle: Appearance.inirEverywhere
    readonly property bool auroraStyle: Appearance.auroraEverywhere && !angelStyle
    readonly property bool neutralDialect: angelStyle || inirStyle || auroraStyle

    readonly property color surface: angelStyle ? Appearance.angel.colGlassPanel
        : inirStyle ? Appearance.inir.colLayer0
        : auroraStyle ? Appearance.aurora.colOverlay
        : Appearance.colors.colLayer0
    readonly property color surfaceContainerLow: angelStyle ? Appearance.angel.colGlassCard
        : inirStyle ? Appearance.inir.colLayer1
        : auroraStyle ? Appearance.aurora.colSubSurface
        : Appearance.colors.colSurfaceContainerLow
    readonly property color surfaceContainer: angelStyle ? Appearance.angel.colGlassCard
        : inirStyle ? Appearance.inir.colLayer2
        : auroraStyle ? Appearance.aurora.colSubSurface
        : Appearance.colors.colSurfaceContainer
    readonly property color surfaceContainerHigh: angelStyle ? Appearance.angel.colGlassElevated
        : inirStyle ? Appearance.inir.colLayer3
        : auroraStyle ? Appearance.aurora.colElevatedSurface
        : Appearance.colors.colSurfaceContainerHigh
    readonly property color surfaceContainerHighest: surfaceContainerHigh
    readonly property color onSurface: angelStyle ? Appearance.angel.colText
        : inirStyle ? Appearance.inir.colText
        : Appearance.colors.colOnSurface
    readonly property color onSurfaceVariant: angelStyle ? Appearance.angel.colTextSecondary
        : inirStyle ? Appearance.inir.colTextSecondary
        : Appearance.colors.colOnSurfaceVariant
    readonly property color outlineVariant: angelStyle ? Appearance.angel.colCardBorder
        : inirStyle ? Appearance.inir.colBorder
        : auroraStyle ? Appearance.aurora.colTooltipBorder
        : Appearance.colors.colOutlineVariant
    readonly property color primary: Appearance.colors.colPrimary
    readonly property color onPrimary: Appearance.colors.colOnPrimary
    readonly property color primaryContainer: neutralDialect ? surfaceContainerLow : Appearance.colors.colPrimaryContainer
    readonly property color onPrimaryContainer: neutralDialect ? onSurface : Appearance.colors.colOnPrimaryContainer
    readonly property color secondaryContainer: neutralDialect ? surfaceContainer : Appearance.colors.colSecondaryContainer
    readonly property color onSecondaryContainer: neutralDialect ? onSurface : Appearance.colors.colOnSecondaryContainer
    readonly property color tertiary: Appearance.colors.colTertiary
    readonly property color tertiaryContainer: neutralDialect ? surfaceContainerHigh : Appearance.colors.colTertiaryContainer
    readonly property color onTertiary: Appearance.colors.colOnTertiary
    readonly property color onTertiaryContainer: neutralDialect ? onSurface : Appearance.colors.colOnTertiaryContainer
    readonly property color tooltip: Appearance.colors.colTooltip
    readonly property color onTooltip: Appearance.colors.colOnTooltip
    readonly property color error: Appearance.colors.colError
    readonly property color onError: Appearance.colors.colOnError

    function pillContainer(name: string): color {
        if ((Config.options?.bar?.m3?.cornerStyle ?? 0) !== 3)
            return primaryContainer

        if (neutralDialect) {
            switch (name) {
            case "media":
            case "sysTray":
                return secondaryContainer
            case "resources":
                return tertiaryContainer
            default:
                return primaryContainer
            }
        }

        switch (name) {
        case "media":
        case "sysTray":
            return secondaryContainer
        case "resources":
            return tertiaryContainer
        case "systemIcons":
            return primary
        default:
            return primaryContainer
        }
    }

    function pillInk(name: string): color {
        if ((Config.options?.bar?.m3?.cornerStyle ?? 0) !== 3)
            return onPrimaryContainer

        if (neutralDialect)
            return ColorUtils.ensureReadable(onSurface, pillContainer(name), 4.5)

        switch (name) {
        case "media":
        case "sysTray":
            return ColorUtils.ensureReadable(onSecondaryContainer, pillContainer(name), 4.5)
        case "resources":
            return ColorUtils.ensureReadable(onTertiaryContainer, pillContainer(name), 4.5)
        case "systemIcons":
            return ColorUtils.ensureReadable(onPrimary, pillContainer(name), 4.5)
        default:
            return ColorUtils.ensureReadable(onPrimaryContainer, pillContainer(name), 4.5)
        }
    }
}
