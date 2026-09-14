import QtQuick
import QtTest
import "../modules/bar/BarBreakpoints.js" as BarBreakpoints

TestCase {
    name: "BarBreakpoints"

    function test_moduleAllowedAtWidth_data() {
        return [
            { tag: "media below breakpoint", moduleId: "media", width: 1728, expected: false },
            { tag: "weather at breakpoint", moduleId: "weather", width: 1800, expected: false },
            { tag: "media above breakpoint", moduleId: "media", width: 1801, expected: true },
            { tag: "weather on main display", moduleId: "weather", width: 2304, expected: true },
            { tag: "clock on compact display", moduleId: "clock", width: 1728, expected: false },
            { tag: "clock at breakpoint", moduleId: "clock", width: 1800, expected: false },
            { tag: "clock above breakpoint", moduleId: "clock", width: 1801, expected: true },
            { tag: "clock on main display", moduleId: "clock", width: 2304, expected: true },
            { tag: "utility buttons on compact display", moduleId: "utilButtons", width: 1728, expected: false },
            { tag: "utility buttons at breakpoint", moduleId: "utilButtons", width: 1800, expected: false },
            { tag: "utility buttons above breakpoint", moduleId: "utilButtons", width: 1801, expected: true },
            { tag: "utility buttons on main display", moduleId: "utilButtons", width: 2304, expected: true },
            { tag: "tray on compact display", moduleId: "tray", width: 1728, expected: true },
            { tag: "battery on compact display", moduleId: "battery", width: 1728, expected: false },
            { tag: "battery at breakpoint", moduleId: "battery", width: 1800, expected: false },
            { tag: "battery above breakpoint", moduleId: "battery", width: 1801, expected: true },
            { tag: "battery on main display", moduleId: "battery", width: 2304, expected: true },
            { tag: "workspace on compact display", moduleId: "workspaces", width: 1728, expected: true },
            { tag: "unknown width", moduleId: "media", width: 0, expected: true }
        ]
    }

    function test_moduleAllowedAtWidth(data) {
        compare(BarBreakpoints.moduleAllowedAtWidth(data.moduleId, data.width), data.expected)
    }
}
