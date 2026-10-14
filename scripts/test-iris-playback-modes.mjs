#!/usr/bin/env node
// Execute the shared iRiS QML button bindings and handlers; rendering and D-Bus
// are verified separately against a temporary MPRIS player.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const MprisLoopState = { None: 0, Track: 1, Playlist: 2 };
const read = path => readFileSync(new URL(path, import.meta.url), 'utf8');
function blockAfter(source, marker, from = 0) {
    const at = source.indexOf(marker, from);
    assert.notEqual(at, -1, `Missing ${marker}`);
    const start = source.indexOf('{', at);
    let depth = 1;
    for (let end = start + 1; end < source.length; end++) {
        if (source[end] === '{') depth++;
        if (source[end] === '}' && --depth === 0) return source.slice(start + 1, end);
    }
    assert.fail(`Unclosed ${marker}`);
}

const player = { canControl: true, shuffleSupported: true, loopSupported: true,
    shuffle: false, loopState: MprisLoopState.None };
const other = { ...player };
for (const path of ['components/IrisMediaCard.qml', 'bar/island/IslandMediaPage.qml',
    'widgets/IrisNowPlayingFace.qml', 'control/IrisControlGrid.qml']) {
    const source = read(`../modules/iris/${path}`);
    const buttons = [...source.matchAll(/IrisPlaybackModeButton\s*\{/g)]
        .map(match => blockAfter(source, 'IrisPlaybackModeButton', match.index));
    assert.equal(buttons.length, 2, `${path}: missing shuffle/repeat controls`);
    const adjacentSize = path === 'components/IrisMediaCard.qml'
        ? source.match(/iconSize: (toggle \? .+)/)[1]
        : path === 'bar/island/IslandMediaPage.qml'
            ? blockAfter(source, 'GlyphButton').match(/glyphSize: (.+)/)[1]
        : path === 'widgets/IrisNowPlayingFace.qml'
            ? read('../modules/iris/widgets/FaceAction.qml').match(/iconSize: (.+)/)[1]
            : source.match(/iconSize: (Math\.round\(\(transportButton.+)/)[1];
    const defaultSize = read('../modules/iris/components/IrisIconButton.qml').match(/property int iconSize: (.+)/)[1];
    for (const button of buttons) {
        const binding = button.match(/player: (.+)/)?.[1];
        assert.ok(binding, `${path}: missing displayed-player binding`);
        const shown = vm.runInNewContext(binding, { root: { player }, page: { island: { player } }, transport: { player: { player } } });
        assert.equal(shown, player, `${path}: controls target the displayed player`);
        for (const density of [1, 1.25, 1.5]) {
            const px = n => Math.round(n * density);
            const sizing = { root: { d: density, px, face: { px } }, IrisStyle: { density },
                toggle: false, transportButton: { modelData: { action: 'previous' } } };
            const modeSize = button.match(/iconSize: (.+)/)?.[1] ?? defaultSize;
            assert.equal(vm.runInNewContext(modeSize, sizing), vm.runInNewContext(adjacentSize, sizing),
                `${path}: mode icons match previous/next at density ${density}`);
        }
        if (path === 'control/IrisControlGrid.qml') {
            const enabled = button.match(/enabled: (.+)/)?.[1];
            for (const [live, editing] of [[true, false], [false, false], [true, true]]) {
                assert.equal(vm.runInNewContext(enabled, { supported: true, transport: { live }, root: { editing } }), live && !editing);
            }
        }
    }
}

const source = read('../modules/iris/components/IrisPlaybackModeButton.qml');
const root = { player, mode: 'shuffle',
    colBackground: 'transparent', colBackgroundHover: '#222222' };
let disabled = false;
const context = { root, MprisLoopState, IrisStyle: { text: '#ffffff', accent: '#80bfff' }, Translation: { tr: text => text } };
function value(name) {
    const match = source.match(new RegExp(`^    (?:(?:readonly )?property \\w+ )?${name}: (.+(?:\\n        .*)*)`, 'm'));
    assert.ok(match, `Missing mode button ${name}`);
    return vm.runInNewContext(match[1].startsWith('{')
        ? `(() => {${blockAfter(source, `${name}:`)}})()` : match[1], context);
}
for (const name of ['supported', 'selected']) Object.defineProperty(root, name, { get: () => value(name) });
Object.defineProperty(root, 'enabled', { get: () => !disabled && value('enabled') });
const click = () => vm.runInNewContext(`(() => {${blockAfter(source, 'onClicked:')}})()`, context);
assert.equal(value('visible'), true);
assert.equal(value('opacity'), 0.45);
assert.equal(value('foreground'), '#ffffff');
click();
assert.equal(player.shuffle, true);
assert.equal(value('caption'), 'Shuffle On');
assert.equal(value('opacity'), 1);
assert.equal(value('foreground'), '#ffffff');
assert.equal(value('colBackgroundToggled'), 'transparent');
assert.equal(value('colBackgroundToggledHover'), '#222222');
assert.ok(!source.includes('StyledToolTip'), 'No hover text for playback modes');
assert.equal(other.shuffle, false);
player.shuffle = false;
assert.equal(value('caption'), 'Shuffle Off');

root.mode = 'repeat';
for (const [state, label, icon] of [[MprisLoopState.Playlist, 'Repeat All', 'repeat'],
    [MprisLoopState.Track, 'Repeat One', 'repeat_one'], [MprisLoopState.None, 'Repeat Off', 'repeat']]) {
    click();
    assert.equal(player.loopState, state);
    assert.equal(value('caption'), label);
    assert.equal(value('materialIcon'), icon);
}
player.loopState = MprisLoopState.Track;
assert.equal(value('materialIcon'), 'repeat_one');
root.player = other;
click();
assert.equal(other.loopState, MprisLoopState.Playlist);
assert.equal(player.loopState, MprisLoopState.Track);

for (const mode of ['shuffle', 'repeat']) {
    root.mode = mode;
    for (const loss of [mode === 'shuffle' ? 'shuffleSupported' : 'loopSupported', 'canControl']) {
        root.player = { ...player, [loss]: false };
        const before = { ...root.player };
        assert.equal(value('visible'), false);
        click();
        assert.deepEqual(root.player, before);
    }
    root.player = player;
    disabled = true;
    const before = { ...player };
    click();
    assert.deepEqual(player, before);
    disabled = false;
    root.player = null;
    assert.equal(value('visible'), false);
    click();
}
console.log('iRiS playback modes: four player bindings, repeat/shuffle, external state and capability guards passed');
