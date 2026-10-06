#!/usr/bin/env node
// Execute the real bar handlers and routing methods with two connected outputs.
// Native QML windows still require the live two-monitor click check.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const read = path => readFileSync(new URL(path, import.meta.url), 'utf8');
const barSource = process.argv[2]
    ? readFileSync(process.argv[2], 'utf8') : read('../modules/bar/BarContent.qml');
const globalSource = read('../GlobalStates.qml');
const layoutSource = read('../services/ShellLayoutController.qml');

function blockAfter(source, marker) {
    const markerAt = source.indexOf(marker);
    assert.notEqual(markerAt, -1, `Missing ${marker}`);
    const start = source.indexOf('{', markerAt);
    let depth = 1;
    for (let end = start + 1; end < source.length; end++) {
        if (source[end] === '{') depth++;
        if (source[end] === '}' && --depth === 0) return source.slice(start + 1, end);
    }
    assert.fail(`Unclosed ${marker}`);
}

function loadMethods(source, names, root, globals) {
    const context = vm.createContext({ ...globals, root });
    // QML methods can address their own object's properties without `root.`.
    for (const property of Object.keys(root)) {
        Object.defineProperty(context, property, {
            get: () => root[property], set: value => { root[property] = value; }
        });
    }
    for (const name of names) {
        const signature = source.match(new RegExp(`function ${name}\\(([^)]*)\\)`));
        assert.ok(signature, `Missing method ${name}`);
        const args = signature[1].replace(/:\s*\w+/g, '');
        root[name] = vm.runInContext(`(function(${args}) {${blockAfter(source, `function ${name}(`)}})`, context);
    }
    return context;
}

const Config = { options: { sidebar: { screenList: [], shellLayout: {
    feature: { slot: 'left' }, system: { slot: 'right' }
} } } };
const GlobalStates = {
    focusedScreen: { name: 'DP-2' }, primaryScreen: { name: 'DP-1' },
    sidebarLeftOpen: false, sidebarRightOpen: false,
    sidebarLeftTargetOutput: '', sidebarRightTargetOutput: ''
};
const globalContext = loadMethods(globalSource, [
    'connectedOutputNames', 'resolveOutputName',
    'openSidebarLeft', 'closeSidebarLeft', 'openSidebarRight', 'closeSidebarRight'
], GlobalStates, { Config, Quickshell: { screens: [{ name: 'DP-1' }, { name: 'DP-2' }] } });
for (const edge of ['Left', 'Right']) {
    const property = `sidebar${edge}PresentationOutput`;
    const expression = globalSource.match(new RegExp(`readonly property string ${property}:\\s*([\\s\\S]+?)(?=\\n\\s*(?:readonly property|function))`))?.[1];
    assert.ok(expression, `Missing ${property}`);
    Object.defineProperty(GlobalStates, property, {
        get: () => vm.runInContext(expression, globalContext)
    });
}
const ShellLayoutController = {};
loadMethods(layoutSource, [
    '_validSidebarSlot', 'sidebarAssignments', 'sidebarRoleForSlot',
    'sidebarOpenAtSlot', 'setSidebarOpenAtSlot', 'toggleSidebarAtSlot'
], ShellLayoutController, { Config, GlobalStates });

const context = vm.createContext({
    root: { screen: { name: 'DP-1' }, QsWindow: { window: { screen: { name: 'DP-1' } } } },
    ShellLayoutController, Qt: { LeftButton: 1, RightButton: 2 }, event: { button: 1 },
    rightCenterGroup: { _tapSeq: 0 }, _tapSeqTimer: { restart() {} }, _fxResetTimer: { restart() {} }
});
const cases = [
    ['left margin', 'id: barLeftSideMouseArea', 'left'],
    ['right margin', 'id: barRightSideMouseArea', 'right'],
    ['right center pill', '// Interaction overlay (sidebar toggle', 'right'],
    ['right status button', 'id: rightSidebarButton\n', 'right']
];

for (const swapped of [false, true]) {
    Config.options.sidebar.shellLayout.feature.slot = swapped ? 'right' : 'left';
    Config.options.sidebar.shellLayout.system.slot = swapped ? 'left' : 'right';
    for (const [label, marker, slot] of cases) {
        const source = barSource.slice(barSource.indexOf(marker));
        const handler = `(() => {${blockAfter(source, 'onPressed:')}})()`;
        const edge = ShellLayoutController.sidebarRoleForSlot(slot) === 'featureSidebar' ? 'Left' : 'Right';
        GlobalStates.sidebarLeftOpen = false;
        GlobalStates.sidebarRightOpen = false;
        GlobalStates[`sidebar${edge}TargetOutput`] = 'DP-2';
        GlobalStates[`sidebar${edge}Open`] = true;
        vm.runInContext(handler, context);
        assert.equal(GlobalStates[`sidebar${edge}Open`], true, `${label}: move an open panel to the clicked screen`);
        assert.equal(GlobalStates[`sidebar${edge}TargetOutput`], 'DP-1', `${label}: clicked screen wins over focused screen`);
        vm.runInContext(handler, context);
        assert.equal(GlobalStates[`sidebar${edge}Open`], false, `${label}: second click closes this screen's panel`);
        console.log(`PASS ${label}: output routing and toggle${swapped ? ' with swapped sidebars' : ''}`);
    }
}

Config.options.sidebar.shellLayout.feature.slot = 'left';
Config.options.sidebar.shellLayout.system.slot = 'right';
const button = barSource.slice(barSource.indexOf('id: rightSidebarButton\n'));
const toggled = button.match(/toggled: ([\s\S]+?)\n\s*property color colText/)?.[1];
assert.ok(toggled, 'Missing right button toggled binding');
GlobalStates.sidebarRightOpen = true;
GlobalStates.sidebarRightTargetOutput = 'DP-2';
assert.equal(vm.runInContext(toggled, context), false, 'Main button is idle when the sidebar is on the other screen');
GlobalStates.sidebarRightTargetOutput = 'DP-1';
assert.equal(vm.runInContext(toggled, context), true, 'Main button is selected when its sidebar is open');
console.log('PASS right button: screen-local selected state');
