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

- The upstream synchronization merge is `3f01d4b17f21ba047f01416418c375d824b1b1f4`.
- Its parents are the previous local `main` (`3738723338a1549914f45a61f7e04d88ff5d300c`) and `upstream/main` (`0f252bbf40875e43ac9c242705e777f3706b1164`).
- The merge preserves the local Open-Meteo, selectable resource temperature source, dual-threshold battery protection, Chinese calendar, compact-screen bar behavior, one-percent audio steps, focused-monitor wallpaper, folder-name display, and Dolphin-default changes.
- The pre-merge local commit is the recovery baseline if the synchronized version develops a regression.

### Multi-monitor resolution

- Upstream commit `0017948e` replaces the old single-primary-sidebar workaround with one `SidebarHost` per selected output, created through `Variants`.
- The merge intentionally does not retain these old primary-only mitigations:
  - `093a9d96`: pin the right sidebar to the primary screen.
  - `2f83bbfc`: suppress sidebar-related bar actions on secondary screens.
  - `1e7aa202`: freeze primary-screen routing for the lifetime of the Quickshell process.
- Screen-local popup bindings from `9405fc22` remain where they still match the upstream architecture. The shared `ContextMenu` keeps explicit target-window and target-screen bindings while using upstream's single-active-menu lifecycle.
- `sidebar.screenList: []` means sidebars are instantiated on all connected screens.

### Known crash risk

- Do not treat the new multi-monitor path as proven crash-free.
- Historical crashes on 2026-07-24 used Qt 6.11.1 and Quickshell revision `4df562dfb2475a9057f0f33a8db75808efad8670`. The stack reached `QWaylandWindow::handleScreensChanged`, `QWindowPrivate::updateDevicePixelRatio`, `QQuickWindow::physicalDpiChanged`, and then `__cxa_pure_virtual`.
- The current synchronization was smoke-tested with two Niri outputs: it reached first frame, loaded both outputs, initialized the sidebar modules, and produced no new coredump. This covers stable output topology only; primary-monitor changes and output hotplug remain unverified.
- `GlobalStates.primaryScreen` is reactive in upstream. The retained bindings in `ControlPanel.qml`, `OnScreenKeyboard.qml`, `SettingsOverlay.qml`, and `ShellUpdateOverlay.qml` can therefore reassign a live `PanelWindow.screen` after a primary-monitor setting change or output hotplug. Treat that path as unverified.

### Rules for future multi-monitor work

- Prefer one native window per output with a stable screen assignment over moving a live `PanelWindow` between outputs.
- Reproduce and verify primary-monitor changes, output hotplug/removal, suspend/resume, and rapid sidebar open/close before declaring a screen-routing change safe.
- On a crash, preserve the trigger sequence and collect `journalctl --user -u inir.service`, `coredumpctl`, and `~/.cache/quickshell/crashes/` evidence before changing code.
- Perform upstream conflict resolution in an isolated worktree. Do not merge into the checkout currently loaded by Quickshell.
- To compare a regression with the pre-sync behavior, use `3738723338a1549914f45a61f7e04d88ff5d300c` as the recovery reference; do not discard newer history while testing.
