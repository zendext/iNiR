pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property bool enabled: Config.options?.calendar?.china?.enable ?? false
    readonly property string holidayDataDir: `${Directories.cachePath}/calendar/holiday-cn`
    property var holidayDataByYear: ({})
    property var loadedYears: ({})
    property var missingYears: ({})
    property var queuedYears: []
    property int pendingYear: 0
    property bool loading: false
    property string lastError: ""

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log("[CalendarCn]", ...args)
    }

    function formatDateKey(date: var): string {
        const y = date.getFullYear()
        const m = String(date.getMonth() + 1).padStart(2, "0")
        const d = String(date.getDate()).padStart(2, "0")
        return `${y}-${m}-${d}`
    }

    function holidayFilePath(year: int): string {
        return `${holidayDataDir}/${year}.json`
    }

    function normalizeHolidayData(raw: var): var {
        const map = {}
        if (!raw) return map

        if (Array.isArray(raw)) {
            raw.forEach(entry => {
                if (entry && entry.date) map[entry.date] = entry
            })
            return map
        }

        if (raw.days && Array.isArray(raw.days)) {
            raw.days.forEach(entry => {
                if (entry && entry.date) map[entry.date] = entry
            })
            return map
        }

        if (raw.holidays && typeof raw.holidays === "object") {
            Object.keys(raw.holidays).forEach(key => {
                const entry = raw.holidays[key]
                if (entry && typeof entry === "object") map[key] = entry
            })
            return map
        }

        Object.keys(raw).forEach(key => {
            const entry = raw[key]
            if (entry && typeof entry === "object") map[key] = entry
        })

        return map
    }

    function ensureHolidayYear(year: int): void {
        if (!enabled) return
        if (holidayDataByYear[year] || loadedYears[year] || missingYears[year]) return
        if (queuedYears.indexOf(year) !== -1 || pendingYear === year) return

        const queue = queuedYears.slice()
        queue.push(year)
        queuedYears = queue
        _loadNextYear()
    }

    function _loadNextYear(): void {
        if (loading || queuedYears.length === 0) return
        const queue = queuedYears.slice()
        pendingYear = queue.shift()
        queuedYears = queue
        loading = true
        holidayFileView.path = Qt.resolvedUrl(holidayFilePath(pendingYear))
        holidayFileView.reload()
    }

    function getHolidayInfo(date: var): var {
        if (!enabled || !date) return null
        const year = date.getFullYear()
        if (!holidayDataByYear[year]) {
            ensureHolidayYear(year)
            return null
        }
        return holidayDataByYear[year][formatDateKey(date)] || null
    }

    function getLunarInfo(date: var): var {
        if (!(Config.options?.calendar?.china?.showLunar ?? true)) return null
        return LunarUtils.toLunar(date)
    }

    function getWorkStatusType(info: var): string {
        if (!info) return ""
        if (info.isOffDay === true) return "休"
        if (info.isOffDay === false) return "班"
        if (info.holiday === true) return "休"
        return ""
    }

    function getLunarLabel(info: var): string {
        if (!info) return ""
        const monthNames = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
        const dayNames = [
            "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
            "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
            "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
        ]
        const monthLabel = `${info.isLeap ? "闰" : ""}${monthNames[info.month - 1]}月`
        const monthDays = LunarUtils.lunarMonthDays(info.year, info.month, info.isLeap)
        if (!info.isLeap && info.month === 12 && info.day === monthDays) return "除夕"
        if (info.day === 1) return monthLabel
        return dayNames[info.day - 1] || ""
    }

    Component.onCompleted: {
        if (!enabled) return
        const year = new Date().getFullYear()
        ensureHolidayYear(year)
        ensureHolidayYear(year + 1)
    }

    onEnabledChanged: {
        if (!enabled) return
        const year = new Date().getFullYear()
        ensureHolidayYear(year)
        ensureHolidayYear(year + 1)
    }

    FileView {
        id: holidayFileView
        onLoaded: {
            const fileContents = holidayFileView.text()
            try {
                const parsed = JSON.parse(fileContents)
                const updatedData = Object.assign({}, holidayDataByYear)
                updatedData[pendingYear] = normalizeHolidayData(parsed)
                holidayDataByYear = updatedData

                const updatedLoaded = Object.assign({}, loadedYears)
                updatedLoaded[pendingYear] = true
                loadedYears = updatedLoaded
                lastError = ""
                _log("Loaded holiday data for", pendingYear)
            } catch (e) {
                lastError = e.message || "parse error"
                const updatedData = Object.assign({}, holidayDataByYear)
                updatedData[pendingYear] = {}
                holidayDataByYear = updatedData

                const updatedLoaded = Object.assign({}, loadedYears)
                updatedLoaded[pendingYear] = true
                loadedYears = updatedLoaded
                console.warn("[CalendarCn] Failed to parse holiday data for " + pendingYear + ": " + lastError)
            }
            loading = false
            _loadNextYear()
        }
        onLoadFailed: (error) => {
            if (error == FileViewError.FileNotFound) {
                const updatedMissing = Object.assign({}, missingYears)
                updatedMissing[pendingYear] = true
                missingYears = updatedMissing

                const updatedData = Object.assign({}, holidayDataByYear)
                updatedData[pendingYear] = {}
                holidayDataByYear = updatedData
                _log("Holiday file not found for", pendingYear)
            } else {
                lastError = `${error}`
                console.warn("[CalendarCn] Error loading holiday data for " + pendingYear + ": " + error)
            }
            loading = false
            _loadNextYear()
        }
    }
}
