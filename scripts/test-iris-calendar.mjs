#!/usr/bin/env node
// Exercise the shared QML date presentation with real lunar conversion.
// QML parsing and live checks cover layout and asynchronous property bindings.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

function loadFunctions(path, bindings) {
    const source = readFileSync(new URL(path, import.meta.url), 'utf8');
    const context = vm.createContext({ Date, ...bindings });
    context.root = context;
    for (const match of source.matchAll(/function (\w+)\(([^)]*)\)(?:\s*:\s*\w+)?\s*\{/g)) {
        const start = match.index + match[0].length;
        let depth = 1;
        let end = start;
        while (depth && end < source.length) {
            if (source[end] === '{') depth++;
            if (source[end] === '}') depth--;
            end++;
        }
        const args = match[2].replace(/:\s*\w+/g, '');
        vm.runInContext(`function ${match[1]}(${args}) {${source.slice(start, end - 1)}}`, context);
    }
    return { source, context };
}

const lunarSource = readFileSync(new URL('../modules/common/functions/LunarUtils.qml', import.meta.url), 'utf8');
const lunar = loadFunctions('../modules/common/functions/LunarUtils.qml', {
    minYear: Number(lunarSource.match(/property int minYear: (\d+)/)[1]),
    maxYear: Number(lunarSource.match(/property int maxYear: (\d+)/)[1]),
    lunarInfo: vm.runInNewContext(lunarSource.match(/property var lunarInfo: (\[[\s\S]*?\n    \])/)[1])
}).context;
const options = { enable: true, showLunar: true, showWorkStatus: true };
const { context: calendar } = loadFunctions('../services/CalendarCn.qml', {
    Config: { options: { calendar: { china: options } } }, LunarUtils: lunar,
    holidayDataByYear: {}, loadedYears: {}, missingYears: {}, queuedYears: [], pendingYear: 0
});
Object.defineProperty(calendar, 'enabled', { get: () => options.enable });
// The file-loading boundary is deferred; exercise the real year queue and normalization.
calendar._loadNextYear = () => {};
assert.equal(typeof calendar.getDayDisplay, 'function', 'Missing shared Chinese-calendar presentation');
const display = date => JSON.parse(JSON.stringify(calendar.getDayDisplay(date)));
const spring = new Date(2026, 1, 17);

assert.deepEqual(display(spring), { lunarLabel: '正月', holidayName: '', workStatus: '' });
assert.equal(calendar.queuedYears.join(','), '2026');
calendar.holidayDataByYear[2026] = calendar.normalizeHolidayData({ days: [
    { date: '2026-02-17', name: '春节', isOffDay: true },
    { date: '2026-10-10', name: '国庆节', isOffDay: false }
] });
assert.deepEqual(display(spring), { lunarLabel: '正月', holidayName: '春节', workStatus: '休' });
assert.equal(display(new Date(2026, 9, 10)).workStatus, '班');
assert.equal(display(new Date(2026, 1, 16)).lunarLabel, '除夕');
assert.equal(display(new Date(2026, 9, 14)).holidayName, '');
assert.equal(display(new Date(2026, 9, 14)).workStatus, '');
assert.equal(display(new Date(2027, 0, 1)).holidayName, '');
assert.equal(calendar.queuedYears.join(','), '2026,2027');

options.showLunar = false;
assert.deepEqual(display(spring), { lunarLabel: '', holidayName: '春节', workStatus: '休' });
options.showWorkStatus = false;
assert.deepEqual(display(spring), { lunarLabel: '', holidayName: '春节', workStatus: '' });
options.enable = false;
assert.deepEqual(display(spring), { lunarLabel: '', holidayName: '', workStatus: '' });
assert.deepEqual(display(null), { lunarLabel: '', holidayName: '', workStatus: '' });
console.log('iRiS Chinese calendar: lunar, holiday, make-up day, deferred data and settings passed');
