pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

Singleton {
    id: root

    readonly property bool enabled: Config.options?.sidebar?.screenTime?.enable ?? false
    property bool ready: false

    property var _todayData: null
    property string _currentAppId: ""
    property string _currentAppName: ""
    property real _lastTickTime: 0
    property string _currentDate: ""
    property bool _dirty: false
    property bool _startupLock: true
    property var _rangeCache: ({})

    readonly property var todayData: _todayData
    readonly property string currentAppId: _currentAppId
    readonly property string currentAppName: _currentAppName

    signal dataChanged()
    signal rangeLoaded(int days, var data)

    Component.onCompleted: {
        if (!root.enabled) {
            root.ready = true
            return
        }
        _currentDate = _dateString(new Date())
        _loadTodayFromFile()
    }

    Connections {
        target: Config
        function onConfigChanged() {
            if (root.enabled && !root.ready) {
                _currentDate = _dateString(new Date())
                _loadTodayFromFile()
            }
        }
    }

    function _loadTodayFromFile(): void {
        const path = _todayFilePath()
        startupReadProc.command = ["/usr/bin/bash", "-c", `test -f "${path}" && cat "${path}" || echo "__NOFILE__"`]
        startupReadProc.running = true
    }

    Timer {
        id: pollTimer
        interval: (Config.options?.sidebar?.screenTime?.pollIntervalSeconds ?? 5) * 1000
        running: root.enabled && root.ready
        repeat: true
        triggeredOnStart: true
        onTriggered: root._tick()
    }

    Timer {
        id: dayRolloverTimer
        interval: 60000
        running: root.enabled && root.ready
        repeat: true
        onTriggered: {
            const now = root._dateString(new Date())
            if (now !== root._currentDate) {
                root._persistToday()
                root._currentDate = now
                root._todayData = root._emptyDay(now)
                root._currentAppId = ""
                root._currentAppName = ""
                root._lastTickTime = Date.now()
                root._rangeCache = ({})
                root.dataChanged()
            }
        }
    }

    function _tick(): void {
        if (!root.enabled) return

        const now = Date.now()
        let appId = ""
        let appName = ""

        if (CompositorService.isNiri) {
            const win = NiriService.activeWindow
            if (win) {
                appId = win.app_id || ""
                appName = appId ? _humanizeAppId(appId) : ""
            }
        } else if (CompositorService.isHyprland) {
            const wins = HyprlandData.windowList || []
            for (let i = 0; i < wins.length; i++) {
                if (wins[i].focusHistoryID === 0) {
                    appId = wins[i].class || ""
                    appName = appId ? _humanizeAppId(appId) : ""
                    break
                }
            }
        }

        const elapsed = root._lastTickTime > 0
            ? Math.round((now - root._lastTickTime) / 1000)
            : 0
        root._lastTickTime = now

        if (elapsed <= 0 || elapsed > 60) {
            root._currentAppId = appId
            root._currentAppName = appName
            return
        }

        if (!root._todayData)
            root._todayData = _emptyDay(root._currentDate)

        if (appId.length > 0) {
            root._todayData.totalSeconds += elapsed
            const hour = new Date().getHours()
            root._todayData.hourly[hour] = (root._todayData.hourly[hour] || 0) + elapsed

            const key = appId.toLowerCase().replace(/[^a-z0-9-]/g, "")
            if (!root._todayData.apps[key])
                root._todayData.apps[key] = { name: appName, seconds: 0, originalId: appId }
            if (!root._todayData.apps[key].originalId)
                root._todayData.apps[key].originalId = appId
            root._todayData.apps[key].seconds += elapsed
            root._dirty = true
        }

        root._currentAppId = appId
        root._currentAppName = appName
        root._todayData = Object.assign({}, root._todayData)
        root._rangeCache = ({})
        root.dataChanged()

        if (root._dirty && root._todayData.totalSeconds % 60 < elapsed) {
            root._persistToday()
            root._dirty = false
        }
    }

    function getToday(): var {
        return root._todayData || _emptyDay(root._currentDate)
    }

    function requestDays(count: int): void {
        if (count <= 1) {
            root.rangeLoaded(1, getToday())
            return
        }
        let script = ""
        const now = new Date()
        for (let i = 1; i < count; i++) {
            const d = new Date(now)
            d.setDate(d.getDate() - i)
            const path = `${Directories.screenTimePath}/${_dateString(d)}.json`
            script += `cat "${path}" 2>/dev/null || echo "{}"; echo "---DELIM---";\n`
        }
        rangeReadProc._requestedDays = count
        rangeReadProc.command = ["/usr/bin/bash", "-c", script]
        rangeReadProc.running = true
    }

    function getCachedDays(count: int): var {
        return root._rangeCache[count] || null
    }

    function getAppList(days: int): var {
        const data = days <= 1 ? getToday() : (root._rangeCache[days] || getToday())
        const apps = data.apps || {}
        const list = []
        const keys = Object.keys(apps)
        for (let i = 0; i < keys.length; i++) {
            const key = keys[i]
            list.push({ id: key, name: apps[key].name || key, seconds: apps[key].seconds || 0, originalId: apps[key].originalId || key })
        }
        list.sort((a, b) => b.seconds - a.seconds)
        return list
    }

    function formatDuration(totalSeconds: int): string {
        if (totalSeconds < 60) return totalSeconds + "s"
        const hours = Math.floor(totalSeconds / 3600)
        const mins = Math.floor((totalSeconds % 3600) / 60)
        if (hours > 0) return hours + "h " + mins + "m"
        return mins + "m"
    }

    readonly property var _iconOverrides: ({
        "code": "visual-studio-code",
        "code - oss": "visual-studio-code",
        "code-oss": "visual-studio-code",
        "orgquickshell": "org.quickshell",
        "quickshell": "org.quickshell",
        "quicksilver": "org.quickshell",
        "zen": "zen-browser"
    })

    function resolveAppIcon(app: var): string {
        return AppSearch.resolveIcon(resolveAppIconName(app), "application-x-executable")
    }

    function resolveAppIconName(app: var): string {
        const originalId = app.originalId || ""
        const key = app.id || ""
        const name = app.name || ""

        if (originalId && _iconOverrides[originalId.toLowerCase()])
            return _iconOverrides[originalId.toLowerCase()]
        const keyLower = key.toLowerCase()
        if (_iconOverrides[keyLower]) return _iconOverrides[keyLower]
        const nameLower = name.toLowerCase().replace(/ /g, "-")
        if (_iconOverrides[nameLower]) return _iconOverrides[nameLower]

        if (originalId) return originalId
        if (nameLower && nameLower !== key) return nameLower
        return key || "application-x-executable"
    }

    function _emptyDay(dateStr: string): var {
        return { date: dateStr, totalSeconds: 0, hourly: new Array(24).fill(0), apps: {} }
    }

    function _humanizeAppId(id: string): string {
        const parts = id.split(".")
        const name = parts.length > 1 ? parts[parts.length - 1] : id
        return name.replace(/[-_]/g, " ").replace(/\b\w/g, function(c) { return c.toUpperCase() }).trim()
    }

    function _dateString(d: var): string {
        const y = d.getFullYear()
        const m = String(d.getMonth() + 1).padStart(2, "0")
        const day = String(d.getDate()).padStart(2, "0")
        return `${y}-${m}-${day}`
    }

    function _todayFilePath(): string {
        return `${Directories.screenTimePath}/${root._currentDate}.json`
    }

    function _persistToday(): void {
        if (!root._todayData) return
        const url = Qt.resolvedUrl(_todayFilePath())
        if (todayFileView.path !== url)
            todayFileView.path = url
        todayFileView.setText(JSON.stringify(root._todayData, null, 2))
    }

    function _mergeDays(todayData: var, rawText: string): var {
        const result = {
            totalSeconds: todayData.totalSeconds || 0,
            hourly: (todayData.hourly || []).slice(),
            apps: {}
        }
        if (!result.hourly.length) result.hourly = new Array(24).fill(0)

        const todayApps = todayData.apps || {}
        const todayKeys = Object.keys(todayApps)
        for (let i = 0; i < todayKeys.length; i++) {
            const key = todayKeys[i]
            result.apps[key] = { name: todayApps[key].name, seconds: todayApps[key].seconds, originalId: todayApps[key].originalId || key }
        }

        const sections = rawText.split("---DELIM---").filter(s => s.trim().length > 0 && s.trim() !== "{}")
        for (let i = 0; i < sections.length; i++) {
            try {
                const dayData = JSON.parse(sections[i].trim())
                if (!dayData || !dayData.totalSeconds) continue
                result.totalSeconds += dayData.totalSeconds || 0
                if (dayData.hourly) {
                    for (let h = 0; h < 24; h++)
                        result.hourly[h] = (result.hourly[h] || 0) + (dayData.hourly[h] || 0)
                }
                if (dayData.apps) {
                    const keys = Object.keys(dayData.apps)
                    for (let k = 0; k < keys.length; k++) {
                        const key = keys[k]
                        if (!result.apps[key])
                            result.apps[key] = { name: dayData.apps[key].name || key, seconds: 0 }
                        result.apps[key].seconds += dayData.apps[key].seconds || 0
                    }
                }
            } catch (e) {}
        }
        return result
    }

    FileView {
        id: todayFileView
        path: ""
    }

    Process {
        id: startupReadProc
        command: ["/usr/bin/bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "__NOFILE__" || text.trim().length === 0) {
                    root._todayData = root._emptyDay(root._currentDate)
                } else {
                    try {
                        root._todayData = JSON.parse(text.trim())
                    } catch (e) {
                        root._todayData = root._emptyDay(root._currentDate)
                    }
                }
                root._dirty = false
                root._lastTickTime = Date.now()
                root.ready = true
                root._startupLock = false
                root.dataChanged()
            }
        }
    }

    Process {
        id: rangeReadProc
        property int _requestedDays: 1
        command: ["/usr/bin/bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const merged = root._mergeDays(root.getToday(), text)
                const cache = {}
                cache[rangeReadProc._requestedDays] = merged
                root._rangeCache = Object.assign({}, root._rangeCache, cache)
                root.rangeLoaded(rangeReadProc._requestedDays, merged)
            }
        }
    }
}
