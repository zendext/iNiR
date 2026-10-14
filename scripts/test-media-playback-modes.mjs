#!/usr/bin/env node
// Exercise the actual QML bindings/handlers without loading the desktop shell.
// Visual layout and the MPRIS transport still need a live Spotify smoke test.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const MprisLoopState = { None: 0, Track: 1, Playlist: 2 };
const Translation = { tr: text => text };

function blockAfter(text, marker) {
    const markerAt = text.indexOf(marker);
    assert.notEqual(markerAt, -1, `Missing ${marker}`);
    const start = text.indexOf('{', markerAt);
    let depth = 1;
    for (let end = start + 1; end < text.length; end++) {
        if (text[end] === '{') depth++;
        if (text[end] === '}' && --depth === 0) return text.slice(start + 1, end);
    }
    assert.fail(`Unclosed ${marker}`);
}

function button(source, id, root) {
    const idAt = source.indexOf(`id: ${id}`);
    assert.notEqual(idAt, -1, `Missing ${id}`);
    const text = blockAfter(source.slice(source.lastIndexOf('RippleButton {', idAt)), 'RippleButton');
    const context = { root, MprisLoopState, Translation, playPauseIcon: { color: '#fafafa' } };
    return {
        value(property) {
            const expression = text.match(new RegExp(`^\\s*(?:property \\w+ )?${property}: (.+)$`, 'm'))?.[1];
            assert.ok(expression, `Missing ${id}.${property}`);
            return vm.runInNewContext(expression, context);
        },
        click() {
            vm.runInNewContext(`(() => {${blockAfter(text, 'onClicked:')}})()`, context);
        },
        iconValue(property) {
            const icon = blockAfter(text, 'contentItem: MaterialSymbol');
            const expression = icon.match(new RegExp(`^\\s*${property}: (.+)$`, 'm'))?.[1];
            assert.ok(expression, `Missing ${id} icon ${property}`);
            context[id] = { toggled: this.value('toggled') };
            return vm.runInNewContext(expression, context);
        }
    };
}

function testFile(path) {
    const source = readFileSync(new URL(path, import.meta.url), 'utf8');
    const player = { canControl: true, loopSupported: true, shuffleSupported: true, loopState: MprisLoopState.None, shuffle: false };
    const otherPlayer = { ...player };
    const root = { player };
    const shuffle = button(source, 'shuffleButton', root);
    const loop = button(source, 'loopButton', root);

    assert.equal(shuffle.value('visible'), true);
    assert.equal(loop.value('visible'), true);
    for (const control of [shuffle, loop]) {
        assert.equal(control.iconValue('color'), '#fafafa');
        assert.equal(control.iconValue('opacity'), 0.45);
    }
    shuffle.click();
    assert.equal(player.shuffle, true);
    assert.equal(shuffle.value('toggled'), true);
    assert.equal(shuffle.value('buttonText'), 'Shuffle On');
    assert.equal(shuffle.iconValue('opacity'), 1);
    assert.equal(otherPlayer.shuffle, false);
    player.shuffle = false; // A change initiated in the player must update the UI.
    assert.equal(shuffle.value('toggled'), false);
    assert.equal(shuffle.value('buttonText'), 'Shuffle Off');

    for (const [expected, label, icon] of [
        [MprisLoopState.Playlist, 'Repeat All', 'repeat'],
        [MprisLoopState.Track, 'Repeat One', 'repeat_one'],
        [MprisLoopState.None, 'Repeat Off', 'repeat']
    ]) {
        loop.click();
        assert.equal(player.loopState, expected);
        assert.equal(loop.value('buttonText'), label);
        assert.equal(loop.value('iconName'), icon);
        assert.equal(loop.value('toggled'), expected !== MprisLoopState.None);
        assert.equal(loop.iconValue('opacity'), expected === MprisLoopState.None ? 0.45 : 1);
    }
    player.loopState = MprisLoopState.Track;
    assert.equal(loop.value('iconName'), 'repeat_one');
    assert.equal(loop.value('buttonText'), 'Repeat One');

    root.player = otherPlayer;
    loop.click();
    shuffle.click();
    assert.equal(otherPlayer.loopState, MprisLoopState.Playlist);
    assert.equal(otherPlayer.shuffle, true);
    assert.equal(player.loopState, MprisLoopState.Track);
    assert.equal(player.shuffle, false);

    for (const capability of ['loopSupported', 'shuffleSupported', 'canControl']) {
        const target = { ...player, [capability]: false };
        root.player = target;
        const before = { ...target };
        if (capability !== 'shuffleSupported') {
            assert.equal(loop.value('visible'), false);
            loop.click();
        }
        if (capability !== 'loopSupported') {
            assert.equal(shuffle.value('visible'), false);
            shuffle.click();
        }
        assert.deepEqual(target, before);
    }
    root.player = null;
    assert.equal(shuffle.value('visible'), false);
    assert.equal(loop.value('visible'), false);
    shuffle.click();
    loop.click();
    assert.equal(shuffle.value('toggled'), false);
    assert.equal(loop.value('toggled'), false);
    console.log(`PASS ${path}: loop, shuffle, brightness, state sync, player switching, capabilities and disconnect`);
}

testFile('../modules/mediaControls/PlayerControl.qml');
testFile('../modules/sidebarLeft/widgets/MediaPlayerWidget.qml');

// A browser can temporarily lose mpris:length after seeking. The popup must
// share the controller's remembered length and corrected position with its slider.
const controllerSource = readFileSync(new URL('../services/MprisController.qml', import.meta.url), 'utf8');
const player = { dbusName: 'browser', trackTitle: 'Video', position: 20, length: 20, lengthSupported: false, canSeek: true, isPlaying: true };
const controller = {
    knownLengths: { browser: { title: 'Video', length: 120 } },
    positionOffsets: { browser: 15 },
    titleOf: player => player.trackTitle
};
const controllerContext = vm.createContext({ root: controller });
for (const name of ['lengthOf', 'positionOf', '_setPositionOffset', 'clearPositionOffset', 'seek']) {
    const signature = controllerSource.match(new RegExp(`function ${name}\\(([^)]*)\\)`));
    assert.ok(signature, `Missing ${name}`);
    const args = signature[1].replace(/:\s*\w+/g, '');
    controller[name] = vm.runInContext(`(function(${args}) {${blockAfter(controllerSource, `function ${name}(`)}})`, controllerContext);
}
const popupSource = readFileSync(new URL('../modules/mediaControls/PlayerControl.qml', import.meta.url), 'utf8');
const timelineContext = vm.createContext({ root: { player }, MprisController: controller });
const labels = [...popupSource.matchAll(/text: StringUtils\.friendlyTimeForSeconds\((.+)\)/g)]
    .map(match => vm.runInContext(match[1], timelineContext));
assert.deepEqual(labels, [35, 120], 'Time labels use the corrected position and remembered length');
const progress = blockAfter(popupSource, 'PlayerProgress {');
for (const [property, expected] of [['position', 35], ['length', 120]]) {
    const expression = progress.match(new RegExp(`^\\s*${property}: (.+)$`, 'm'))?.[1];
    assert.ok(expression, `Missing progress.${property}`);
    assert.equal(vm.runInContext(expression, timelineContext), expected);
}
const seek = progress.match(/onSeekRequested: (.+)/)?.[1];
assert.ok(seek, 'Missing seek handler');
vm.runInContext(`(${seek})(75)`, timelineContext);
assert.equal(player.position, 75);
assert.equal(controller.positionOffsets.browser, undefined, 'Seeking clears the old correction');
console.log('PASS popup timeline: remembered length, corrected position and seeking');
