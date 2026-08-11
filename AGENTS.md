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

- The upstream synchronization merge is `08aabb3fae2087b265a5c74ec16b8bb27563e6f0`.
- Its parents are the previous local `main` (`56d6dbfdabd66bfd12369dd282137bd6e8c51593`) and `upstream/main` (`5ed7a624dec5b9d22f56c9a09c49c5778a083039`).
- The merge preserves the local Open-Meteo, resource temperature source, battery protection, Chinese calendar, focused-monitor wallpaper, folder-name display, and Dolphin-default changes.
- The pre-merge local commit is the recovery baseline if the synchronized version develops a regression.

### Multi-monitor resolution

- Upstream commit `0017948e` replaces the old single-primary-sidebar workaround with one `SidebarHost` per selected output, created through `Variants`.
- The merge intentionally does not retain these old primary-only mitigations:
  - `093a9d96`: pin the right sidebar to the primary screen.
  - `2f83bbfc`: suppress sidebar-related bar actions on secondary screens.
  - `1e7aa202`: freeze primary-screen routing for the lifetime of the Quickshell process.
- Screen-local popup bindings from `9405fc22` remain where they still match the upstream architecture.
- `sidebar.screenList: []` means sidebars are instantiated on all connected screens.

### Known crash risk

- Do not treat the new multi-monitor path as proven crash-free.
- Historical crashes on 2026-07-24 used Qt 6.11.1 and Quickshell revision `4df562dfb2475a9057f0f33a8db75808efad8670`. The stack reached `QWaylandWindow::handleScreensChanged`, `QWindowPrivate::updateDevicePixelRatio`, `QQuickWindow::physicalDpiChanged`, and then `__cxa_pure_virtual`.
- The synchronized version was smoke-tested with two Niri outputs and reached first frame, IPC registration, and normal service initialization without a new coredump. This only covers stable output topology.
- `GlobalStates.primaryScreen` is reactive in upstream. The retained bindings in `ControlPanel.qml`, `OnScreenKeyboard.qml`, `SettingsOverlay.qml`, and `ShellUpdateOverlay.qml` can therefore reassign a live `PanelWindow.screen` after a primary-monitor setting change or output hotplug. Treat that path as unverified.

### Rules for future multi-monitor work

- Prefer one native window per output with a stable screen assignment over moving a live `PanelWindow` between outputs.
- Reproduce and verify primary-monitor changes, output hotplug/removal, suspend/resume, and rapid sidebar open/close before declaring a screen-routing change safe.
- On a crash, preserve the trigger sequence and collect `journalctl --user -u inir.service`, `coredumpctl`, and `~/.cache/quickshell/crashes/` evidence before changing code.
- Perform upstream conflict resolution in an isolated worktree. Do not merge into the checkout currently loaded by Quickshell.
- To compare a regression with the old behavior, use `56d6dbfdabd66bfd12369dd282137bd6e8c51593` as the pre-merge reference; do not discard newer history while testing.
