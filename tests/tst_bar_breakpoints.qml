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
            { tag: "workspace on compact display", moduleId: "workspaces", width: 1728, expected: true },
            { tag: "unknown width", moduleId: "media", width: 0, expected: true }
        ]
    }

    function test_moduleAllowedAtWidth(data) {
        compare(BarBreakpoints.moduleAllowedAtWidth(data.moduleId, data.width), data.expected)
    }
}
