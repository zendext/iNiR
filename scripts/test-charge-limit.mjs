#!/usr/bin/env node
// Run the actual threshold writer against ordinary files without polkit.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import vm from 'node:vm';

const source = readFileSync(new URL('../services/Battery.qml', import.meta.url), 'utf8');
const body = source.match(/function _buildChargeLimitWriteCommand\(enable: bool\): var \{([\s\S]*?)\n    \}/)[1];
const dir = mkdtempSync(join(tmpdir(), 'inir-charge-test-'));
try {
    const start = join(dir, 'start');
    const end = join(dir, 'end');
    const behaviour = join(dir, 'behaviour');
    writeFileSync(start, '0');
    writeFileSync(end, '100');
    writeFileSync(behaviour, 'inhibit-charge');
    const fixture = {
        _chargeLimitBackend: 'threshold',
        _chargeLimitStartSysfsPath: start,
        _chargeLimitSysfsPath: end,
        _chargeLimitBehaviourSysfsPath: behaviour,
        chargeLimitStartThreshold: 60,
        _desiredChargeLimitValue: enable => enable ? 80 : 100
    };
    const build = vm.runInNewContext('(function(enable) {' + body + '})', fixture);
    const apply = enable => {
        const [, shell, ...args] = build(enable);
        return spawnSync(shell, args, { encoding: 'utf8' });
    };

    assert.equal(apply(true).status, 0);
    assert.equal(readFileSync(start, 'utf8'), '60');
    assert.equal(readFileSync(end, 'utf8'), '80');
    assert.equal(readFileSync(behaviour, 'utf8'), 'auto');
    assert.equal(apply(false).status, 0);
    assert.equal(readFileSync(start, 'utf8'), '0');
    assert.equal(readFileSync(end, 'utf8'), '100');

    fixture._chargeLimitStartSysfsPath = join(dir, 'missing', 'start');
    assert.notEqual(apply(true).status, 0);
    assert.equal(readFileSync(end, 'utf8'), '100');
} finally {
    rmSync(dir, { recursive: true, force: true });
}
console.log('Charge limit: threshold writes, reset and write failure passed');
