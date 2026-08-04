pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs
import qs.modules.common
import qs.services

Scope {
    id: root
    readonly property var focusedScreen: CompositorService.isNiri
        ? (Quickshell.screens.find(s => s.name === NiriService.currentOutput) ?? GlobalStates.primaryScreen)
        : (Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? GlobalStates.primaryScreen)
    readonly property string focusedMonitorName: focusedScreen?.name ?? ""
    readonly property var defaultScreen: focusedScreen ?? GlobalStates.primaryScreen
    readonly property string defaultMonitorName: defaultScreen?.name ?? focusedMonitorName
    property bool _pendingCoverflow: false

    Process {
        id: niriOutputDetector
        property string _buffer: ""
        stdout: SplitParser { onRead: data => niriOutputDetector._buffer += data + "\n" }
        onExited: (code, status) => {
            let monitorName = ""
            if (code === 0 && niriOutputDetector._buffer) {
                try { monitorName = JSON.parse(niriOutputDetector._buffer).name || "" }
                catch (error) {}
            }
            niriOutputDetector._buffer = ""
            if (!monitorName) monitorName = root.focusedMonitorName
            if (root._pendingCoverflow) {
                root._pendingCoverflow = false
                root._toggleCoverflowWithMonitor(monitorName)
            } else root._openWithMonitor(monitorName)
        }
    }

    function _openWithMonitor(monitorName: string): void {
        GlobalStates.wallpaperSelectorTargetMonitor = monitorName || ""
        Config.setNestedValue("wallpaperSelector.targetMonitor", monitorName || "")
        GlobalStates.wallpaperSelectorOpen = true
    }

    function _toggleCoverflowWithMonitor(monitorName: string): void {
        Config.setNestedValue("wallpaperSelector.targetMonitor", monitorName || "")
        GlobalStates.wallpaperSelectorOpen = false
        GlobalStates.coverflowSelectorOpen = !GlobalStates.coverflowSelectorOpen
    }

    function toggle(): void {
        if (GlobalStates.wallpaperLauncherOpen) {
            GlobalStates.wallpaperLauncherOpen = false
            return
        }
        if (Config.options?.wallpaperSelector?.useSystemFileDialog ?? false) {
            Wallpapers.openFallbackPicker(Appearance.m3colors.darkmode)
            return
        }
        const selectorStyle = Config.options?.wallpaperSelector?.style ?? "grid"
        if (selectorStyle === "launcher") {
            root._openLauncher("", "")
            return
        }
        if (selectorStyle === "coverflow") {
            GlobalStates.wallpaperSelectorOpen = false
            const multiMonitor = Config.options?.background?.multiMonitor?.enable ?? false
            const explicitMonitor = Config.options?.wallpaperSelector?.targetMonitor ?? ""
            if (!explicitMonitor && multiMonitor
                    && CompositorService.isNiri && !niriOutputDetector.running) {
                root._pendingCoverflow = true
                niriOutputDetector.exec(["niri", "msg", "-j", "focused-output"])
                return
            }
            root._toggleCoverflowWithMonitor(explicitMonitor || (multiMonitor ? root.defaultMonitorName : ""))
            return
        }
        GlobalStates.coverflowSelectorOpen = false
        if (GlobalStates.wallpaperSelectorOpen) {
            GlobalStates.wallpaperSelectorOpen = false
            return
        }
        const explicitMonitor = Config.options?.wallpaperSelector?.targetMonitor ?? ""
        const explicitTarget = Config.options?.wallpaperSelector?.selectionTarget ?? "main"
        if (!explicitMonitor && explicitTarget === "main") {
            if (Config.options?.panelFamily === "waffle") {
                const useMain = Config.options?.waffles?.background?.useMainWallpaper ?? true
                Config.setNestedValue("wallpaperSelector.selectionTarget", useMain ? "main" : "waffle")
            } else Config.setNestedValue("wallpaperSelector.selectionTarget", "main")
            if (Config.options?.background?.multiMonitor?.enable ?? false) {
                if (CompositorService.isNiri && !niriOutputDetector.running) {
                    niriOutputDetector.exec(["niri", "msg", "-j", "focused-output"])
                    return
                }
                root._openWithMonitor(root.defaultMonitorName)
                return
            }
        } else if (explicitMonitor) GlobalStates.wallpaperSelectorTargetMonitor = explicitMonitor
        GlobalStates.wallpaperSelectorOpen = true
    }

    // An empty mode means "match what is on screen": opening the picker while a
    // video wallpaper is applied must land on Animated, not on Static where the
    // current wallpaper cannot even appear.
    function _resolveLauncherMode(mode: string): string {
        if (mode === "animated" || mode === "static")
            return mode
        const currentPath = Wallpapers.currentWallpaperPathForTarget(
            Wallpapers.currentSelectionTarget(),
            (Config.options?.background?.multiMonitor?.enable ?? false)
                ? (Config.options?.wallpaperSelector?.targetMonitor ?? "") : "")
        return WallpaperListener.isAnimatedPath(currentPath) ? "animated" : "static"
    }

    function _openLauncher(mode: string, requestedMonitor: string): void {
        const nextMode = root._resolveLauncherMode(mode)
        GlobalStates.wallpaperSelectorOpen = false
        GlobalStates.coverflowSelectorOpen = false
        // Opening the launcher makes it the active picker, so the wallpaper
        // shortcut keeps opening it instead of falling back to the grid.
        // The grid button inside the launcher is the way back out.
        Config.setNestedValue("wallpaperSelector.style", "launcher")
        GlobalStates.wallpaperLauncherMode = nextMode
        const configuredMonitor = Config.options?.wallpaperSelector?.targetMonitor ?? ""
        const monitorName = requestedMonitor || configuredMonitor
            || ((Config.options?.background?.multiMonitor?.enable ?? false)
                ? root.defaultMonitorName : "")
        const target = Wallpapers.currentSelectionTarget()
        GlobalStates.wallpaperSelectionTarget = target
        Config.setNestedValue("wallpaperSelector.selectionTarget", target)
        GlobalStates.wallpaperSelectorTargetMonitor = monitorName
        Config.setNestedValue("wallpaperSelector.targetMonitor", monitorName)
        GlobalStates.wallpaperLauncherOpen = true
    }

    function openLauncher(mode: string): void {
        root._openLauncher(mode, "")
    }

    IpcHandler {
        target: "wallpaperSelector"
        function toggle(): void { root.toggle() }
        function open(): void {
            if (!GlobalStates.wallpaperSelectorOpen
                    && !GlobalStates.wallpaperLauncherOpen
                    && !GlobalStates.coverflowSelectorOpen)
                root.toggle()
        }
        function close(): void {
            GlobalStates.wallpaperSelectorOpen = false
            GlobalStates.wallpaperLauncherOpen = false
        }
        function openLauncher(mode: string): void { root.openLauncher(mode) }
        function toggleOnMonitor(monitorName: string): void {
            if ((Config.options?.wallpaperSelector?.style ?? "grid") === "launcher") {
                root._openLauncher("", monitorName)
                return
            }
            if (monitorName) {
                GlobalStates.wallpaperSelectorTargetMonitor = monitorName
                Config.setNestedValue("wallpaperSelector.targetMonitor", monitorName)
            }
            root.toggle()
        }
        function random(): void { Wallpapers.randomFromCurrentFolder() }
    }

    IpcHandler {
        target: "coverflowSelector"
        function toggle(): void { GlobalStates.coverflowSelectorOpen = !GlobalStates.coverflowSelectorOpen }
        function open(): void { GlobalStates.coverflowSelectorOpen = true }
        function close(): void { GlobalStates.coverflowSelectorOpen = false }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut { name: "wallpaperSelectorToggle"; description: "Toggle wallpaper selector"; onPressed: root.toggle() }
            GlobalShortcut { name: "wallpaperSelectorRandom"; description: "Select random wallpaper in current folder"; onPressed: Wallpapers.randomFromCurrentFolder() }
            GlobalShortcut { name: "coverflowSelectorToggle"; description: "Toggle coverflow wallpaper selector"; onPressed: GlobalStates.coverflowSelectorOpen = !GlobalStates.coverflowSelectorOpen }
        }
    }
}
