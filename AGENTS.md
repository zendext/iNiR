# Codex User Instructions

## Commit Messages

- Use this format unless the user explicitly asks for another format:

```text
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Repository Workflow

- This repository does not use a mandatory GitHub Issue-to-pull-request workflow.
- Do not create GitHub Issues, dedicated task branches, Git worktrees, or pull requests merely to satisfy a generic Issue-to-pull-request workflow.
- Use a Git worktree only when the user explicitly requests one or a repository-specific safety rule below requires one.
- When asked to publish changes, commit and push the current branch directly unless the user explicitly requests a different workflow.

## Upstream Merge and Multi-Monitor Safety

### Current baseline

- The upstream synchronization merge is `d7d611a627dcba822537c0a1a69cc56f7a01444d`.
- Its parents are the previous local `main` (`421be5ec9f8336636b767a0daf46afa12feb1371`) and `upstream/main` (`dcba34ee124acb5a191c88b2e1952006fa5afb2f`).
- The merge preserves the local Open-Meteo, selectable resource temperature source, dual-threshold battery protection, Chinese calendar, compact-screen bar behavior, one-percent audio steps, focused-monitor wallpaper, folder-name display, and Dolphin-default changes.
- The pre-merge local commit is the recovery baseline if the synchronized version develops a regression.
- Conflict resolution adopts upstream's 2.30.0 package versions and schema-based Wallpapers assertion, while retaining both the Settings overlay screen binding and upstream search page access, plus the local battery-toggle registration check.
- The 2026-09-10 synchronization passed `bash scripts/test-local-distribution.sh` (including 10 payload tests), all 6 sensor fixture tests in `scripts/test-detect-sensors.py`, the Qt 6 `tests/tst_bar_breakpoints.qml` run (8 passed, including setup and cleanup), and parsing of `SettingsOverlay.qml` with Qt 6 `qmlformat`.
- This was a source synchronization. The running shell was stopped before fast-forwarding the live checkout and restarted afterward; the installed launcher/service and Niri configuration migrations were not updated by an installer.

### Multi-monitor resolution

- Upstream commit `0017948e` replaces the old single-primary-sidebar workaround with one `SidebarHost` per selected output, created through `Variants`.
- The merge intentionally does not retain these old primary-only mitigations:
  - `093a9d96`: pin the right sidebar to the primary screen.
  - `2f83bbfc`: suppress sidebar-related bar actions on secondary screens.
  - `1e7aa202`: freeze primary-screen routing for the lifetime of the Quickshell process.
- Screen-local popup bindings from `9405fc22` remain where they still match the upstream architecture. The shared `ContextMenu` keeps explicit target-window and target-screen bindings while using upstream's single-active-menu lifecycle.
- `sidebar.screenList: []` means sidebars are instantiated on all connected screens.
- `ScreenCorners.CornerPanelWindow` must use the inherited `PanelWindow.screen` property. Redeclaring it as a QML `var` shadows the native property, so the per-output bindings only update the shadow while the actual windows all open on the default output.
- `python3 scripts/test-orbit-hot-corners.py HDMI-A-1 eDP-1` checks live corner-surface coverage when Orbit hot corners are enabled and the selected outputs are not fullscreen or blocked by Niri overview corners. The 2026-09-10 regression changed from zero external/two internal corner surfaces to one on each output after removing the shadowing declaration; the user also confirmed Orbit opens from the external screen's hot corner.

### Known crash risk

- Do not treat the new multi-monitor path as proven crash-free.
- Historical crashes on 2026-07-24 used Qt 6.11.1 and Quickshell revision `4df562dfb2475a9057f0f33a8db75808efad8670`. The stack reached `QWaylandWindow::handleScreensChanged`, `QWindowPrivate::updateDevicePixelRatio`, `QQuickWindow::physicalDpiChanged`, and then `__cxa_pure_virtual`.
- The 2026-09-10 startup smoke test used Qt 6.11.2 and Quickshell 0.3.1 revision `2d3b3e9c70ef380dff751b61d334dc88df016c29`. It reached first frame in 1127 ms, loaded `HDMI-A-1` and `eDP-1`, updated weather through Open-Meteo, and answered the `shellUpdate.diagnose`, `sidebarLeft.status`, and `orbit.status` IPC calls. No new QML load errors, reference/type errors, binding loops, or automatic service restarts were observed. This covers stable output topology only; primary-monitor changes, output hotplug, and suspend/resume remain unverified.
- `GlobalStates.primaryScreen` is reactive in upstream. The retained bindings in `ControlPanel.qml`, `OnScreenKeyboard.qml`, `SettingsOverlay.qml`, and `ShellUpdateOverlay.qml` can therefore reassign a live `PanelWindow.screen` after a primary-monitor setting change or output hotplug. Treat that path as unverified.

### Rules for future multi-monitor work

- Prefer one native window per output with a stable screen assignment over moving a live `PanelWindow` between outputs.
- Reproduce and verify primary-monitor changes, output hotplug/removal, suspend/resume, and rapid sidebar open/close before declaring a screen-routing change safe.
- On a crash, preserve the trigger sequence and collect `journalctl --user -u inir.service`, `coredumpctl`, and `~/.cache/quickshell/crashes/` evidence before changing code.
- Perform upstream conflict resolution in an isolated worktree. Do not merge into the checkout currently loaded by Quickshell.
- To compare a regression with the pre-sync behavior, use `421be5ec9f8336636b767a0daf46afa12feb1371` as the recovery reference; do not discard newer history while testing.
